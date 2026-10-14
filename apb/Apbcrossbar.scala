package test

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba3.apb._
import spinal.lib.bus.misc.SizeMapping

import scala.collection.mutable.ArrayBuffer

// -------------------------------------------
// 轮询仲裁器
// -------------------------------------------

/** APB 轮询（round-robin）仲裁器
  *
  * 输入各主端口的请求，输出一热（one-hot）授权，同一时刻最多授权一个。
  *
  * 实现用的是「优先级掩码」法：
  *   mask 中为 1 的位表示本轮仍然有资格参与竞争。
  *   每次授权之后，把 mask 里「被授权位及其低位」全部清零，
  *   下一次的优先级自然从被授权位的下一位开始，于是形成轮转。
  *
  * 未获授权的端口这一拍拿不到 PREADY，会继续保持等待，
  * 下一个空闲周期再参加竞争。
  *
  * 这里写成 object + apply（而不是 Area），是为了避免在 Area 里用
  * in / out 标记方向 —— 那会被 SpinalHDL 当成「需要从组件外部驱动」，
  * 触发 HIERARCHY VIOLATION。
  */
object ApbRoundRobinArbiter {

  /** @param requests 各端口的请求信号
    * @return 一热授权；无请求时全 0
    */
  def apply(requests: Seq[Bool]): Bits = {
    val portCount = requests.length
    require(portCount >= 2, s"仲裁器至少需要 2 个端口（当前 $portCount）")

    val reqBits = Bits(portCount bits)
    for (i <- 0 until portCount) {
      reqBits(i) := requests(i)
    }

    // mask 全 0 表示「所有请求者同等优先」，即第一轮
    val mask = Reg(Bits(portCount bits)) init B(0, portCount bits)

    val maskedReq = reqBits & mask
    // 先在前一轮剩下的候选里挑，挑不到才从头挑
    val pick = OHMasking.first(Mux(maskedReq.orR, maskedReq, reqBits))

    // pick 位及其低位清零、高位保留 —— 下一次从 pick 的下一位开始轮
    val nextMask = Bits(portCount bits)
    // 注意：这里必须写出 ": Bool"，否则 Scala 会把 taken 推断成 False 的单例类型
    var taken: Bool = False
    for (i <- 0 until portCount) {
      nextMask(i) := taken
      taken = taken || pick(i)
    }
    when(pick.orR) {
      mask := nextMask
    }

    pick
  }
}

// -------------------------------------------
// 互连工厂
// -------------------------------------------

/** APB 多主多从互连工厂，用法与 Axi4CrossbarFactory 一致
  *
  * {{{
  *   val apbCrossBar = Apb3CrossbarFactory()
  *
  *   apbCrossBar.addSlaves(
  *     (io.apbOut(0), SizeMapping(0x00000000L, 4 KiB)),
  *     (io.apbOut(1), SizeMapping(0x00001000L, 4 KiB))
  *   )
  *
  *   apbCrossBar.addConnections(
  *     io.apbIn(0) -> List(io.apbOut(0), io.apbOut(1)),
  *     io.apbIn(1) -> List(io.apbOut(0))
  *   )
  *
  *   apbCrossBar.build()
  * }}}
  *
  * 结构：M 个主端口 ── 轮询仲裁 ── 一条内部 APB ── 地址译码 ── N 个从端口
  *
  * 说明：
  *   - 主端口（apbIn）用 slave(Apb3(...)) 声明，从端口（apbOut）用 master(Apb3(...)) 声明
  *   - addConnections 的调用顺序就是主设备的序号（第 1 行 = 主设备 0）
  *   - 从端口数量、主端口数量都任意，M >= 2，N >= 1
  */
