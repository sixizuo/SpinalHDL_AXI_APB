# APB 多主多从互连（SpinalHDL）

2 个主设备、8 个从设备的 APB3 互连，代码组织形式与 `../AXIcrossbar` 的 AXI 版本保持一致。

## 文件

| 文件 | 对应 AXIcrossbar | 内容 |
|---|---|---|
| `Apbcrossbar.scala` | `Axicrossbar.scala` | 轮询仲裁器、互连工厂 `Apb3CrossbarFactory`、互连顶层 `Apb3Crossbar_2x8`、Verilog 生成入口 |
| `Config.scala` | `Config.scala` | 统一的 `SpinalConfig` 与 `SimConfig` |
| `ApbSim.scala` | — | 仿真：主设备激励与从设备响应都在这里产生 |

>`Config.scala` 与 `../AXIcrossbar/Config.scala` 内容完全相同。两个目录如果在同一个 sbt 工程里编译，这份文件只保留一份即可，否则会出现 `object Config` 重复定义。

## 代码组织

```scala
case class Apb3Crossbar_2x8() extends Component {
  val apbConfig = Apb3Config(addressWidth = 32, dataWidth = 32, selWidth = 1, useSlaveError = true)

  val io = new Bundle {
    val apbIn  = Vec(slave(Apb3(apbConfig)), size = 2)
    val apbOut = Vec(master(Apb3(apbConfig)), size = 8)
  }
  noIoPrefix()

  val apbCrossBar = Apb3CrossbarFactory()

  apbCrossBar.addSlaves(
    (io.apbOut(0), SizeMapping(0x00000000L, 4 KiB)),   //sram
    ...
  )

  apbCrossBar.addConnections(
    io.apbIn(0) -> List(io.apbOut(0), ..., io.apbOut(7)),
    io.apbIn(1) -> List(io.apbOut(0), ..., io.apbOut(7))
  )

  apbCrossBar.build()
}

object genApb2x8 extends App {
  Config.spinal.generateVerilog(Apb3Crossbar_2x8())
}
```

与 `Axi4CrossbarFactory` 一样是三步：`addSlaves` → `addConnections` → `build()`。

**代码里没有主设备和从设备类。** 互连本体只负责仲裁、译码、搬运信号；主设备的激励行为和从设备的响应行为都在仿真文件里产生。

要改从设备数量，在 `io.apbOut` 里增减元素、同步调整 `addSlaves` / `addConnections` 即可；工厂对数量没有限制（主设备 ≥ 2，从设备 ≥ 1）。

## 运行

```bash
sbt "runMain test.genApb2x8"     # 生成 Verilog，输出到 hw/gen/Apb3Crossbar_2x8.v
sbt "runMain test.ApbSim"        # 跑仿真自检，需要 Verilator 或 iverilog
```

## 生成的 Verilog 接口

```
apbIn_0_*   主设备 0（PADDR/PSEL/PENABLE/PWRITE/PWDATA 输入，PREADY/PRDATA/PSLVERROR 输出）
apbIn_1_*   主设备 1
apbOut_0_* ~ apbOut_7_*   8 个从设备（方向相反）
clk, resetn
```

| 从设备 | 地址窗口 | 从设备 | 地址窗口 |
|---|---|---|---|
| `apbOut(0)` | `0x0000_0000 ~ 0x0000_0FFF` | `apbOut(4)` | `0x0000_4000 ~ 0x0000_4FFF` |
| `apbOut(1)` | `0x0000_1000 ~ 0x0000_1FFF` | `apbOut(5)` | `0x0000_5000 ~ 0x0000_5FFF` |
| `apbOut(2)` | `0x0000_2000 ~ 0x0000_2FFF` | `apbOut(6)` | `0x0000_6000 ~ 0x0000_6FFF` |
| `apbOut(3)` | `0x0000_3000 ~ 0x0000_3FFF` | `apbOut(7)` | `0x0000_7000 ~ 0x0000_7FFF` |

## 设计要点

1. **轮询仲裁用优先级掩码实现** —— `mask` 中为 1 的位仍有竞争资格；授权之后把「被授权位及其低位」清零，下一次自然从下一位开始轮转。两个主设备不会互相饿死。

2. **holder 反压** —— 一次 APB 事务（`PSEL` 为高）期间总线锁定给同一主设备，中途不换人，从设备不会看到半个事务。

3. **从端口相位重定时** —— 多一级 `selectedD`（上一拍的选中情况），从设备总能先看到一拍 `PSEL=1 / PENABLE=0`（SETUP），再看到 `PENABLE=1`（ACCESS）。没有这一级，一直在 ACCESS 阶段等待、刚拿到总线的主设备会让从设备直接看到 `PENABLE=1`，缺了 APB 规范要求的 SETUP 相位。

4. **访问未映射地址立即报错** —— `PREADY=1` 加上 `PSLVERROR=1`，主设备不会死等。

5. **`addConnections` 可以做访问裁剪** —— 某个主设备没有列出的从设备，它的访问会被判为未映射并报错。这一版两个主设备都连接了全部 8 个从设备。

## 仿真里怎么产生主设备和从设备

`ApbSim.scala` 中：

- **从设备**：一个 `Array.ofDim[Int](8, 8)` 当寄存器堆，用 `clockDomain.onSamplings { ... }` 在时钟采样点上组合地给出 `PRDATA` / `PREADY` / `PSLVERROR`：

  ```scala
  fork {
    clockDomain.onSamplings {
      for (s <- 0 until SLAVE_COUNT) {
        val apb    = dut.io.apbOut(s)
        val access = apb.PSEL(0).toBoolean && apb.PENABLE.toBoolean
        val index  = (apb.PADDR.toInt >> 2) & (WORD_COUNT - 1)
        if (access && apb.PWRITE.toBoolean) mem(s)(index) = apb.PWDATA.toInt
        apb.PRDATA    #= mem(s)(index)
        apb.PREADY    #= access
        apb.PSLVERROR #= false
      }
    }
  }
  ```

- **主设备**：两个 `fork` 线程，每个线程用 `apbWrite` / `apbRead` 两个函数按标准三拍时序直接驱动 `dut.io.apbIn(m)`：

  ```scala
  apb.PSEL(0) #= true
  apb.PENABLE #= false        // SETUP
  clockDomain.waitSampling()
  apb.PENABLE #= true         // ACCESS
  clockDomain.waitSampling()
  while (!apb.PREADY.toBoolean) clockDomain.waitSampling()
  apb.PSEL(0) #= false
  apb.PENABLE #= false        // 回 IDLE 一拍，让出总线
  clockDomain.waitSampling()
  ```

  两个主设备上电后同时启动，分别访问窗口 0（`0x0000_0000`）和窗口 4（`0x0000_4000`），因此数据互不干扰，但会争抢同一条内部总线 —— 仿真里会打印总线在两个主设备之间的交替次数。

## 验证情况

- **编译**：Scala 2.12.20 + SpinalHDL 1.10.1，0 错误 0 警告
- **Verilog 生成**：通过，输出 `Apb3Crossbar_2x8.v`（291 行，1 个模块，74 个端口）
- **行为模型**（`verification/model_check.py`，纯 Python 周期精确）：两个主设备 65 个周期完成，18 个字全部读回一致，两从设备寄存器堆互不干扰，0 次 APB 相位违例，总线交替 31 次

仿真文件本身需要 Verilator 或 iverilog 才能运行，本机未安装，用上面的周期精确模型替代验证了逻辑。
