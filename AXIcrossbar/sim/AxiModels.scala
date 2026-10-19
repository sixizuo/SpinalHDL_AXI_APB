package test

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._

// =============================================================================
//  AXI 仿真模型 —— 与被测互连完全解耦的两个独立组件
//
//  本文件里只有两类东西：
//
//      AxiMasterModel   主设备行为模型：发 burst → 读回来 → 逐拍自检
//      AxiSlaveModel    从设备行为模型：一块真内存 + 标准 AXI4 从端握手
//
//  它们不引用 AxiCrossbar_2x8，也不知道互连长什么样；
//  生成入口 genAxiModels 把每个组件单独输出成一个 .v 文件，
//  到 Vivado 侧再由手写的 tb_axi_top.v 用「模块实例化」接起来。
//
//  这样拆的理由：
//    · 互连 RTL（verilog/AxiCrossbar_2x8.v）可以独立交付、独立综合，
//      不会因为「附带了一个 testbench」而变成不可综合的模块；
//    · 模型换个互连照样能用 —— 只要 AXI4 端口对得上；
//    · 每个 .v 只有一个模块，波形层次干净，改一个模型不会牵动另一个。
//
//  ---------------------------------------------------------------------------
//  模型的「可调参数」分两类，别混
//  ---------------------------------------------------------------------------
//    编译期（写在构造参数里，改完要重新生成 Verilog）
//        config  —— 位宽（地址/数据/ID）
//        rounds  —— 每个主设备做几轮
//        beats   —— 每个 burst 几拍（AXI）/ 每轮几个字（APB）
//
//    运行期（做成了输入端口，Verilog 里直接给常量，不用重生成）
//        base    —— 起始字节地址
//        stride  —— 每轮的地址跨度
//        seed    —— 数据种子
//        id      —— AXI ID（APB 没有这个口）
//
//  这样学生要试「换个地址段」「两个主设备抢同一段地址」时，
//  只改 tb_axi_top.v 里的例化参数就够了，不必回到 WSL 重新生成。
// =============================================================================

/** 模型与互连必须对齐的位宽约定
  *
  * 关键点：互连输出侧的 ID 比输入侧宽 1 位。
  *   2 个主设备 → 互连要把「主设备序号」拼到 ID 高位才能把响应路由回去
  *   （log2Up(2) = 1 位）。所以：
  *       主设备模型用 inConfig （id 4 位）
  *       从设备模型用 outConfig（id 5 位）
  *   这两个配置必须和 Axicrossbar.scala 里的一致，否则实例化时端口位宽对不上。
  */
object AxiModelCfg {
  val addressWidth = 32
  val dataWidth    = 32
  val idWidthIn    = 4
  val idWidthOut   = idWidthIn + 1

  val inConfig = Axi4Config(
    addressWidth = addressWidth,
    dataWidth    = dataWidth,
    idWidth      = idWidthIn,
    useRegion    = false,
    useQos       = false
  )
  val outConfig = Axi4Config(
    addressWidth = addressWidth,
    dataWidth    = dataWidth,
    idWidth      = idWidthOut,
    useRegion    = false,
    useQos       = false
  )

  /** 每个主设备做几轮 */
  val rounds = 8
  /** 每个 burst 几拍 */
  val beats = 4
  /** 每个从设备模型的内存深度（单位：32 位字）= 256 KiB */
  val wordCount = 65536
}

/** 从设备行为模型：一块真内存 + 标准 AXI4 从端握手
  *
  * 只用了可综合写法（Mem + 寄存器 + 计数器），没有任何 spinal.core.sim 的东西。
  *
  * 支持：
  *   · 单拍 / 多拍 INCR burst 的读写
  *   · 按 WSTRB 整字写入（本模型的主设备永远整字写，不做读改写）
  */
