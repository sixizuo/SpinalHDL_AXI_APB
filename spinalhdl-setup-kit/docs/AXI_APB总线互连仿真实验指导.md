# SpinalHDL 总线互连（AXI4 / APB3）生成与 Vivado 仿真实验指导

> 适用版本：SpinalHDL 1.10.1 / Scala 2.12.20 / sbt 1.10 及以上 / JDK 17 / Vivado 2025.2（2024.x 亦可）
> 适用平台：Windows 11 + WSL2(Ubuntu) + VS Code
> 套件位置：`<仓库根>\spinalhdl-setup-kit`

---

## 0 实验总览

### 0.1 实验目标

本实验要完成四件事，缺一不可：

1. 用 SpinalHDL 生成**可独立使用**的 AXI4 与 APB3 总线互连 RTL（不含任何 testbench 内容）；
2. 用 SpinalHDL 生成**主设备 / 从设备行为模型**的 Verilog（同样独立成文件）；
3. 用**手写 Verilog 顶层**把这些模块按端口连起来，形成仿真激励平台；
4. 在 Windows 侧的 Vivado 里，用 **Tcl 脚本自动**建仿真工程、挂波形、跑仿真、判定 PASS/FAIL。

### 0.2 为什么这样分工

这是本实验最重要的一条设计原则，理解它后面的步骤就都顺了：

| 环节 | 在哪里做 | 为什么 |
|---|---|---|
| 写 RTL、生成 Verilog | WSL(Ubuntu) | sbt/JVM 在 ext4 上编译比在 `/mnt` 快数倍 |
| 仿真、看波形 | Windows(Vivado) | xsim 有图形化波形窗口，且 Vivado 只装在 Windows |
| 建工程、挂波形、判结果 | Windows，**全在 Tcl 里** | 手工点一遍要 30 秒，Tcl 一条命令 3 秒，还能重复 |

由此推出一条硬性约束：

> **四类 Verilog 文件永远不内联。** 总线 RTL、主模型、从模型、仿真顶层各自是独立文件，
> 只在 Verilog 层通过端口实例化相连。这样总线 RTL 能单独交付、单独综合，
> 模型换个互连照样能用，波形层次也干净。

### 0.3 目录与脚本编号

环境脚本独立编号（`00`~`02`），每条总线用独立号段：AXI 是 `10`~`14`，APB 是 `20`~`24`。
同号段内后缀含义一致，所以学会 AXI 那一套，APB 只是换个号。

```
<仓库根>/
├── AXIcrossbar/                        AXI 源码 + 产物
│   ├── Axicrossbar.scala               总线互连（被测对象）
│   ├── fifo.scala                      配套 FIFO
│   ├── Config.scala                    Verilog 输出目录 / 时钟复位风格
│   ├── sim/AxiModels.scala             主/从模型（与互连解耦）
│   ├── verilog/                        ① 总线 RTL 产物
│   │   ├── AxiCrossbar_2x8.v
│   │   └── Axi_CDC.v
│   └── verification/
│       ├── models/                     ② 模型产物
│       │   ├── AxiMasterModel.v
│       │   └── AxiSlaveModel.v
│       └── tb_axi_top.v                ③ 手写仿真顶层
├── apb/                                结构完全相同
│   ├── Apbcrossbar.scala / Config.scala
│   ├── sim/ApbModels.scala
│   ├── verilog/Apb3Crossbar_2x8.v
│   └── verification/
│       ├── models/ApbMasterModel.v, ApbSlaveModel.v
│       └── tb_apb_top.v
└── spinalhdl-setup-kit/
    ├── scripts/                        ← 在 WSL 里跑
    │   ├── lib/{common.sh,project_kit.sh}
    │   ├── env/01-install-toolchain.sh
    │   ├── env/02-vscode-extensions.sh
    │   ├── axi/{10,11,12,13}-*.sh
    │   └── apb/{20,21,22,23}-*.sh
    └── windows/                        ← 在 Windows 的 cmd 里跑
        ├── env/00-preflight.ps1
        ├── axi/{14-run-sim.cmd, 14-run-sim.tcl, 14-wave.tcl}
        └── apb/{24-run-sim.cmd, 24-run-sim.tcl, 24-wave.tcl}
```

脚本编号一览：

| 编号 | 作用 | 在哪跑 | 产物 |
|---|---|---|---|
| `00-preflight.ps1` | Windows 前置检查（只读） | Windows | 报告，不改系统 |
| `01-install-toolchain.sh` | 装 JDK17 / sbt / 镜像 | WSL | 工具链 |
| `02-vscode-extensions.sh` | 给 VS Code 装 Metals | WSL | 代码补全 |
| `10/20` | 建**总线** sbt 工程 | WSL | `~/spinalhdl-projects/{AXIcrossbar,apb}` |
| `11/21` | 生成**总线 RTL** | WSL | `verilog/*.v` |
| `12/22` | 建**激励** sbt 工程 | WSL | `~/spinalhdl-projects/{AXIcrossbar-sim,apb-sim}` |
| `13/23` | 生成**主/从模型** | WSL | `verification/models/*.v` |
| `14/24` | Vivado 建工程+仿真+判定 | Windows | `vivado-sim/<bus>/` |

### 0.4 产物清单

一次完整的实验跑完，仓库里会多出这些 Verilog，全部可以单独拿走：

| 类别 | AXI | APB | 是否可综合 |
|---|---|---|---|
| ① 总线 RTL | `AxiCrossbar_2x8.v`、`Axi_CDC.v` | `Apb3Crossbar_2x8.v` | 可综合，可直接交付 |
| ② 主设备模型 | `AxiMasterModel.v` | `ApbMasterModel.v` | 可综合（纯行为，但无 `initial` 时序） |
| ③ 从设备模型 | `AxiSlaveModel.v` | `ApbSlaveModel.v` | 可综合（内部有 `Mem`） |
| ④ 仿真顶层 | `tb_axi_top.v` | `tb_apb_top.v` | **不可综合**，只用于仿真 |

### 0.5 完整流程

```
WSL (Ubuntu)                                       Windows
──────────────────────────────────────────────     ──────────────────────────────
10 建总线工程 ──► 11 生成总线 RTL ──► verilog/*.v ─┐
                                                    │
12 建激励工程 ──► 13 生成模型 RTL ──► models/*.v ───┼──► 14 Tcl ──► Vivado 工程+波形+PASS/FAIL
                                                    │
                          tb_axi_top.v（手写，已在仓库）┘

APB 用 20/21/22/23 + 24，流程一模一样
```

---

## 第 1 章 实验环境搭建

### 1.1 Windows 侧：前置检查

在 Windows 上打开 **PowerShell（管理员）**：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
cd D:\SpinalHDL\spinalhdl-setup-kit\windows\env
.\00-preflight.ps1
```

这个脚本**只读**，不改任何系统设置。它检查 8 项：执行身份、Windows 版本、
CPU 虚拟化、WSL 与 Ubuntu、磁盘空间、VS Code + WSL 扩展、脚本与源码是否齐全、Vivado 位置。

正常输出长这样（关键行）：

```
=== 1. Windows 版本 ===
  [ OK ] Windows 11（Build 26300）—— 支持 wsl --install 一键安装
=== 2. 硬件虚拟化 ===
  [ OK ] Hypervisor 已启用
=== 3. WSL 功能与已安装的发行版 ===
  [ OK ] 已安装 Ubuntu 发行版
