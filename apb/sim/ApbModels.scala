package test

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba3.apb._

// =============================================================================
//  APB 仿真模型 —— 与 AXI 那份同构，只是总线换成 APB3
//
//      ApbMasterModel   主设备行为模型：写一轮 → 立刻读回 → 逐字自检
//      ApbSlaveModel    从设备行为模型：一组 32 位寄存器堆
//
//  生成入口 genApbModels 各自输出独立 .v，Vivado 侧由 tb_apb_top.v 实例化。
//
//  ---------------------------------------------------------------------------
//  APB 的时序比 AXI 简单，但有两个必须守住的约束
//  ---------------------------------------------------------------------------
//    约束 1：每轮的地址窗口必须够放下这一轮的所有字
//              stride 端口 >= words * 4
//            各轮窗口一旦重叠，第 0 轮写的数据会被第 1 轮覆盖，
//            读回必然失败 —— 而且波形上看不出任何异常握手，很容易误判成
//            「互连坏了」。这条以前是 Scala 里的 require 检查；
//            现在 stride 改成端口了，编译器管不到，只能靠这里写清楚。
//
//    约束 2：每个字之间要插一拍 GAP（PSEL=0）
//            两个主设备的请求才会真正交错；否则一个主设备会一直占着总线，
//            「互连」等于没被验证到。
// =============================================================================

object ApbModelCfg {
  val addressWidth = 32
  val dataWidth    = 32
  val selWidth     = 1

  val config = Apb3Config(
    addressWidth  = addressWidth,
    dataWidth     = dataWidth,
    selWidth      = selWidth,
    useSlaveError = true
  )

  /** 每个主设备做几轮 */
  val rounds = 4
  /** 每轮写/读几个字 */
  val words = 8
  /** 从设备模型寄存器堆深度（单位：32 位字） */
  val wordCount = 256
}

/** 从设备模型：WORD_COUNT 个 32 位寄存器的寄存器堆
  *
  * ACCESS 相位（PSEL=1 && PENABLE=1）时：
  *   · PWRITE=1 → 把 PWDATA 写进 PADDR 指向的寄存器
  *   · PREADY=1（零等待），PRDATA 组合地给出读出的内容
  */
case class ApbSlaveModel(config: Apb3Config, wordCount: Int) extends Component {
  val addrWidth = log2Up(wordCount)

  val io = new Bundle {
    val apb = slave(Apb3(config))
  }

  io.apb.PREADY    := False
  io.apb.PRDATA    := 0
  io.apb.PSLVERROR := False

  val regs = Vec(Reg(Bits(config.dataWidth bits)) init 0, wordCount)

  val sel    = io.apb.PSEL.asBits.orR
  val access = sel && io.apb.PENABLE
  val idx    = io.apb.PADDR(addrWidth + 1 downto 2).resize(addrWidth)

  when(access) {
    io.apb.PREADY := True

    when(io.apb.PWRITE) {
      regs(idx) := io.apb.PWDATA
    } otherwise {
      io.apb.PRDATA := regs(idx)
    }
  }
}

/** 主设备行为模型 + 自检
  *
  * 每个字之间插一拍 GAP，让两个主设备能真正交错。
  * 状态机只有 4 个状态，写/读阶段靠 wrPhase 区分：
  *     IDLE → [SETUP → ACCESS → GAP] × words → 换阶段 → …
  *     SETUP ：PSEL=1, PENABLE=0（符合 APB 规范，也给互连的相位重定时留一拍）
  *     ACCESS：PSEL=1, PENABLE=1，等 PREADY
  *     GAP   ：PSEL=0，把总线让出去一拍
  *
  * 端口约定同 AXI：io_base/io_stride/io_seed 给常量，io_busy/io_error/io_done 用来判定。
  */