case class Apb3CrossbarFactory() {

  private val slavesNode      = ArrayBuffer[(Apb3, SizeMapping)]()
  private val connectionsNode = ArrayBuffer[(Apb3, List[Apb3])]()

  def addSlave(apb: Apb3, mapping: SizeMapping): this.type = {
    slavesNode += ((apb, mapping))
    this
  }

  def addSlaves(orders: (Apb3, SizeMapping)*): this.type = {
    orders.foreach(order => addSlave(order._1, order._2))
    this
  }

  def addConnection(apb: Apb3, slaves: Seq[Apb3]): this.type = {
    connectionsNode += ((apb, slaves.toList))
    this
  }

  def addConnection(order: (Apb3, Seq[Apb3])): this.type = addConnection(order._1, order._2)

  def addConnections(orders: (Apb3, Seq[Apb3])*): this.type = {
    orders.foreach(order => addConnection(order._1, order._2))
    this
  }

  def build(): Unit = {
    val slaveList     = slavesNode.map(_._1).toList
    val mappings      = slavesNode.map(_._2).toList
    val masterList    = connectionsNode.map(_._1).toList
    val connectedList = connectionsNode.map(_._2).toList

    val slaveCount  = slaveList.length
    val masterCount = masterList.length

    require(masterCount >= 2, s"至少需要 2 个主设备（当前 $masterCount）")
    require(slaveCount >= 1, "至少需要 1 个从设备")
    require(slaveList.forall(_.PSEL.getWidth == 1), "PSEL 必须是 1 位")
    require(!SizeMapping.verifyOverlapping(mappings),
      "从设备地址窗口之间存在重叠：" +
        mappings.map(m => s"0x${m.base.toString(16)}~0x${m.end.toString(16)}").mkString(", "))
    mappings.foreach { m =>
      require(m.isAligned,
        s"窗口 0x${m.base.toString(16)} 的大小 0x${m.size.toString(16)} 必须是 2 的幂，且基地址按它对齐")
    }
    connectedList.foreach { list =>
      list.foreach { port =>
        require(slaveList.exists(_ eq port), "addConnections 里出现了没有在 addSlaves 中登记的从端口")
      }
    }

    // ========================================================================
    // 1) 仲裁：这一拍由哪个主设备占用总线
    // ========================================================================
    // holder 记录当前占用总线的主设备（一热编码）
    val holder = Reg(Bits(masterCount bits)) init B(0, masterCount bits)
    // 持有者是否还在访问中（PSEL 尚未落下）
    val holderBusy = holder.orR && MuxOH(holder, masterList.map(_.PSEL.lsb))

    // 总线被占用时把请求全部屏蔽（冻结仲裁器），
    // 避免它在一次事务的中途改变仲裁结果
    val arbGrants = ApbRoundRobinArbiter(
      masterList.map(m => m.PSEL.lsb && !holderBusy)
    )

    // 忙 → 继续给持有者；空闲 → 采纳仲裁结果
    val granted = Bits(masterCount bits)
    when(holderBusy) {
      granted := holder
    } otherwise {
      granted := arbGrants
    }
    when(!holderBusy) {
      holder := granted
    }
    val anyGranted = granted.orR

    // ========================================================================
    // 2) 把获授权主设备的信号汇成一条内部 APB 总线
    // ========================================================================
    val busAddr   = MuxOH(granted, masterList.map(_.PADDR))
    val busWrite  = MuxOH(granted, masterList.map(_.PWRITE))
    val busWData  = MuxOH(granted, masterList.map(_.PWDATA))
    val busEnable = MuxOH(granted, masterList.map(_.PENABLE))

    // ========================================================================
    // 3) 地址译码：选出目标从设备
    //    每个主设备能访问哪些从设备由 addConnections 决定，这里是编译期常量
    // ========================================================================
    val allowMask = connectedList.map { connected =>
      var bits = BigInt(0)
      for (s <- 0 until slaveCount) {
        if (connected.exists(_ eq slaveList(s))) bits |= (BigInt(1) << s)
      }
      B(bits, slaveCount bits)
    }
    val allowBits = MuxOH(granted, allowMask)

    val selected = Bits(slaveCount bits)
    for (s <- 0 until slaveCount) {
      selected(s) := anyGranted && allowBits(s) && mappings(s).hit(busAddr)
    }
    val anySelected = selected.orR

    // ========================================================================
    // 4) 驱动从端口
    //
    //    这里要做一次「相位重定时」。主设备一旦进入 ACCESS 阶段，PENABLE
    //    就会一直保持为高（APB 规范如此）。如果直接透传，那些一直在
    //    ACCESS 阶段等待、刚拿到总线的主设备，就会让从设备看到 PSEL 与
    //    PENABLE 同一拍变高，缺了规范的 SETUP 相位。
    //    加一级 selectedD（上一拍的选中情况）之后，从设备总能先看到
    //    一拍 PSEL = 1 / PENABLE = 0，再看到 PENABLE = 1。
    // ========================================================================
    val selectedD = Reg(Bits(slaveCount bits)) init B(0, slaveCount bits)
    selectedD := selected

    for (s <- 0 until slaveCount) {
      val apb = slaveList(s)
      apb.PSEL(0) := selected(s)
      apb.PENABLE := selected(s) && selectedD(s) && busEnable
      apb.PADDR   := busAddr
      apb.PWRITE  := busWrite
      apb.PWDATA  := busWData
    }

    // ========================================================================
    // 5) 汇总从设备响应，回送给主设备
    // ========================================================================
    val respData  = MuxOH(selected, slaveList.map(_.PRDATA))
    val respReady = MuxOH(selected, slaveList.map(_.PREADY))
    val useError  = slaveList.head.PSLVERROR != null
    val respError = if (useError) MuxOH(selected, slaveList.map(_.PSLVERROR)) else False

    // 没有命中任何从设备：立刻以错误结束，避免主设备无限等待
    val finalReady = Mux(anySelected, respReady, True)
    val finalError = Mux(anySelected, respError, True)

    for (m <- 0 until masterCount) {
      val apb = masterList(m)
      apb.PRDATA := respData
      // 只有「正在访问 + 已获授权」的主设备才可能看到 PREADY，
      // 其余主设备一律等待（PREADY = 0）
      apb.PREADY := apb.PSEL.lsb && granted(m) && finalReady
      if (useError) {
        apb.PSLVERROR := apb.PSEL.lsb && granted(m) && finalError
      }
    }
  }
}