=== 6. 套件与源码目录 ===
  [ OK ] WSL 侧脚本齐全：...\scripts （共 10 个）
  [ OK ] Windows 侧仿真脚本齐全：...\windows
  [ OK ] AXI 源码目录齐全
  [ OK ] AXI 的 Verilog 产物齐全（RTL / 模型 / TB）
=== 7. Vivado ===
  [ OK ] 找到 2 个 Vivado：
         C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat
         C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat
```

**只要看到 Vivado 有多版本，就要留意 license。** `14-run-sim.cmd` 默认按版本号倒序取最新的，
如果最新那个没 license，会报 `Vivado Design Suite cannot be launched because a valid license was not found`。
解决办法是先指定：

```bat
set VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat
```

> **关于 `[FAIL] CPU 固件虚拟化未开启`**：如果 `wsl -l -v` 能正常列出 Ubuntu 并且 `VERSION` 是 `2`，
> 说明虚拟化实际是好的（脚本读的是 `Win32_Processor.VirtualizationFirmwareEnabled`，
> 某些新 CPU 上这个字段会误报）。真正装不上 WSL 时才需要进 BIOS 打开 VT-x / AMD-V。

如果还没装 WSL：

```powershell
wsl --install -d Ubuntu     # 装完必须重启
wsl -l -v                   # 确认 VERSION 列是 2
wsl --set-default-version 2
```

### 1.2 WSL 侧：安装工具链

打开 Ubuntu 终端（开始菜单里的「Ubuntu」，或在 Windows Terminal 里选 Ubuntu 标签）：

```bash
cd /mnt/d/SpinalHDL/spinalhdl-setup-kit
bash scripts/env/01-install-toolchain.sh
```

脚本做 7 件事，中间会要求输入**你在安装 Ubuntu 时设置的那个密码**：

1. apt 源改国内镜像（原文件备份成 `*.bak-<时间戳>`，可回滚）
2. 装 `git curl wget unzip zip ca-certificates`
3. 装 `openjdk-17-jdk-headless`
4. 装 sbt（apt 优先；apt 里没有时从 Maven 镜像取 `sbt-launch.jar`，生成 `~/.local/bin/sbt`）
5. 写 `~/.sbt/repositories` —— sbt 拉依赖走国内 Maven 镜像
6. 写 `~/.config/coursier/mirror.properties` —— Metals 下服务端走镜像
7. 打印汇总

常用选项：

```bash
bash scripts/env/01-install-toolchain.sh --no-mirror     # 全部走官方源
bash scripts/env/01-install-toolchain.sh --help
```

结束时应该看到：

```
==> 7/7 汇总
    java         openjdk version "17.0.x"
    javac        javac 17.0.x
    JAVA_HOME    /usr/lib/jvm/java-17-openjdk-amd64
    sbt          /usr/bin/sbt   （或 ~/.local/bin/sbt）
    git          git version 2.x
```

> **本套件刻意不装 Verilator / iverilog。** 仿真由 Vivado 的 xsim 负责；
> Verilator 属于旧的 SpinalSim 路线，apt 里的 5.x 与 SpinalHDL 1.10.1 不兼容，
> 而 iverilog 在 1.10.1 里被官方标注为不可用（"This backend doesn't work"）。

### 1.3 VS Code + Scala 补全

Windows 上：

1. 装 VS Code（安装时勾选「添加到 PATH」）
2. 扩展面板搜 `WSL`（`ms-vscode-remote.remote-wsl`）并安装
3. 左下角绿色按钮 → **Connect to WSL**
4. 连上后打开一个 WSL 终端，输入 `code` 应该有反应

然后回到 WSL 终端：

```bash
bash scripts/env/02-vscode-extensions.sh
```

它装两个扩展：

* `scalameta.metals` —— 语言服务（补全、跳转、报错）
* `scala-lang.scala` —— 官方语法高亮（是 Metals 的 extensionPack 成员，不冲突）

这个脚本**永远返回 0**：装不上也不影响后面的生成与仿真，只是写代码时少点补全。

打开工程时注意：

```bash
code ~/spinalhdl-projects/AXIcrossbar       # AXI 总线
code ~/spinalhdl-projects/AXIcrossbar-sim   # AXI 激励模型
code ~/spinalhdl-projects/apb               # APB 总线
code ~/spinalhdl-projects/apb-sim           # APB 激励模型
```

> 要打开**工程根目录**（里面有 `build.sbt`），不要打开 `hw/spinal/test` 子目录。
> 那个子目录里没有 `build.sbt`，Metals 会退化成「Scala CLI 单文件模式」，
> 报 `no build tool detected`，还留下 `.metals` / `.scala-build` 残留。

打开后 `Ctrl+Shift+P` → `Metals: Restart Build Server`，等左下角 Metals 图标不再转圈。

### 1.4 环境自检

在 WSL 里一次跑完：

```bash
java -version
sbt --script-version
ls ~/spinalhdl-projects 2>/dev/null
```

三条都要有输出。`~/spinalhdl-projects` 现在还不存在是正常的，第 2 章会创建它。

---

## 第 2 章 AXI4 总线：从 Scala 到 Vivado 仿真

本章按「建总线工程 → 生成总线 RTL → 建激励工程 → 生成模型 → 回 Windows 仿真」五步走，
每一步都是一个独立脚本，可以随时单独重跑。

### 2.1 先认识被测对象

打开 `AXIcrossbar/Axicrossbar.scala`，核心只有三块：

```scala
val inConfig  = Axi4Config(addressWidth=32, dataWidth=32, idWidth=4, useRegion=false, useQos=false)
val outConfig = inConfig.copy(idWidth = inConfig.idWidth + 1)   // 2 主 → 输出侧 ID 多 1 位

val io = new Bundle {
  val axiIn  = Vec(slave(Axi4(inConfig)),  size = 2)   // 2 个主设备端口
  val axiOut = Vec(master(Axi4(outConfig)), size = 8)  // 8 个从设备端口
  axiIn.foreach(Axi4SpecRenamer(_))
  axiOut.foreach(Axi4SpecRenamer(_))
}
noIoPrefix()
```

地址映射（`addSlaves`）：

| 从端口 | 基地址 | 大小 | 用途 |
|---|---|---|---|
| `axiOut(0)` | `0x1C00_0000` | 8 MiB | sram |
| `axiOut(1)` | `0x0000_0000` | 8 MiB | reserved |
| `axiOut(2)` | `0x1F00_0000` | 1 MiB | apb |
| `axiOut(3)` | `0x1F10_0000` | 1 MiB | dvi |
| `axiOut(4)` | `0x1F20_0000` | 1 MiB | confreg |
| `axiOut(5)` | `0x1F30_0000` | 1 MiB | dma |
| `axiOut(6)` | `0x1F40_0000` | 1 MiB | fft |
| `axiOut(7)` | `0x1F50_0000` | 1 MiB | reserved |

连接关系（`addConnections`）：主设备 0 可访问全部 8 个从设备，主设备 1 只能访问 `axiOut(0) / (1) / (6) / (7)`。
这是一个**部分互连**，正好用来观察「访问未连接从设备会怎样」。

> **ID 为什么加宽 1 位**：2 个主设备共用一个输出端口，互连必须把「主设备序号」拼到 ID 高位
> （`log2Up(2) = 1` 位），响应回来时靠这一位路由回原主设备。主设备数量改成 4 就是加宽 2 位。

### 2.2 步骤 1：建总线 sbt 工程（脚本 `10`）

```bash
cd /mnt/d/SpinalHDL/spinalhdl-setup-kit
bash scripts/axi/10-create-bus-project.sh
```

预期输出：

```
==> 1/3 建工程骨架：/home/<你>/spinalhdl-projects/AXIcrossbar
==> 2/3 同步总线源码
    [OK] 已同步 Axicrossbar.scala
    [OK] 已同步 fifo.scala
    [OK] 已同步 Config.scala
