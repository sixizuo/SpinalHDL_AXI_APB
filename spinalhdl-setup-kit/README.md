# SpinalHDL AXI4 / APB3 互连：Verilog 生成与 Vivado 仿真套件

把「用 SpinalHDL 写总线 → 生成 Verilog → 在 Vivado 里仿真验证」这条链路做成**可重复执行的脚本**：
WSL 侧负责生成，Windows 侧负责仿真，每条总线一套独立脚本，互不干扰。

**完整实验步骤见 [`docs/AXI_APB总线互连仿真实验指导.md`](docs/AXI_APB总线互连仿真实验指导.md)**
（分 4 章：环境 / AXI / APB / 改结构与校验）。本文件只是索引与速查。

---

## 1. 这套东西产出什么

四类 Verilog，**永远不内联**，各自独立成文件：

| 类别 | AXI | APB | 可综合 |
|---|---|---|---|
| ① 总线 RTL（可独立交付） | `AxiCrossbar_2x8.v`、`Axi_CDC.v` | `Apb3Crossbar_2x8.v` | 是 |
| ② 主设备行为模型 | `AxiMasterModel.v` | `ApbMasterModel.v` | 是 |
| ③ 从设备行为模型 | `AxiSlaveModel.v` | `ApbSlaveModel.v` | 是 |
| ④ 仿真顶层（手写） | `tb_axi_top.v` | `tb_apb_top.v` | 否 |

拆分带来的直接收益：

* 总线 RTL 不含 testbench 内容，可以单独拿去综合 / 交付；
* 模型不 `import` 互连，只按 AXI4 / APB3 端口说话 —— 换一个互连实现，模型照样能用；
* 每个 `.v` 只有一个模块，波形层次干净，改一个模型不牵动另一个；
* 激励参数（`base / stride / seed / id`）做成**输入端口**，改地址段不必重新生成 Verilog。

## 2. 目录结构

```
<仓库根>/
├── AXIcrossbar/                   AXI 源码与产物
│   ├── Axicrossbar.scala          被测互连（2 主 8 从，ID 4→5 位）
│   ├── fifo.scala                 配套 FIFO
│   ├── Config.scala               Verilog 输出目录 / 时钟复位风格
│   ├── sim/AxiModels.scala        主/从模型（与互连解耦）
│   ├── verilog/                   ① 总线 RTL
│   └── verification/
│       ├── models/                ② ③ 模型
│       └── tb_axi_top.v           ④ 手写仿真顶层
├── apb/                           结构完全相同（Apbcrossbar.scala / sim/ApbModels.scala / …）
└── spinalhdl-setup-kit/
    ├── docs/                      实验指导（Markdown）
    ├── scripts/                   ← WSL 里跑
    │   ├── lib/common.sh          路径推导 + 总线描述表（加第三条总线只改这里）
    │   ├── lib/project_kit.sh     建骨架/同步/调 sbt/回传产物
    │   ├── env/01,02
    │   ├── axi/10,11,12,13
    │   └── apb/20,21,22,23
    ├── windows/                   ← Windows 的 cmd 里跑
    │   ├── env/00-preflight.ps1
    │   ├── axi/14-run-sim.cmd / .tcl / 14-wave.tcl
    │   └── apb/24-run-sim.cmd / .tcl / 24-wave.tcl
    └── vivado-sim/                仿真工程与结果的落地目录（生成物，可删）
```

## 3. 脚本编号

环境脚本独立号段，每条总线独立号段；同号段内后缀含义一致。

| 编号 | 作用 | 在哪跑 |
|---|---|---|
| `env/00-preflight.ps1` | Windows 前置检查（只读，不改系统） | Windows PowerShell |
| `env/01-install-toolchain.sh` | JDK 17 + sbt + 国内镜像 | WSL |
| `env/02-vscode-extensions.sh` | VS Code 的 Scala / Metals 扩展 | WSL |
| `axi/10`、`apb/20` | 建**总线** sbt 工程 | WSL |
| `axi/11`、`apb/21` | 生成**总线 RTL** → `verilog/` | WSL |
| `axi/12`、`apb/22` | 建**激励** sbt 工程 | WSL |
| `axi/13`、`apb/23` | 生成**主/从模型** → `verification/models/` | WSL |
| `axi/14`、`apb/24` | Vivado 建工程 + 挂波形 + 仿真 + 判定 | Windows cmd |

## 4. 三步跑通