// -------------------------------------------
// 2 主 8 从 APB 互连
// -------------------------------------------

case class Apb3Crossbar_2x8() extends Component {

  val apbConfig = Apb3Config(
    addressWidth  = 32,
    dataWidth     = 32,
    selWidth      = 1,
    useSlaveError = true
  )

  val io = new Bundle {
    val apbIn  = Vec(slave(Apb3(apbConfig)), size = 2)
    val apbOut = Vec(master(Apb3(apbConfig)), size = 8)
  }

  noIoPrefix()

  val apbCrossBar = Apb3CrossbarFactory()

  apbCrossBar.addSlaves(
    (io.apbOut(0), SizeMapping(0x00000000L, 4 KiB)),   //sram
    (io.apbOut(1), SizeMapping(0x00001000L, 4 KiB)),   //uart
    (io.apbOut(2), SizeMapping(0x00002000L, 4 KiB)),   //spi
    (io.apbOut(3), SizeMapping(0x00003000L, 4 KiB)),   //i2c
    (io.apbOut(4), SizeMapping(0x00004000L, 4 KiB)),   //gpio
    (io.apbOut(5), SizeMapping(0x00005000L, 4 KiB)),   //timer
    (io.apbOut(6), SizeMapping(0x00006000L, 4 KiB)),   //dma
    (io.apbOut(7), SizeMapping(0x00007000L, 4 KiB))    //confreg
  )

  apbCrossBar.addConnections(
    io.apbIn(0) -> List(io.apbOut(0), io.apbOut(1), io.apbOut(2), io.apbOut(3),
                        io.apbOut(4), io.apbOut(5), io.apbOut(6), io.apbOut(7)),
    io.apbIn(1) -> List(io.apbOut(0), io.apbOut(1), io.apbOut(2), io.apbOut(3),
                        io.apbOut(4), io.apbOut(5), io.apbOut(6), io.apbOut(7))
  )

  apbCrossBar.build()
}

// -------------------------------------------

object genApb2x8 extends App {

  Config.spinal.generateVerilog(Apb3Crossbar_2x8())
}