==> 3/3 自检
    [OK] build.sbt 关键行就位
    [OK] 源码齐了：Axicrossbar.scala fifo.scala Config.scala

    工程位置（WSL 内部，编译比 /mnt 快很多）：
      /home/<你>/spinalhdl-projects/AXIcrossbar
    下一步：bash scripts/axi/11-make-bus-verilog.sh
```

它建出的工程长这样：

```
~/spinalhdl-projects/AXIcrossbar/
├── build.sbt                  ← 关键一行：Compile / scalaSource := ... / "hw" / "spinal"
├── project/build.properties   ← sbt 版本
├── project/plugins.sbt        ← 默认空，需要用 Metals 时放开注释
├── .vscode/{settings,tasks}.json
├── hw/spinal/test/            ← Scala 源码（package test）
└── hw/gen/                    ← Verilog 输出
```

`build.sbt` 里最关键的是这一行：

```scala
Compile / scalaSource := baseDirectory.value / "hw" / "spinal",   // 【关键一行】
```

本工程源码放在 `hw/spinal` 下，不是 sbt 默认的 `src/main/scala`。少了这一行：
VS Code 报 `no build target for .../*.scala`，终端 `sbt runMain` 报找不到主类。

> **为什么 AXI 和 APB 必须是两个工程**：两边源码目录里都有 `package test` 和 `object Config`，
> 塞进同一个 sbt 工程会直接「重复定义」编译失败。

### 2.3 步骤 2：生成总线 Verilog（脚本 `11`）

```bash
bash scripts/axi/11-make-bus-verilog.sh
```

这一步只做一件事：在总线工程里跑

```bash
sbt "runMain test.gen2x8" "runMain test.genCDC"
```

然后把 `hw/gen/` 里的产物回传到仓库：

```
    [OK] 回传 AxiCrossbar_2x8.v  (432784 字节)
    [OK] 回传 Axi_CDC.v          (72045 字节)
    仓库位置：/mnt/d/SpinalHDL/AXIcrossbar/verilog
```

> **这两个 .v 就是「可独立使用的 AXI 总线」**：不含 testbench、不含激励模型，
> 可以直接加进任何工程综合。文件大是因为 SpinalHDL 把每个端口的 payload 都展开成了扁平信号，
> 没有用 `interface` / `struct`（Vivado 对这两者支持不一致）。

**如果 sbt 报 `import javax.swing` 相关的编译错误**：那是 IDE 误自动导入。
`11` 脚本会自己检测、注释掉那一行、重试，不用手工处理。

### 2.4 步骤 3：建激励 sbt 工程（脚本 `12`）

```bash
bash scripts/axi/12-create-sim-project.sh
```

```
==> 1/3 建工程骨架：/home/<你>/spinalhdl-projects/AXIcrossbar-sim
==> 2/3 同步模型源码
    [OK] 已同步 AxiModels.scala
==> 3/3 自检
    [OK] 模型源码：sim/AxiModels.scala
    这个工程刻意【不包含】互连源码：模型和 DUT 只在 Verilog 层通过端口相连，
    所以换一个互连实现，模型照样能用。

    下一步：bash scripts/axi/13-make-model-verilog.sh
```

`AXIcrossbar/sim/AxiModels.scala` 里只有两个组件，都不 `import` 互连：

| 组件 | 作用 | 端口 |
|---|---|---|
| `AxiMasterModel` | 发 burst → 读回 → 逐拍自检 | `io_axi_*`（AXI4 主端）+ 4 个激励输入 + 3 个状态输出 |
| `AxiSlaveModel` | 一块真内存 + 标准 AXI4 从端握手 | `io_axi_*`（AXI4 从端） |

模型的参数分两类，**别混**：

```scala
// 编译期（写在构造参数里，改完要重新生成 Verilog）
config   // 位宽（地址 / 数据 / ID）
rounds   // 每个主设备做几轮
beats    // 每个 burst 几拍

// 运行期（做成了输入端口，Verilog 里给常量，不用重生成）
base     // 起始字节地址
stride   // 每轮地址跨度
seed     // 数据种子
id       // AXI ID
```

当前取值（`object AxiModelCfg`）：`rounds = 8`、`beats = 4`、`wordCount = 65536`（每从设备 256 KiB 内存）、
`idWidthIn = 4` / `idWidthOut = 5`。

> **这两个配置必须和 `Axicrossbar.scala` 里的一致**，否则实例化时端口位宽对不上：
> 主设备模型用 `inConfig`（ID 4 位），从设备模型用 `outConfig`（ID 5 位）。

### 2.5 步骤 4：生成主 / 从模型 Verilog（脚本 `13`）

```bash
bash scripts/axi/13-make-model-verilog.sh
```

内部执行 `sbt "runMain test.genAxiModels"`，回传：

```
    [OK] 回传 AxiMasterModel.v  (13823 字节)
    [OK] 回传 AxiSlaveModel.v   (5258 字节)
    仓库位置：/mnt/d/SpinalHDL/AXIcrossbar/verification/models
    下一步（Windows 侧）：运行 windows/axi/14-run-sim.cmd 做 Vivado 仿真
```

到这一步，WSL 侧的工作全部结束。**仿真顶层 `tb_axi_top.v` 不是生成的，它一直就在仓库里**，
原因见下一节。

### 2.6 步骤 5：回 Windows，用 Tcl 跑 Vivado 仿真（脚本 `14`）

#### 2.6.1 为什么仿真顶层要手写

SpinalHDL 的 `SimConfig` 路线是「Scala 里写激励 → 调 Verilator 编译」，而 Verilator 在 WSL 里
既不好装（apt 的 5.x 与 1.10.1 不兼容），也没法和 Vivado 共用波形。
所以本实验把分工切成：

* **能生成的用 Scala 生成**（总线、主模型、从模型）—— 可复用、易改参数；
* **纯连线的用手写**（`tb_axi_top.v`）—— 只有连线、时钟复位、判定，不实现任何协议。

`tb_axi_top.v` 里只有四类内容：

```verilog
// 1. 时钟复位：10 ns 周期 = 100 MHz，低有效复位（与 Config.scala 对应）
reg clk = 0;  always #5 clk = ~clk;
reg reset_n = 0;
initial begin reset_n = 0; repeat (20) @(posedge clk); reset_n = 1; end

// 2. 实例化：DUT + 2 个主模型 + 8 个从模型
AxiCrossbar_2x8  u_dut (...);
AxiMasterModel   u_m0  (...), u_m1 (...);
AxiSlaveModel    u_s0  (...);   // u_s0 ~ u_s7

// 3. 连线：m0_* / m1_* ←→ u_dut.axiIn_0 / axiIn_1
//          u_dut.axiOut_0 ~ _7 ←→ u_s0 ~ u_s7
//    （由 Python 生成器产出，1323 行全是 wire 声明与端口对接）

// 4. 判定：两个主设备都 done 且都没 error → PASS
localparam TIMEOUT = 200000;
always @(posedge clk) begin
  if (reset_n && !reported) begin
    cyc <= cyc + 1;
    if (m0_error | m1_error)          $display("==== FAIL ==== data mismatch ...");
    else if (m0_done & m1_done)       $display("==== PASS ==== 2 masters x 8 rounds x 4 beats, all read back identical (%0d cycles)", cyc);
    else if (cyc > TIMEOUT)           $display("==== FAIL ==== timeout ...");
  end
end
```

两个主设备的激励参数（想改激励就改这四行 ×2）：

| 主设备 | `io_base` | `io_stride` | `io_seed` | `io_id` |
|---|---|---|---|---|
| `u_m0` | `32'h1C00_0000`（sram 窗口） | `32'h0000_1000` | `32'h1100_0000` | `4'd3` |
| `u_m1` | `32'h1C01_0000`（同一 sram 窗口，错开 64 KiB） | `32'h0000_1000` | `32'h2200_0000` | `4'd7` |

两个主设备打同一块 sram、地址段错开，这样既能各自读写成功，又能观察互连的仲裁与 ID 路由。

> **`stride` 必须 ≥ `beats × 4`**（这里是 `4 × 4 = 16`，取 `0x1000` 更宽裕）。
> 改小了相邻两轮地址会重叠，后一轮覆盖前一轮 —— 读回全错但握手完全正常，
> 这是最容易误判成「互连坏了」的坑。

#### 2.6.2 运行

在 **cmd**（不是 PowerShell，也不是 Git Bash）里：

```bat
cd /d D:\SpinalHDL\spinalhdl-setup-kit
windows\axi\14-run-sim.cmd
```

> ⚠️ **不要用 Git Bash 跑 `.cmd`。** MSYS 会把 `cmd.exe /c` 的 `/c` 改写成 `C:\`，
> 而且 Git Bash 传回的退出码恒为 127，判定会完全失效。

想看波形就加 `gui`：

```bat
windows\axi\14-run-sim.cmd gui
```

| 模式 | 行为 | 什么时候用 |
|---|---|---|
| `batch`（默认） | 跑完自动退出，波形存成 `.wdb` + `.wcfg` | 批量回归、交作业 |
| `gui` | 跑完停在 Vivado 波形窗口 | 看时序、定位问题 |

#### 2.6.3 Tcl 里做了什么（五步）

`14-run-sim.cmd` 只负责**找 vivado.bat 并转发模式**，真正的逻辑全在 `14-run-sim.tcl`：

| 步骤 | Tcl 动作 | 关键点 |
|---|---|---|
| 1 检查源文件 | 逐个 `file exists` | 5 个 `.v` 缺一个就 `die`，并提示回 WSL 跑 11 / 13 |
| 2 建工程 | 删旧目录 → `create_project -force sim_axi` | 工程在 `vivado-sim/axi/proj`，只做仿真不综合 |
| 3 加源文件 | `add_files -norecurse` + 设 top | **`sources_1` 和 `sim_1` 都要设 top** |
| 4 仿真设置 | `xsim.simulate.runtime=all`、`xsim.simulate.custom_tcl=14-wave.tcl` | batch 下没有波形窗口，波形脚本必须交给 xsim 自己执行 |
| 5 跑 + 判定 | `launch_simulation` → `run all` → 读 `simulate.log` | 不看退出码，只看 PASS/FAIL 标记 |

三个 Vivado 坑，写在这里省你几个小时：

```tcl
# 坑 1：launch_simulation 看的是 sim_1 这个 fileset 的 top。
# 只设 sources_1 会报 Common 17-70 Top module not set for fileset 'sim_1'
set_property top tb_axi_top [get_filesets sources_1]
set_property top tb_axi_top [get_filesets sim_1]      ;# ← 必须补这一行

# 坑 2：2025.2 里 launch_simulation 的 -mode 指 behavioral / post-synth / post-impl，
# 不是 gui / batch。带 -mode batch 会报 Invalid simulation mode。
# 界面由外层 vivado -mode 决定，这里一律不带参数。
launch_simulation
run all

# 坑 3：batch 模式下没有波形窗口，直接 add_wave 会报 Wavedata 42-443。
# 正确做法是把波形脚本登记成 xsim 的启动脚本：
set_property -name {xsim.simulate.custom_tcl} -value $waveTcl -objects [get_filesets sim_1]
```

判定为什么不看退出码：`$finish` 之后 xsim 会返回 `0xC0000409`（-1073740791），
`vivado.bat` 在有些 shell 里还恒返回 127。所以 Tcl 只做一件事 ——
在 `simulate.log` 里找 `==== PASS` / `==== FAIL`，然后把结论落盘成
`vivado-sim/axi/verdict.txt`（内容就一个词：`PASS` / `FAIL` / `NO-VERDICT`）。

#### 2.6.4 怎么读 console 输出

正常应该是这样：

```
============================================================
  AXI4 crossbar - Vivado simulation
  mode : batch
  part : xc7a100tcsg324-1
============================================================
==> 1/5 check source files
    ok  AxiCrossbar_2x8.v
    ok  Axi_CDC.v
    ok  AxiMasterModel.v
    ok  AxiSlaveModel.v
    ok  tb_axi_top.v
==> 2/5 create project
==> 3/5 add sources
==> 4/5 configure simulation
    runtime : all
    waves   : 14-wave.tcl
==> 5/5 launch and run
[wave] total 302 signals
[wave] saved ...\vivado-sim\axi\tb_axi_top.wcfg

============================================================
  RESULT
------------------------------------------------------------
  verdict : PASS
  detail  : ==== PASS ==== 2 masters x 8 rounds x 4 beats, all read back identical (218 cycles)
  log     : ...\vivado-sim\axi\proj\sim_axi.sim\sim_1\behav\xsim\simulate.log
  wave    : ...\vivado-sim\axi\proj\sim_axi.sim\sim_1\behav\xsim\tb_axi_top.wdb
  wcfg    : ...\vivado-sim\axi\tb_axi_top.wcfg
------------------------------------------------------------
  PASS - 2 masters x 8 rounds x 4 beats read back identical.
```

三种结论分别对应三种状况：

| `verdict` | 含义 | 下一步 |
|---|---|---|
| `PASS` | 218 拍内两个主设备各 8 轮 × 4 拍全部读回一致 | 打开波形核对路由 |
| `FAIL` | 数据不一致或超时，`detail` 那行会写清哪个主设备、哪轮哪拍 | 看下面 2.6.6 |
| `NO-VERDICT` | 日志里连标记都没有，仿真没跑完 | 多半是握手卡死或 elaborate 报错，往上翻日志 |

#### 2.6.5 波形怎么用

`14-wave.tcl` 在 xsim 进程里执行，按 8 组挂波形（共 **302** 个信号），并
`save_wave_config` 到 `vivado-sim/axi/tb_axi_top.wcfg`：

| 分组 | 信号数 | 看什么 |
|---|---|---|
| `00_clock_and_result` | 6 | `clk / reset_n / m0_done / m0_error / m1_done / m1_error` —— **先看这一组** |
| `01_master0_bus` | 35 | 主设备 0 的 5 个通道（`aw/w/b/ar/r`）全部信号 |
| `02_master1_bus` | 35 | 主设备 1 同上 |
| `03_crossbar_in0` | 35 | 互连输入端口 0（扁平名 `axiIn_0_*`） |
| `04_crossbar_in1` | 35 | 互连输入端口 1 |
| `05_crossbar_out` | 72 | 8 个输出端口各取 9 根关键信号（`awvalid awaddr wvalid wlast bvalid arvalid araddr rvalid rlast`） |
| `06_slave0_bus` | 35 | 从设备 0 端口（`io_axi_*`）全套握手 |
| `07_slaves_1_to_7` | 49 | 其余 7 个从设备各 7 根摘要（抓全 35 根波形窗口会很卡） |

打开已有波形（不重跑仿真）：

```bat
cd /d D:\SpinalHDL\spinalhdl-setup-kit\vivado-sim\axi\proj
C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat sim_axi.xpr
```

Vivado 里 `Flow → Open Static Simulation`，或直接在 Tcl Console 里：

```tcl
open_wave_database {../sim_axi.sim/sim_1/behav/xsim/tb_axi_top.wdb}
open_wave_config  {../../tb_axi_top.wcfg}
```

**看波形的顺序（照这个顺序看，90% 的问题三步内能定位）：**

1. `00_clock_and_result`：`m0_error` / `m1_error` 有没有变高？变了就是数据错，跳到第 3 步。
2. `01_master0_bus` / `02_master1_bus`：`awvalid & awready`、`wvalid & wready`、`bvalid & bready`
   有没有出现「一直高但对方 ready 恒 0」—— 那就是死锁，看对应的 `03/04` 互连输入端口。
3. `05_crossbar_out`：地址落在哪个窗口，`axiOut_x_awvalid` 就应该只有那一根起来。
   如果同时起来两根，说明地址映射改错了；如果一根都不起，说明 `addConnections` 里没连这个从设备。

#### 2.6.6 常见故障与处理

| 现象 | 原因 | 处理 |
|---|---|---|
| `missing: ...\AxiCrossbar_2x8.v` | 没跑 11 号脚本 | 回 WSL 跑 `bash scripts/axi/11-make-bus-verilog.sh` |
| `missing: ...\AxiMasterModel.v` | 没跑 13 号脚本 | 回 WSL 跑 `bash scripts/axi/13-make-model-verilog.sh` |
| `[VRFC 10-3180] cannot find port 'io_axi_rlast'` | 端口名写错（模型是 `io_axi_r_last`） | 见 `tb_axi_top.v` 里的实际端口名，别按互连的扁平风格猜 |
| `Common 17-70 Top module not set for fileset 'sim_1'` | 只设了 `sources_1` 的 top | 已在 Tcl 里修，若自己写脚本记得补 |
| `Invalid simulation mode` | `launch_simulation -mode batch` | 去掉 `-mode`，界面由外层 `vivado -mode` 决定 |
| `Wavedata 42-443` | batch 下调 `add_wave` | 用 `xsim.simulate.custom_tcl` |
| `cannot remove old project` | 上一个 Vivado 还开着 | 先关掉 Vivado 再跑 |
| `valid license was not found` | 启动器挑了没 license 的版本 | `set VIVADO_BIN=<有 license 的>\Vivado\bin\vivado.bat` |
| `verdict : FAIL`，detail 是 `data mismatch` | 地址重叠 / ID 没回显 / 位宽不对 | 先查 `stride`，再查从模型 `b.id` 是否回显 `awid` |
| `verdict : NO-VERDICT` | 仿真没跑完（死锁或 elaborate 失败） | 往上翻 `simulate.log` 找 `ERROR` |

### 2.7 本章自检清单

- [ ] `~/spinalhdl-projects/AXIcrossbar/hw/gen/` 里有 `AxiCrossbar_2x8.v`、`Axi_CDC.v`
- [ ] `AXIcrossbar/verilog/` 里这两个文件大小是 432784 / 72045 字节左右
- [ ] `AXIcrossbar/verification/models/` 里有 `AxiMasterModel.v`、`AxiSlaveModel.v`
- [ ] `windows\axi\14-run-sim.cmd` 打印 `verdict : PASS` 与 `218 cycles`
- [ ] `vivado-sim/axi/verdict.txt` 内容是 `PASS`
- [ ] `vivado-sim/axi/tb_axi_top.wcfg` 存在，8 个分组共 302 个信号

---

## 第 3 章 APB3 总线：同样的五步

结构与第 2 章完全对应，只是号段从 `1x` 换成 `2x`。已熟悉 AXI 的可只看 3.1 与 3.6。

### 3.1 认识被测对象

`apb/Apbcrossbar.scala` 里有三块：

**① 轮询仲裁器** `ApbRoundRobinArbiter`

用「优先级掩码」实现轮转：`mask` 中为 1 的位表示本轮还有资格竞争；
每次授权后把「被授权位及其低位」清零，下一次自然从下一位开始。

```scala
val maskedReq = reqBits & mask
val pick = OHMasking.first(Mux(maskedReq.orR, maskedReq, reqBits))
// pick 位及其低位清零、高位保留
var taken: Bool = False
for (i <- 0 until portCount) { nextMask(i) := taken; taken = taken || pick(i) }
when(pick.orR) { mask := nextMask }
```

写成 `object + apply`（而不是 `Area`），是为了避免在 `Area` 里用 `in / out` 标记方向 ——
那会被 SpinalHDL 当成「需要从组件外部驱动」，触发 HIERARCHY VIOLATION。

**② 互连工厂** `Apb3CrossbarFactory`，用法和 `Axi4CrossbarFactory` 一致：

```scala
val apbCrossBar = Apb3CrossbarFactory()
apbCrossBar.addSlaves((io.apbOut(0), SizeMapping(0x00000000L, 4 KiB)), ...)
apbCrossBar.addConnections(io.apbIn(0) -> List(io.apbOut(0), ...), ...)
apbCrossBar.build()
```

`build()` 里有 4 个 `require`，改结构时会在这里报错，比在波形里找问题快得多：

```scala
require(masterCount >= 2, "至少需要 2 个主设备")
require(slaveCount  >= 1, "至少需要 1 个从设备")
require(!SizeMapping.verifyOverlapping(mappings), "从设备地址窗口之间存在重叠")
mappings.foreach { m => require(m.isAligned, "窗口大小必须是 2 的幂，且基地址按它对齐") }
```

内部结构是：**M 个主端口 → 轮询仲裁 → 一条内部 APB → 地址译码 → N 个从端口**。
有一处值得单独说：`build()` 里做了**相位重定时**。

```scala
// 主设备一进 ACCESS 阶段 PENABLE 就一直为高（APB 规范如此）。
// 直接透传的话，那些一直在 ACCESS 里等待、刚拿到总线的主设备，
// 会让从设备看到 PSEL 与 PENABLE 同拍变高，缺了规范的 SETUP 相位。
val selectedD = Reg(Bits(slaveCount bits)) init B(0, slaveCount bits)
selectedD := selected
apb.PSEL(0) := selected(s)
apb.PENABLE := selected(s) && selectedD(s) && busEnable     // ← 必须晚一拍
```

**③ 被测实例** `Apb3Crossbar_2x8`，地址映射每窗口 4 KiB：

| 从端口 | 基地址 | 用途 | 从端口 | 基地址 | 用途 |
|---|---|---|---|---|---|
| `apbOut(0)` | `0x0000_0000` | sram | `apbOut(4)` | `0x0000_4000` | gpio |
| `apbOut(1)` | `0x0000_1000` | uart | `apbOut(5)` | `0x0000_5000` | timer |
| `apbOut(2)` | `0x0000_2000` | spi | `apbOut(6)` | `0x0000_6000` | dma |
| `apbOut(3)` | `0x0000_3000` | i2c | `apbOut(7)` | `0x0000_7000` | confreg |

两个主设备都能访问全部 8 个从设备（与 AXI 的「部分互连」不同，这里刻意做成全互连）。

### 3.2 步骤 1：建总线 sbt 工程（脚本 `20`）

```bash
bash scripts/apb/20-create-bus-project.sh
```

工程在 `~/spinalhdl-projects/apb`。源码只有 `Apbcrossbar.scala` 与 `Config.scala`
（`Config.scala` 两个总线各一份，内容相同但必须各自工程一份）。

### 3.3 步骤 2：生成总线 Verilog（脚本 `21`）

```bash
bash scripts/apb/21-make-bus-verilog.sh
```

内部 `sbt "runMain test.genApb2x8"`，回传：

```
    [OK] 回传 Apb3Crossbar_2x8.v  (13989 字节)
```

只有 13 KB，因为 APB3 一共就 8 根信号，互连里也只有一个仲裁器加一段译码。

### 3.4 步骤 3：建激励 sbt 工程（脚本 `22`）

```bash
bash scripts/apb/22-create-sim-project.sh
```

同步 `apb/sim/ApbModels.scala`。模型配置：

```scala
object ApbModelCfg {
  val config = Apb3Config(addressWidth=32, dataWidth=32, selWidth=1, useSlaveError=true)
  val rounds = 4        // 每个主设备几轮
  val words  = 8        // 每轮几个字
  val wordCount = 256   // 每个从设备模型的内存深度（字）
}
```

与 AXI 版一样，`base / stride / seed` 做成了**输入端口**，换地址段不用重生成 Verilog。

### 3.5 步骤 4：生成模型 Verilog（脚本 `23`）

```bash
bash scripts/apb/23-make-model-verilog.sh
```

```
    [OK] 回传 ApbMasterModel.v  (7618 字节)
    [OK] 回传 ApbSlaveModel.v   (51542 字节)
```

从设备模型 51 KB 是正常的 —— 它是 256 个 32 位寄存器的寄存器堆（`RegFile`），
每个寄存器都带写使能逻辑，展开后代码量就上来了。

### 3.6 步骤 5：回 Windows 跑 Vivado 仿真（脚本 `24`）

```bat
cd /d D:\SpinalHDL\spinalhdl-setup-kit
windows\apb\24-run-sim.cmd          :: batch，判 PASS/FAIL
windows\apb\24-run-sim.cmd gui      :: 停在波形窗口
```

预期输出：

```
  verdict : PASS
  detail  : ==== PASS ==== 2 masters x 4 rounds x 8 words, all read back identical (69 cycles)
```

波形 8 组共 **159** 个信号（APB 只有 8 根信号，所以每组的数量是 AXI 的零头）：

| 分组 | 信号数 |
|---|---|
| `00_clock_and_result` | 6 |
| `01_master0_apb` / `02_master1_apb` | 8 / 8 |
| `03_crossbar_in0` / `04_crossbar_in1` | 8 / 8 |
| `05_crossbar_out` | 64 |
| `06_slave0_apb` | 8 |
| `07_slaves_1_to_7` | 49 |

APB 的激励参数：

| 主设备 | `io_base` | `io_stride` | `io_seed` | 打哪个窗口 |
|---|---|---|---|---|
| `u_m0` | `0x0000_0000` | `0x20` | `0x1234_0000` | `apbOut(0)` sram |
| `u_m1` | `0x0000_4000` | `0x20` | `0x1244_0000` | `apbOut(4)` gpio |

`0x20 = 8 字 × 4 字节`，四轮正好占满 `0x00~0x7F`。

> **APB 最隐蔽的坑**：`io_stride` 改小成 `0x10` 时，相邻两轮地址重叠，
> 读回的数据被后一轮覆盖，但 `PSEL/PENABLE/PREADY` 握手**完全正常** ——
> 波形上看不出任何异常，只有 `verdict` 变 `FAIL`。所以先把 `stride ≥ words × 4` 当铁律记住。

**APB 波形看什么**（和 AXI 的 5 通道不同，只有 8 根信号）：

1. `PSEL` 与 `PENABLE` 必须是**先 PSEL 后 PENABLE，至少隔一拍** —— 这就是 SETUP 相位。
   两者同拍起来说明相位重定时被改坏了。
2. `PREADY` 在 `PENABLE` 为高的那一拍才可能为高；`PREADY=0` 时主设备必须原地等待。
3. `PSLVERROR`：访问未映射地址时应为 1（`build()` 里 `finalError = Mux(anySelected, respError, True)`）。
4. 两个主设备同时 `PSEL` 时，`03/04` 里被授权那个的 `PENABLE` 才会推进，另一个一直等 —— 这就是轮询仲裁。

### 3.7 本章自检清单

- [ ] `apb/verilog/Apb3Crossbar_2x8.v` 存在（约 13989 字节）
- [ ] `apb/verification/models/` 里有 `ApbMasterModel.v`、`ApbSlaveModel.v`
- [ ] `windows\apb\24-run-sim.cmd` 打印 `verdict : PASS` 与 `69 cycles`
- [ ] `vivado-sim/apb/verdict.txt` 内容是 `PASS`
- [ ] 波形里 `PSEL` 比 `PENABLE` 早一拍

---

## 第 4 章 修改总线结构并完成仿真校验

本章是实验的重点：结构一改，哪些文件要跟着改、怎么确认改对了。

### 4.1 改一处会牵动哪些文件

先记住这张表，改之前对一遍，能省掉大部分「改了没生效」「位宽对不上」的返工。

| 你想改的东西 | 必改 | 可能要改 | 必须重新生成 |
|---|---|---|---|
| 地址映射 | `Axicrossbar.scala` / `Apbcrossbar.scala` 的 `addSlaves` | `tb_*_top.v` 里的 `io_base` | 总线 RTL（`11` / `21`） |
| 主设备数量 | `io.axiIn` 的 `size`、`addConnections` 的行数 | 模型的 `idWidth`、TB 里的模型实例 | 总线 RTL + **模型**（`11` 与 `13`） |
| 从设备数量 | `io.axiOut` 的 `size`、`addSlaves` 条目 | TB 里的从模型实例数、波形分组 | 总线 RTL |
| 数据位宽 | `inConfig.dataWidth` | 模型的 `dataWidth`、TB 的 wire 位宽、`stride` | 总线 RTL + 模型 |
| 主从连接关系 | `addConnections` | 无 | 总线 RTL |
| 只改激励（地址 / 种子 / ID） | `tb_*_top.v` 的常量 | 无 | **不用重新生成** |
| 激励轮数 / 每轮拍数 | `sim/*Models.scala` 的 `rounds` / `beats` | `stride` 要够大 | 模型（`13` / `23`） |

### 4.2 场景 A：改地址映射（最常做）

**例：把 `axiOut(4)` 从 confreg 的 `0x1F20_0000` 改到 `0x2F20_0000`。**

改 `AXIcrossbar/Axicrossbar.scala`：

```scala
axiCrossBar.addSlaves (
  (io.axiOut(0), SizeMapping(0x1c000000L, 8 MiB)),//sram
  ...
  (io.axiOut(4), SizeMapping(0x2f200000L, 1 MiB)),//confreg  ← 只改这一行
  ...
)
```

然后：

```bash
bash scripts/axi/11-make-bus-verilog.sh      # 重新生成 RTL
windows\axi\14-run-sim.cmd                   # 重跑仿真
```

**校验要点**：仿真仍然应该 `PASS`，因为 TB 打的是 `0x1C00_0000`（sram 窗口），
没被这次改动影响。想真正验证新映射，就把 TB 的 `io_base` 改成 `0x2F20_0000`：

```verilog
AxiMasterModel u_m0 (
  .io_base   (32'h2F20_0000),   // 改成新窗口
  ...
);
```

预期：`PASS`；如果漏改 `addSlaves` 只改了 TB，会 `FAIL`（`PSLVERROR` 或读回全 `X`）。

**几个改映射时的硬约束**（不满足会在 `build()` 的 `require` 里直接报错）：

1. 窗口**不许重叠**；
2. 窗口大小必须是 **2 的幂**，基地址必须**按它对齐**（1 MiB 的窗口基地址低 20 位必须是 0）；
3. `SizeMapping(base, size)` 里的 `size` 用 `KiB / MiB / GiB`（SpinalHDL 的 `Int` 扩展），不要写成 `1024`。

### 4.3 场景 B：改主设备数量（2 → 4）

这一步牵动最多，按顺序改四处：

**① `Axicrossbar.scala`**

```scala
val io = new Bundle {
  val axiIn  = Vec(slave(Axi4(inConfig)),  size = 4)   // ← 2 改 4
  val axiOut = Vec(master(Axi4(outConfig)), size = 8)
}
```

`outConfig` 不用动 —— `idWidth = inConfig.idWidth + 1` 这一行在 4 主时**仍要改成 `+ 2`**：

```scala
val outConfig = inConfig.copy(idWidth = inConfig.idWidth + 2)   // log2Up(4) = 2
```

更稳妥的写法是让它自己算：

```scala
import spinal.core.log2Up
val outConfig = inConfig.copy(idWidth = inConfig.idWidth + log2Up(4))
```

**② `addConnections` 补两行**

```scala
axiCrossBar.addConnections(
  io.axiIn(0) -> List(io.axiOut(0), io.axiOut(1), io.axiOut(2), io.axiOut(3),
                      io.axiOut(4), io.axiOut(5), io.axiOut(6), io.axiOut(7)),
  io.axiIn(1) -> List(io.axiOut(0), io.axiOut(1), io.axiOut(6), io.axiOut(7)),
  io.axiIn(2) -> List(io.axiOut(0), io.axiOut(2), io.axiOut(4)),   // ← 新增
  io.axiIn(3) -> List(io.axiOut(1), io.axiOut(3), io.axiOut(5))    // ← 新增
)
```

**③ `sim/AxiModels.scala` 的位宽**

```scala
object AxiModelCfg {
  val idWidthIn  = 4
  val idWidthOut = idWidthIn + 2      // ← 跟着总线一起改
}
```

**④ `verification/tb_axi_top.v` 加两个主模型**

复制 `u_m0` / `u_m1` 那段（含 35 个 wire 声明 + 实例化），改成 `u_m2` / `u_m3`，
接到 `u_dut.axiIn_2` / `axiIn_3`，并给不同的 `io_base`：

```verilog
AxiMasterModel u_m2 (
  .clk       (clk),
  .resetn    (reset_n),
  .io_base   (32'h1C02_0000),
  .io_stride (32'h0000_1000),
  .io_seed   (32'h3300_0000),
  .io_id     (4'd5),
  ...
);
```

判定逻辑也要跟着改（原来是 `m0_done & m1_done`）：

```verilog
else if (m0_done & m1_done & m2_done & m3_done)
  $display("==== PASS ==== 4 masters x 8 rounds x 4 beats ... (%0d cycles)", cyc);
```

**重新生成的顺序不能错**：

```bash
bash scripts/axi/11-make-bus-verilog.sh      # 先总线（ID 位宽变了）
bash scripts/axi/13-make-model-verilog.sh    # 再模型（outConfig 跟着变）
```

反过来做的话，`13` 生成的模型还是旧位宽，到 Vivado 里会报端口位宽不匹配。

**最后一个坑**：`outConfig` 的 `idWidth` 一旦变了，TB 里接从设备的那一端
（`u_s0..u_s7` 的 `io_axi_aw_payload_id`、`io_axi_b_payload_id` 等）位宽也跟着变。
动手前建议先跑一遍 `14`，让 Vivado 把端口位宽不匹配的行号直接告诉你。

### 4.4 场景 C：改从设备数量（8 → 4）

比改主设备简单，只动两处：

```scala
val axiOut = Vec(master(Axi4(outConfig)), size = 4)   // ← 8 改 4

axiCrossBar.addSlaves (
  (io.axiOut(0), SizeMapping(0x1c000000L, 8 MiB)),
  (io.axiOut(1), SizeMapping(0x00000000L, 8 MiB)),
  (io.axiOut(2), SizeMapping(0x1f000000L, 1 MiB)),
  (io.axiOut(3), SizeMapping(0x1f100000L, 1 MiB))
)
```

`addConnections` 里引用了 `io.axiOut(4..7)` 的地方全部删掉，否则 Scala 编译期就报
`IndexOutOfBounds`。

TB 侧把 `u_s4..u_s7` 四个从模型实例与对应的 wire 删掉，`axiOut_4..7` 的连线换成悬空或直接删。
波形脚本 `14-wave.tcl` 的 `05_crossbar_out` 和 `07_slaves_1_to_7` 也要相应减少
（不改也能跑，只是 `get_objects` 会给 WARNING 说找不到）。

> 从设备数量变化**不影响 ID 位宽**（ID 加宽只看主设备数量），所以模型不用重新生成。

### 4.5 场景 D：改主从连接关系（做部分互连）

只改 `addConnections`，其它都不动：

```scala
// 让主设备 1 完全不能访问 sram
axiCrossBar.addConnections(
  io.axiIn(0) -> List(io.axiOut(0), io.axiOut(1), io.axiOut(2), io.axiOut(3),
                      io.axiOut(4), io.axiOut(5), io.axiOut(6), io.axiOut(7)),
  io.axiIn(1) -> List(io.axiOut(6), io.axiOut(7))
)
```

重新跑 `11` + `14`。**校验方法**：把 TB 里 `u_m1` 的 `io_base` 改成 `0x1C01_0000`（sram 窗口），
预期得到 `FAIL` —— 而且 `detail` 应该指向主设备 1。这一步是**故意让它失败**，
用来确认「未连接从设备的访问确实被互连拒绝」，而不是被悄悄放过去。

APB 侧同理，`allowMask` 是编译期常量，改连接关系后重新生成即可：

```scala
val allowMask = connectedList.map { connected =>
  var bits = BigInt(0)
  for (s <- 0 until slaveCount) if (connected.exists(_ eq slaveList(s))) bits |= (BigInt(1) << s)
  B(bits, slaveCount bits)
}
```

未命中的访问会被 `finalError = Mux(anySelected, respError, True)` 立刻以错误结束，
主设备不会无限等待 —— 这正是 `PSLVERROR` 的验证点。

### 4.6 场景 E：只改激励（不重新生成任何 Verilog）

这是模型参数做成端口的价值所在。改 `tb_axi_top.v` 里的四个常量即可：

```verilog
AxiMasterModel u_m0 (
  .io_base   (32'h1C00_0000),   // 起始地址：必须落在某个从设备窗口内
  .io_stride (32'h0000_1000),   // 每轮跨度：必须 >= beats*4 = 16
  .io_seed   (32'h1100_0000),   // 数据种子：第 r 轮第 b 拍写 seed + r*0x100 + b
  .io_id     (4'd3),            // AXI ID：两个主设备用不同值才看得出路由
  ...
);
```

三个「故意做出对比」的实验，各跑一次 `14`：

| 实验 | 改动 | 预期 |
|---|---|---|
| 地址重叠 | `io_stride` 改 `0x08`（< 16） | `FAIL`，detail 是 data mismatch |
| 两主设备抢同一地址 | `u_m1.io_base` 改 `0x1C00_0000` | 仍 `PASS`（同值同数据，互不破坏），但波形上能看到 B 通道争用 |
| 越界地址 | `u_m0.io_base` 改 `0x3000_0000` | `FAIL`，从设备不回 B/R 或回 error |

### 4.7 场景 F：换一个互连实现，模型复用

这是「四类文件不内联」的直接收益。假设你另写了一个 `MyCrossbar`，只要端口对得上：

```verilog
// tb_axi_top.v 里只改 DUT 这一处，两个模型和 8 个从模型全不用动
// AxiCrossbar_2x8 u_dut (...);
MyCrossbar u_dut (
  .axiIn_0_awvalid (m0_awvalid),
  ...
);
```

前提是端口名与位宽和 `AxiCrossbar_2x8` 一致（`axiIn_0_*` ~ `axiIn_1_*`、`axiOut_0_*` ~ `axiOut_7_*`）。
如果你的新互连用 `noIoPrefix()` 后的名字不同，把 `tb_axi_top.v` 里的端口名替换一下即可 ——
**模型侧一行都不用改**。

### 4.8 仿真校验的三层方法

改完结构不要只看 `PASS` 两个字，按三层确认：

**第 1 层：能 elaborate（编译级）**

```bat
windows\axi\14-run-sim.cmd
```

只要没出现 `ERROR: [VRFC ...]` / `[XSIM 43-...]`，说明端口名、位宽、模块名全对。
这一层挡住的是「低级错误」。

**第 2 层：协议能跑完（握手级）**

`verdict` 不是 `NO-VERDICT`。`NO-VERDICT` 表示仿真没到判定点就停了，
典型症状是某个 `valid` 一直高、对方 `ready` 恒 0 —— 协议死锁。
用 `01/02` 分组定位到具体通道，再看 `03/04` 互连输入端口。

**第 3 层：数据正确（数据级）**

`verdict : PASS` 且 `detail` 里的 cycles 数量级合理：

| 设计 | 参考值 | 说明 |
|---|---|---|
| AXI 2×8，8 轮 × 4 拍 | **218 cycles** | 明显变大（几千）通常是握手里插了多余等待 |
| APB 2×8，4 轮 × 8 字 | **69 cycles** | 每字 SETUP + ACCESS 至少 2 拍 |

cycles 突然翻倍但仍是 `PASS`，说明功能对但性能退化（例如仲裁器一直不轮转、
或者从设备 `PREADY` 多等了一拍）。这时候 `PASS` 不够，得看波形确认。

### 4.9 常见故障速查

| 现象 | 最可能的原因 | 快速验证 |
|---|---|---|
| Scala 编不过：`not found: value io.axiOut` | `addConnections` 里引用了被删掉的从端口 | 检查 `size` 与索引 |
| Scala 编不过：`requirement failed: 窗口重叠` | 两个 `SizeMapping` 地址范围交叠 | 手算 base + size |
| Vivado：`port size mismatch` | 模型 `idWidth` 没跟着总线的 `+log2Up(N)` 改 | 对比 `AxiModelCfg` 与 `Axicrossbar.scala` |
| Vivado：`module not found` | 生成物没回传 | 看 `verilog/` 与 `verification/models/` 是否有新 mtime |
| `verdict : FAIL` + data mismatch | `stride` 太小、地址重叠 | 改 `stride ≥ beats*4` |
| `verdict : FAIL`，主设备 1 永远等 B | 从模型 `b.id` 没回显 `awid` | 看波形 `bid` 是否为 0 |
| `verdict : NO-VERDICT` | 死锁或 elaborate 失败 | 翻 `simulate.log` 的 `ERROR` |
| 波形里某分组 0 个信号 | `get_objects` 精确名不匹配 | `14-wave.tcl` 会打 WARNING，按提示补端口名 |
| 波形里某分组信号数暴增 | 路径尾部写了 `*`（跨层次） | 改成显式端口清单 |

> **`get_objects` 的两个坑**（改 `14-wave.tcl` / `24-wave.tcl` 时一定会遇到）：
> ① **精确名必须写全** —— 模型端口是 `io_axi_aw_valid`，互连端口是 `axiIn_0_awvalid`，两者不一样；
> ② **路径尾部 `*` 会跨层次** —— `axiIn_0_*` 会抓到 281 个而不是 35 个。
> 所以两个 `wave.tcl` 里全部用显式端口清单，抓不到的路径会打 WARNING 而不是静默跳过。

---

## 附录 A 脚本速查

```bash
# ===== 第 1 章：环境（WSL）=====
bash scripts/env/01-install-toolchain.sh          # JDK17 + sbt + 国内镜像
bash scripts/env/02-vscode-extensions.sh          # VS Code 的 Scala/Metals 扩展

# ===== 第 2 章：AXI（WSL）=====
bash scripts/axi/10-create-bus-project.sh         # 建总线工程
bash scripts/axi/11-make-bus-verilog.sh           # 生成总线 RTL
bash scripts/axi/12-create-sim-project.sh         # 建激励工程
bash scripts/axi/13-make-model-verilog.sh         # 生成主/从模型

# ===== 第 3 章：APB（WSL）=====
bash scripts/apb/20-create-bus-project.sh
bash scripts/apb/21-make-bus-verilog.sh
bash scripts/apb/22-create-sim-project.sh
bash scripts/apb/23-make-model-verilog.sh
```

```bat
:: ===== 第 4 章：Vivado 仿真（Windows cmd）=====
windows\axi\14-run-sim.cmd                :: batch，判 PASS/FAIL
windows\axi\14-run-sim.cmd gui            :: 停在波形窗口
windows\apb\24-run-sim.cmd
windows\apb\24-run-sim.cmd gui

:: 多版本 Vivado / 无 license 时
set VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat
:: 换器件（默认 xc7a100tcsg324-1）
set VIVADO_PART=xc7z020clg400-1
```

一键跑完两条总线（cmd）：

```bat
cd /d D:\SpinalHDL\spinalhdl-setup-kit
windows\axi\14-run-sim.cmd && windows\apb\24-run-sim.cmd
```

产出位置：

| 内容 | 路径 |
|---|---|
| 总线 RTL | `AXIcrossbar/verilog/`、`apb/verilog/` |
| 模型 | `AXIcrossbar/verification/models/`、`apb/verification/models/` |
| 仿真工程 | `spinalhdl-setup-kit/vivado-sim/<bus>/proj/` |
| 判定结果 | `spinalhdl-setup-kit/vivado-sim/<bus>/verdict.txt` |
| 波形配置 | `spinalhdl-setup-kit/vivado-sim/<bus>/tb_*_top.wcfg` |
| 仿真日志 | `.../proj/sim_<bus>.sim/sim_1/behav/xsim/simulate.log` |

## 附录 B 术语

| 术语 | 含义 |
|---|---|
| Crossbar（交叉开关） | 多主多从互连，任意主设备可按地址访问任意（被允许的）从设备 |
| 部分互连 | `addConnections` 里只列出一部分从端口，不是全连接 |
| SETUP / ACCESS 相位 | APB 两次握手：`PSEL=1,PENABLE=0` 为 SETUP，`PENABLE=1` 为 ACCESS |
| ID 拼接 | 多主共用一个输出端口时，把主设备序号拼到 ID 高位，用于响应路由 |
| 轮询仲裁 | 每次授权后把优先级移到下一个请求者，避免饿死 |
| sticky error | 错误一旦出现就锁存，直到复位（`errorR := errorR || (errCnt =/= 0)`） |
| verdict | 仿真结论文件，只有 `PASS` / `FAIL` / `NO-VERDICT` 三种值 |
| wcfg | Vivado 波形配置文件，记录分组与信号选择 |