case class AxiSlaveModel(config: Axi4Config, wordCount: Int) extends Component {
  val wordAddrWidth = log2Up(wordCount)
  val bytePerBeat   = config.dataWidth / 8

  val io = new Bundle {
    val axi = slave(Axi4(config))
  }

  val mem = Mem(Bits(config.dataWidth bits), wordCount)

  // ---------------------------------------------------------------- 写通道
  //
  //  【三个踩过的坑，改这段之前先看完】
  //
  //  坑 1：把「收 W」和「落盘 + 撤 wValid」写在同一拍的先后两个 when 里，
  //        wValid 会被同一个 always 块赋两次（先 True 后 False），SpinalHDL 里
  //        后者优先 → wValid 永远起不来 → 从设备不回 B → 整个仿真死锁。
  //        正确做法：收、执行分成两个【不同拍】的阶段（见下面两段 when）。
  //
  //  坑 2：mem 是同步读（readSync 的数据下一拍才出来），
  //        想按 WSTRB 做「读旧值 + 合并」必须多插一拍流水。
  //        本模型的主设备永远整字写（strb 全 1），所以直接整字覆盖。
  //
  //  坑 3：写使能不能靠 when 作用域「顺手带上」，要写成显式表达式
  //        （见下面 mem.write 的 enable 参数），否则生成出来是常数 1。
  //
  //  结构：
  //      AW 握手 → 锁住地址与 ID
  //      W 握手  → 整字落盘；wLast=1 则回 B，否则地址 +4
  //      B 握手  → 撤 bValid，收工
  //
  val awValid = Reg(Bool()) init False
  val awAddr  = Reg(UInt(config.addressWidth bits)) init 0
  val awId    = Reg(UInt(config.idWidth bits)) init 0
  val bValid  = Reg(Bool()) init False

  io.axi.aw.ready := !awValid && !bValid
  when(io.axi.aw.valid && io.axi.aw.ready) {
    awValid := True
    awAddr  := io.axi.aw.payload.addr
    awId    := io.axi.aw.payload.id
  }

  io.axi.w.ready := awValid && !bValid

  mem.write(awAddr(wordAddrWidth + 1 downto 2),
            io.axi.w.payload.data,
            enable = io.axi.w.valid && io.axi.w.ready)

  when(io.axi.w.valid && io.axi.w.ready) {
    when(io.axi.w.payload.last) {
      awValid := False
      bValid  := True
    } otherwise {
      awAddr := awAddr + bytePerBeat
    }
  }

  io.axi.b.valid        := bValid
  io.axi.b.payload.resp := 0 // OKAY
  // ★ B 必须回显 AW 带来的完整 ID —— 这里踩过一个真 bug：
  //   互连会把「主设备序号」拼在 ID 高位发给从设备，响应回来时靠这个高位
  //   路由回主设备。旧代码把 b.id 硬编码成 0，于是主设备 1 的写响应被解码成
  //   「属于主设备 0」，主设备 1 永远等不到自己的 B → 仿真卡死、led_done 恒 0。
  io.axi.b.payload.id := awId
  when(bValid && io.axi.b.ready) {
    bValid := False
  }

  // ---------------------------------------------------------------- 读通道
  //
  //  【这里坑最深，靠波形才看出来，结构别改】
  //
  //  Mem.readSync 的语义是：端口在时钟沿把 mem[地址] 打进输出寄存器，
  //  所以端口上看到的永远是「上一拍那个地址」的数据：
  //      rPort(本拍) = mem[ 上一拍的地址 ]
  //
  //  旧写法是「AR 握手那一拍就 rData := mem.readSync(...)」，现象非常迷惑：
  //  首拍对、第二拍对，从第三拍起每一拍都重复上一拍的数据
  //  （读回 1000 1001 1001 1002），而 rvalid / rready 完全正常、没有卡顿。
  //
  //  正确结构：把「发起读」和「收数据」拆成两拍，用两个单拍脉冲串起来
  //      rIssue  = 1 的那拍：端口发起读
  //      rIssueD = 1 的那拍：端口数据已到 → 锁进 rData，同时拉 rValid
  //      rValid && r.ready ：被收走；还有下一拍就重新 rIssue
  //
  //  代价是每拍多花两拍（4 拍 burst 要走 12 拍），仿真里完全无所谓。
  //
  val rValid  = Reg(Bool()) init False
  val rData   = Reg(Bits(config.dataWidth bits)) init 0
  val rRemain = Reg(UInt(8 bits)) init 0
  val rId     = Reg(UInt(config.idWidth bits)) init 0
  val rAddr   = Reg(UInt(config.addressWidth bits)) init 0
  val rIssue  = Reg(Bool()) init False
  val rIssueD = RegNext(rIssue, False)

  val rPort = mem.readSync(rAddr(wordAddrWidth + 1 downto 2),
                           enable = rIssue, clockCrossing = true)

  io.axi.ar.ready := !rValid && !rIssue && !rIssueD

  rIssue := False

  when(io.axi.ar.valid && io.axi.ar.ready) {
    rAddr   := io.axi.ar.payload.addr
    rIssue  := True
    rRemain := io.axi.ar.payload.len + 1
    rId     := io.axi.ar.payload.id
  }

  when(rIssueD) {
    rData  := rPort
    rValid := True
  }

  when(rValid && io.axi.r.ready) {
    when(rRemain === 1) {
      rValid := False
    } otherwise {
      rRemain := rRemain - 1
      rAddr   := rAddr + bytePerBeat
      rIssue  := True
      rValid  := False
    }
  }

  io.axi.r.valid        := rValid
  io.axi.r.payload.data := rData
  io.axi.r.payload.resp := 0 // OKAY
  io.axi.r.payload.last := (rRemain === 1)
  io.axi.r.payload.id   := rId
}