```bash
# ① 环境（只做一次）
bash scripts/env/01-install-toolchain.sh
bash scripts/env/02-vscode-extensions.sh

# ② 生成 Verilog（每条总线四步，随时可单独重跑）
bash scripts/axi/10-create-bus-project.sh
bash scripts/axi/11-make-bus-verilog.sh
bash scripts/axi/12-create-sim-project.sh
bash scripts/axi/13-make-model-verilog.sh

bash scripts/apb/20-create-bus-project.sh
bash scripts/apb/21-make-bus-verilog.sh
bash scripts/apb/22-create-sim-project.sh
bash scripts/apb/23-make-model-verilog.sh
```

```bat
:: ③ 回 Windows 的 cmd（不要用 Git Bash）
windows\axi\14-run-sim.cmd
windows\apb\24-run-sim.cmd

:: 想看波形
windows\axi\14-run-sim.cmd gui
```

预期结论：

```
  verdict : PASS
  detail  : ==== PASS ==== 2 masters x 8 rounds x 4 beats, all read back identical (218 cycles)   ← AXI
  detail  : ==== PASS ==== 2 masters x 4 rounds x 8 words,  all read back identical (69 cycles)    ← APB
```

## 5. 结果落在哪

| 内容 | 路径 |
|---|---|
| 判定结果（一个词） | `vivado-sim/<bus>/verdict.txt` — `PASS` / `FAIL` / `NO-VERDICT` |
| 波形配置 | `vivado-sim/<bus>/tb_*_top.wcfg` |
| 仿真日志 | `vivado-sim/<bus>/proj/sim_<bus>.sim/sim_1/behav/xsim/simulate.log` |
| 波形数据库 | 同目录 `tb_*_top.wdb` |

`verdict` 三种值的含义：`PASS` 数据全对；`FAIL` 数据错或超时（`detail` 行会说清哪个主设备）；
`NO-VERDICT` 仿真没跑到判定点（多半握手死锁或 elaborate 失败，往上翻日志找 `ERROR`）。

## 6. 踩坑清单

按「踩到时的痛感」排序，全部已在脚本里规避，自己改脚本时注意别踩回去。

| 坑 | 现象 | 处理 |
|---|---|---|
| `.cmd` 写 UTF-8 中文 | `'cl' 不是内部或外部命令`，整行被拆断 | `.cmd` 保持**纯 ASCII + CRLF**（cmd.exe 按 GBK 读） |
| Git Bash 跑 `.cmd` | 退出码恒 127，判定失效 | 用 cmd；或 `cmd //c`（`/c` 会被 MSYS 改写成 `C:\`） |
| `sim_1` 没设 top | `Common 17-70 Top module not set for fileset 'sim_1'` | `sources_1` 与 `sim_1` 都要 `set_property top` |
| `launch_simulation -mode batch` | `Invalid simulation mode` | 2025.2 里 `-mode` 指 behavioral/post-synth/post-impl，别带 |
| batch 下 `add_wave` | `Wavedata 42-443` | 用 `xsim.simulate.custom_tcl` 注册波形脚本 |
| 看 xsim 退出码 | `$finish` 后返回 `0xC0000409` | 只认 `simulate.log` 里的 PASS/FAIL |
| `get_objects` 精确名 | 分组 0 个信号 | 模型端口是 `io_axi_aw_valid`，互连端口是 `axiIn_0_awvalid`，名不同 |
| `get_objects` 尾部 `*` | 分组信号数暴增（281 vs 35） | `*` 会跨层次，改用显式端口清单 |
| 多版本 Vivado | `valid license was not found` | `set VIVADO_BIN=<有 license 的>\Vivado\bin\vivado.bat` |
| `stride` 太小 | `FAIL` 但握手完全正常 | `stride` 必须 ≥ `beats × 4`（APB 是 `words × 4`） |
| 从模型 `b.id` 硬编码 0 | 主设备 1 永远等不到 B，仿真卡死 | `b.id` 必须回显 `awid` |
| 打开 `hw/spinal/test` 子目录 | Metals 报 `no build tool detected` | 打开工程根（有 `build.sbt` 的那层） |

## 7. 加第三条总线

七处改动，其余全不用碰：

1. `scripts/lib/common.sh` 的 `load_bus` 里加一个 `case`（`BUS_NUM / BUS_SRC / BUS_* / MODEL_* / TB_*`）；
2. `scripts/lib/project_kit.sh` 的 `bus_sim_script` 里加一行返回 `xx-run-sim.cmd`；
3. 新建 `scripts/xx/` 四个脚本（照抄 10~13，改 `load_bus xx`）；
4. 新建 `windows/xx/` 三个文件（照抄 14，改路径与 top 名）；
5. 源码目录 `<仓库根>/xx/`；
6. 手写 `verification/tb_xx_top.v`；
7. `windows/env/00-preflight.ps1` 的 `$needScripts` / `$needWin` 里加进新文件。
