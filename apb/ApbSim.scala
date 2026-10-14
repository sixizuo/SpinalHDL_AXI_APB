package test

import spinal.core._
import spinal.core.sim._
import spinal.lib._
import spinal.lib.bus.amba3.apb._

// -------------------------------------------
// APB 互连仿真
//
// 主设备与从设备都在仿真里产生，不参与综合：
//   - 从设备：用纯 Scala 数组当寄存器堆，在时钟采样点上组合地给出
//             PRDATA / PREADY / PSLVERROR
//   - 主设备：用 fork 线程按 APB 三拍时序（IDLE → SETUP → ACCESS）
//             直接驱动 dut.io.apbIn(m)
//
// 两个主设备同时启动，必然争抢同一条内部总线，
// 用来观察轮询仲裁把并发请求串行化。
// -------------------------------------------

object ApbSim extends App {

  val MASTER_COUNT = 2
  val SLAVE_COUNT  = 8
  val WORD_COUNT   = 8

  Config.sim.compile(Apb3Crossbar_2x8()).doSim { dut =>
    val clockDomain = dut.clockDomain

    clockDomain.forkStimulus(10)

    // ---------------- 从设备寄存器堆（仿真专用） ----------------
    val mem = Array.ofDim[Int](SLAVE_COUNT, WORD_COUNT)

    // ---------------- 主设备端口初值 ----------------
    for (m <- 0 until MASTER_COUNT) {
      val apb = dut.io.apbIn(m)
      apb.PSEL(0) #= false
      apb.PENABLE #= false
      apb.PADDR   #= 0
      apb.PWRITE  #= false
      apb.PWDATA  #= 0
    }

    // ========================================================================
    // 从设备：在仿真里产生
    //   零等待从设备 —— 只要处在 ACCESS 相位就给出 PRDATA 与 PREADY
    // ========================================================================
    fork {
      clockDomain.onSamplings {
        for (s <- 0 until SLAVE_COUNT) {
          val apb    = dut.io.apbOut(s)
          val sel    = apb.PSEL(0).toBoolean
          val enable = apb.PENABLE.toBoolean
          val access = sel && enable
          val index  = (apb.PADDR.toInt >> 2) & (WORD_COUNT - 1)

          // 写事务在 ACCESS 相位落盘
          if (access && apb.PWRITE.toBoolean) {
            mem(s)(index) = apb.PWDATA.toInt
          }

          apb.PRDATA    #= mem(s)(index)
          apb.PREADY    #= access
          apb.PSLVERROR #= false
        }
      }
    }

    // ========================================================================
    // 总线观察：竞争与轮转统计
    // ========================================================================
    var lastFinisher = -1
    var switchCount  = 0
    var contention   = false

    fork {
      clockDomain.onSamplings {
        var finisher = -1
        var requests = 0
        for (m <- 0 until MASTER_COUNT) {
          val apb = dut.io.apbIn(m)
          if (apb.PSEL(0).toBoolean) requests += 1
          if (apb.PSEL(0).toBoolean && apb.PENABLE.toBoolean && apb.PREADY.toBoolean) finisher = m
        }
        if (requests >= 2) contention = true
        if (finisher >= 0) {
          if (lastFinisher >= 0 && lastFinisher != finisher) switchCount += 1
          lastFinisher = finisher
        }
      }
    }

    // ========================================================================
    // 主设备：在仿真里产生
    //   标准 APB 时序 —— IDLE → SETUP（PSEL=1，PENABLE=0）
    //                        → ACCESS（PENABLE=1，等 PREADY）
    // ========================================================================
    def apbWrite(m: Int, addr: Int, data: Int): Unit = {
      val apb = dut.io.apbIn(m)

      apb.PSEL(0) #= true
      apb.PENABLE #= false
      apb.PADDR   #= addr
      apb.PWRITE  #= true
      apb.PWDATA  #= data
      clockDomain.waitSampling()                    // SETUP

      apb.PENABLE #= true
      clockDomain.waitSampling()                    // ACCESS
      while (!apb.PREADY.toBoolean) clockDomain.waitSampling()

      // 回 IDLE 一拍，把总线让出来，轮询仲裁才有机会轮转
      apb.PSEL(0) #= false
      apb.PENABLE #= false
      clockDomain.waitSampling()
    }

    def apbRead(m: Int, addr: Int): Int = {
      val apb = dut.io.apbIn(m)

      apb.PSEL(0) #= true
      apb.PENABLE #= false
      apb.PADDR   #= addr
      apb.PWRITE  #= false
      clockDomain.waitSampling()                    // SETUP

      apb.PENABLE #= true
      clockDomain.waitSampling()                    // ACCESS
      while (!apb.PREADY.toBoolean) clockDomain.waitSampling()
      val data = apb.PRDATA.toInt

      apb.PSEL(0) #= false
      apb.PENABLE #= false
      clockDomain.waitSampling()

      data
    }

    // 两个主设备访问不同的从设备窗口，数据互不干扰：
    //   主设备 0 → apbOut(0)，0x0000_0000 起
    //   主设备 1 → apbOut(4)，0x0000_4000 起
    val windowOf = (m: Int) => m * 4 * 0x1000
    val seedOf   = (m: Int) => 0x12340000 + m * 0x00100000

    val finished = new java.util.concurrent.atomic.AtomicIntegerArray(MASTER_COUNT)
    val badData  = new java.util.concurrent.atomic.AtomicIntegerArray(MASTER_COUNT)

    for (m <- 0 until MASTER_COUNT) {
      fork {
        val window = windowOf(m)
        val seed   = seedOf(m)

        // 先按序写
        for (i <- 0 until WORD_COUNT) {
          apbWrite(m, window + i * 4, seed + i)
        }

        // 再按序读回比对
        for (i <- 0 until WORD_COUNT) {
          val got      = apbRead(m, window + i * 4)
          val expected = seed + i
          if (got != expected) {
            println(f"[FAIL] 主设备 $m 地址 0x${window + i * 4}%08x 期望 0x$expected%08x 实际 0x$got%08x")
            badData.set(m, 1)
          }
        }

        finished.set(m, 1)
      }
    }

    // ========================================================================
    // 收尾：等两个主设备跑完，然后检查结果
    // ========================================================================
    var cycles = 0
    while (cycles < 200000 && (0 until MASTER_COUNT).exists(m => finished.get(m) == 0)) {
      clockDomain.waitSampling()
      cycles += 1
    }

    assert((0 until MASTER_COUNT).forall(m => finished.get(m) == 1),
      s"仿真超时：主设备没有跑完（已等 $cycles 个时钟周期），可能出现了死锁")

    var failed = false
    for (m <- 0 until MASTER_COUNT) {
      if (badData.get(m) == 1) failed = true
    }
    assert(!failed, "读回数据校验失败，从设备返回的内容与写入的不一致")

    println(s"[PASS] 2 个主设备在 $cycles 个时钟周期内全部完成")
    println(s"[PASS] 读回数据全部一致（每个主设备 ${WORD_COUNT} 个字）")
    if (contention) {
      println(s"[PASS] 观测到两个主设备同时请求总线")
    } else {
      println("[INFO] 未观测到两个主设备同时请求总线，仲裁路径未被覆盖")
    }
    println(s"[INFO] 总线在 主设备0 / 主设备1 之间交替了 $switchCount 次")
  }
}