case class ApbMasterModel(config: Apb3Config, rounds: Int, words: Int) extends Component {

  val io = new Bundle {
    val apb    = master(Apb3(config))
    val base   = in UInt (config.addressWidth bits)
    val stride = in UInt (config.addressWidth bits)
    val seed   = in Bits (config.dataWidth bits)
    val busy   = out Bool()
    val error  = out Bool()
    val done   = out Bool()
  }

  object St extends SpinalEnum {
    val IDLE, SETUP, ACCESS, GAP = newElement()
  }
  import St._

  val state   = Reg(St()) init IDLE
  val round   = Reg(UInt(16 bits)) init 0
  val idx     = Reg(UInt(8 bits)) init 0
  val wrPhase = Reg(Bool()) init True // True = 写阶段，False = 读回阶段

  val errCnt = Reg(UInt(16 bits)) init 0
  val doneR  = Reg(Bool()) init False

  // sticky：只要出现过一次比对失败，error 就永久为 1
  val errorR = Reg(Bool()) init False
  errorR := errorR || (errCnt =/= 0)

  io.error := errorR
  io.done  := doneR
  io.busy  := (state =/= IDLE)

  // 第 rd 轮第 ix 个字应当写/读的数据
  def expected(rd: UInt, ix: UInt): Bits =
    (io.seed.asUInt + (rd << 4) + ix).resize(config.dataWidth).asBits

  // 第 rd 轮的起始地址
  def roundBase(rd: UInt): UInt =
    (io.base + io.stride * rd).resize(config.addressWidth)

  // 第 rd 轮第 ix 个字的字节地址
  def wordAddr(rd: UInt, ix: UInt): UInt =
    (roundBase(rd) + (ix * 4).resize(config.addressWidth)).resize(config.addressWidth)

  // 默认全部撤下（未在 switch 里显式驱动的状态自动保持这个值）
  io.apb.PSEL    := 0
  io.apb.PENABLE := False
  io.apb.PADDR   := 0
  io.apb.PWRITE  := False
  io.apb.PWDATA  := 0

  switch(state) {
    is(IDLE) {
      when(!doneR) {
        state   := SETUP
        round   := 0
        idx     := 0
        wrPhase := True
      }
    }

    is(SETUP) {
      io.apb.PSEL    := 1
      io.apb.PENABLE := False
      io.apb.PADDR   := wordAddr(round, idx)
      io.apb.PWRITE  := wrPhase
      io.apb.PWDATA  := expected(round, idx)
      state := ACCESS
    }

    is(ACCESS) {
      io.apb.PSEL    := 1
      io.apb.PENABLE := True
      io.apb.PADDR   := wordAddr(round, idx)
      io.apb.PWRITE  := wrPhase
      io.apb.PWDATA  := expected(round, idx)
      when(io.apb.PREADY) {
        // 只有读回阶段才比对；写阶段不需要看 PRDATA
        when(!wrPhase && io.apb.PRDATA =/= expected(round, idx)) {
          errCnt := errCnt + 1
        }
        state := GAP
      }
    }

    is(GAP) {
      io.apb.PSEL    := 0
      io.apb.PENABLE := False
      when(idx === words - 1) {
        when(wrPhase) {
          // 写 → 读：立刻读回本轮刚写的这些字
          wrPhase := False
          idx     := 0
        } otherwise {
          when(round === rounds - 1) {
            doneR := True
          } otherwise {
            round   := round + 1
            idx     := 0
            wrPhase := True
          }
        }
      } otherwise {
        idx := idx + 1
      }
    }
  }
}

// =============================================================================
//  生成入口
//      sbt "runMain test.genApbModels"
//  产物（hw/gen/，由 23 脚本回传到 apb/verification/models/）
//      ApbMasterModel.v
//      ApbSlaveModel.v
// =============================================================================
object genApbModels extends App {

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

  gen(ApbMasterModel(ApbModelCfg.config, ApbModelCfg.rounds, ApbModelCfg.words))
  gen(ApbSlaveModel(ApbModelCfg.config, ApbModelCfg.wordCount))
}