/** 主设备行为模型 + 自检
  *
  * 行为：对 base 地址做 rounds 轮
  *         写 beats 拍（第 round 轮第 beat 拍的数据 = seed + round*0x100 + beat）
  *         再把同样长度读回来
  *         逐拍比对，不一致就累加 errCnt 并锁存 error（sticky）
  *       全部做完后停在 IDLE，不再产生新事务。
  *
  * 端口约定（Verilog 侧看到的名字）：
  *     io_base/io_stride/io_seed/io_id   激励参数，给常量即可
  *     io_busy / io_error / io_done      状态，TB 用它们判定 PASS/FAIL
  */
case class AxiMasterModel(config: Axi4Config, rounds: Int, beats: Int) extends Component {

  val bytePerBeat = config.dataWidth / 8

  val io = new Bundle {
    val axi    = master(Axi4(config))
    val base   = in UInt (config.addressWidth bits)
    val stride = in UInt (config.addressWidth bits)
    val seed   = in Bits (config.dataWidth bits)
    val id     = in UInt (config.idWidth bits)
    val busy   = out Bool()
    val error  = out Bool()
    val done   = out Bool()
  }

  object St extends SpinalEnum {
    val IDLE, AW, W, B, AR, R, NEXT = newElement()
  }
  import St._

  val state  = Reg(St()) init IDLE
  val round  = Reg(UInt(16 bits)) init 0
  val beatR  = Reg(UInt(8 bits)) init 0

  val addrR  = Reg(UInt(config.addressWidth bits)) init 0
  val errCnt = Reg(UInt(16 bits)) init 0
  val doneR  = Reg(Bool()) init False

  val errorR = Reg(Bool()) init False
  errorR := errorR || (errCnt =/= 0)

  io.error := errorR
  io.done  := doneR
  io.busy  := (state =/= IDLE)

  // 第 round 轮第 beat 拍应当写/读的数据
  def expected(rd: UInt, bt: UInt): Bits =
    (io.seed.asUInt + (rd << 8) + bt).resize(config.dataWidth).asBits

  // 第 round 轮的起始地址
  def roundBase(rd: UInt): UInt =
    (io.base + io.stride * rd).resize(config.addressWidth)

  // 默认全部撤下
  io.axi.aw.valid := False
  io.axi.aw.payload.assignDontCare()
  io.axi.w.valid  := False
  io.axi.w.payload.assignDontCare()
  io.axi.b.ready  := False
  io.axi.ar.valid := False
  io.axi.ar.payload.assignDontCare()
  io.axi.r.ready  := False

  switch(state) {
    is(IDLE) {
      when(!doneR) {
        state := AW
        beatR := 0
        addrR := roundBase(round)
      }
    }

    is(AW) {
      io.axi.aw.valid        := True
      io.axi.aw.payload.addr := addrR
      io.axi.aw.payload.id   := io.id
      io.axi.aw.payload.len  := beats - 1
      io.axi.aw.payload.size := log2Up(bytePerBeat)
      io.axi.aw.payload.burst := 1 // INCR
      when(io.axi.aw.ready) {
        state := W
        beatR := 0
      }
    }

    is(W) {
      io.axi.w.valid        := True
      io.axi.w.payload.data := expected(round, beatR)
      io.axi.w.payload.strb := (BigInt(1) << bytePerBeat) - 1 // 整拍全写：0xF
      io.axi.w.payload.last := (beatR === beats - 1)
      when(io.axi.w.ready) {
        when(beatR === beats - 1) {
          state := B
        } otherwise {
          beatR := beatR + 1
        }
      }
    }

    is(B) {
      io.axi.b.ready := True
      when(io.axi.b.valid) {
        state := AR
        beatR := 0
        addrR := roundBase(round)
      }
    }

    is(AR) {
      io.axi.ar.valid        := True
      io.axi.ar.payload.addr := addrR
      io.axi.ar.payload.id   := io.id
      io.axi.ar.payload.len  := beats - 1
      io.axi.ar.payload.size := log2Up(bytePerBeat)
      io.axi.ar.payload.burst := 1
      when(io.axi.ar.ready) {
        state := R
        beatR := 0
      }
    }

    is(R) {
      io.axi.r.ready := True
      when(io.axi.r.valid) {
        when(io.axi.r.payload.data =/= expected(round, beatR)) {
          errCnt := errCnt + 1
        }
        when(beatR === beats - 1) {
          state := NEXT
        } otherwise {
          beatR := beatR + 1
        }
      }
    }

    is(NEXT) {
      when(round === rounds - 1) {
        doneR := True
        state := IDLE
      } otherwise {
        round := round + 1
        state := AW
        beatR := 0
        addrR := roundBase(round + 1)
      }
    }
  }
}

// =============================================================================
//  生成入口
//      sbt "runMain test.genAxiModels"
//  产物（hw/gen/，由 13 脚本回传到 AXIcrossbar/verification/models/）
//      AxiMasterModel.v     主设备模型
//      AxiSlaveModel.v      从设备模型
//
//  注意：每个 generateVerilog 单独 new 一个 SpinalConfig。
//        复用同一个 config 连续生成两次，第二次的 targetDirectory 状态容易出岔子。
// =============================================================================
object genAxiModels extends App {

  def gen(c: => Component): Unit = {
    val cfg = SpinalConfig(
      targetDirectory = "hw/gen",
      defaultConfigForClockDomains = ClockDomainConfig(
        clockEdge        = RISING,
        resetKind        = ASYNC,
        resetActiveLevel = LOW
      ),
      onlyStdLogicVectorAtTopLevelIo = true
    )
    cfg.generateVerilog(c)
  }

  gen(AxiMasterModel(AxiModelCfg.inConfig, AxiModelCfg.rounds, AxiModelCfg.beats))
  gen(AxiSlaveModel(AxiModelCfg.outConfig, AxiModelCfg.wordCount))
}
