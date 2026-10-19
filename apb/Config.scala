package test

import spinal.core._
import spinal.core.sim._

import java.io.File

object Config {
  def spinal = SpinalConfig(
    targetDirectory = "hw/gen",
    defaultConfigForClockDomains = ClockDomainConfig(
      clockEdge= RISING,
      resetKind= ASYNC,
      resetActiveLevel = LOW
    ),
    onlyStdLogicVectorAtTopLevelIo = true
  )

  // ------------------------------------------------------------------
  // 仿真波形格式：优先 FST，检测不到 zlib 时自动降级为 VCD
  //
  // 为什么需要这件事：
  //   Verilator 开启 FST 波形（--trace-fst）时会额外编译 verilated_fst_c.cpp，
  //   而这个文件 #include <zlib.h>，所以系统必须装有 zlib 开发头文件
  //   （Debian/Ubuntu 上是 zlib1g-dev）。没装的话，仿真会在一开始就崩：
  //       fatal error: zlib.h: No such file or directory
  //       make: *** [verilated.mk:281: verilated_fst_c.o] Error 1
  //   VCD 是纯文本格式，不需要 zlib，因此可作为兜底。
  //
  // 效果：有 zlib.h → FST（波形文件小、写盘快）；没有 → VCD（仿真照样能跑）。
  // 装上 zlib1g-dev 之后会自动回到 FST，不用改代码。
  // 若 zlib 装在非标准路径，可用环境变量指出来：
  //       export ZLIB_INC_DIR=/opt/zlib/include
  // ------------------------------------------------------------------
  def zlibIncludeDirs: List[String] =
    List("/usr/include", "/usr/local/include") ++
      sys.env.get("ZLIB_INC_DIR").toList
        .flatMap(_.split("[ ,;:]+").toList).filter(_.nonEmpty)

  def hasZlibHeader: Boolean =
    zlibIncludeDirs.exists(d => new File(d, "zlib.h").exists())

  // SPINAL_SIM_WAVE 可以强制指定波形格式，排错时用：
  //   fst  —— 强制 FST（需要 zlib.h）
  //   vcd  —— 强制 VCD（不需要 zlib）
  //   none —— 完全不生成波形（最省事；某些 Verilator 版本在开波形时会崩，可先用它绕开）
  //   auto / 不设 —— 上面的自动探测（默认）
  def sim = {
    val cfg = SimConfig.withConfig(spinal)
    sys.env.getOrElse("SPINAL_SIM_WAVE", "auto").trim.toLowerCase match {
      case "none" | "off" | "0" =>
        println("[Config] SPINAL_SIM_WAVE=none —— 本次不生成波形")
        cfg
      case "vcd" =>
        println("[Config] SPINAL_SIM_WAVE=vcd —— 波形用 VCD（不需要 zlib）")
        cfg.withVcdWave
      case "fst" =>
        println("[Config] SPINAL_SIM_WAVE=fst —— 波形用 FST")
        cfg.withFstWave
      case _ =>
        if (hasZlibHeader) {
          cfg.withFstWave
        } else {
          println("[Config] 未找到 zlib.h，仿真波形降级为 VCD（不需要 zlib）。")
          println("[Config] 想用 FST（波形更小、写盘更快）请装：sudo apt install -y zlib1g-dev")
          cfg.withVcdWave
        }
    }
  }
}