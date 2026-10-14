# SpinalHDL AXI / APB → Verilog 环境搭建套件

在 Windows 11 上用 WSL2(Ubuntu) + VS Code + sbt + Metals 搭建 SpinalHDL 开发环境，
把 AXI 与 APB 两套互连代码分别转成 Verilog。

**所有脚本都用相对路径**：整套文件下载到哪里都能直接跑，不写死任何盘符。
**AXI 与 APB 在 WSL 侧是两个完全独立的工程**，各有各的 `build.sbt`、源码目录和产物目录。

---

## 1. 目录结构

```
<任意位置>/SpinalHDL/                              ← 仓库根（下载解压出来的目录）
    ├── AXIcrossbar/                               ← AXI 源码
    │       Axicrossbar.scala   fifo.scala   Config.scala
    ├── apb/                                       ← APB 源码
    │       Apbcrossbar.scala   ApbSim.scala   Config.scala
    └── spinalhdl-setup-kit/
        ├── README.md                              ← 本文件
        ├── SpinalHDL_AXI_APB_转Verilog_环境搭建教程.docx
        │                                          ← 从零开始的图文步骤教程（先看它）
        ├── windows/
        │   └── 00-windows-preflight.ps1           ← Windows 前置检查（只读）
        └── scripts/
            ├── lib/common.sh                      ← 路径推导与输出函数（各脚本共用）
            ├── 01-install-toolchain.sh            ← 工具链：apt 镜像 + JDK17 + sbt + 依赖镜像
            ├── 02-create-project.sh               ← 建两个独立工程骨架
            ├── 03-import-source.sh                ← 分别导入两套 .scala 源码
            ├── 04-doctor.sh                       ← 环境体检（只读）
            ├── 05-make-verilog.sh                 ← 分别生成 Verilog 并回传
            └── 06-vscode-extensions.sh            ← 安装 VS Code 扩展
```

## 2. 路径约定

脚本启动时从 **`scripts/lib/common.sh` 自身的位置** 往上推导，全部相对：

| 用途 | 推导方式 | 默认落点 |
|---|---|---|
| 仓库根 `REPO_DIR` | 套件目录的上一级 | 随下载位置走 |
| AXI 源码 `SRC_AXI` | `$REPO_DIR/AXIcrossbar` | 随下载位置走 |
| APB 源码 `SRC_APB` | `$REPO_DIR/apb` | 随下载位置走 |
| AXI 工程 `PROJ_AXI` | `$WSL_PROJ_ROOT/AXIcrossbar` | `~/spinalhdl-projects/AXIcrossbar` |
| APB 工程 `PROJ_APB` | `$WSL_PROJ_ROOT/apb` | `~/spinalhdl-projects/apb` |
| AXI 产物回传 | `$SRC_AXI/verilog` | 仓库内 |
| APB 产物回传 | `$SRC_APB/verilog` | 仓库内 |

WSL 侧工程刻意放在 `$HOME` 下的 ext4 文件系统里，不放在 `/mnt/d`：
跨 9p 文件系统编译会明显变慢（04 脚本会检测并提醒）。

**为什么是两个工程**：两份源码里各有一个同名的 `package test / object Config`，
塞进同一个 sbt 工程会「重复定义」直接编译失败；顶层模块与生成入口也不一样。

## 3. 执行顺序（每个脚本独立运行）

在 **WSL 的 Ubuntu 终端**里执行：

```bash
cd <下载位置>/SpinalHDL/spinalhdl-setup-kit

bash scripts/01-install-toolchain.sh
bash scripts/02-create-project.sh        # 建两个工程
bash scripts/03-import-source.sh         # 两个工程各自导入源码
bash scripts/04-doctor.sh
bash scripts/05-make-verilog.sh          # 两个工程各自生成 Verilog
bash scripts/06-vscode-extensions.sh
```

每个脚本都能单独重跑（幂等），重复执行不会破坏已有环境。
全部跑完的效果：两个工程的 `hw/gen` 里各出现自己的 `.v`，
并回传到 `<下载位置>/SpinalHDL/AXIcrossbar/verilog/` 与 `<下载位置>/SpinalHDL/apb/verilog/`。

## 4. 脚本清单

| 脚本 | 需要 sudo 密码 | 作用 |
|---|---|---|
| `windows/00-windows-preflight.ps1` | 建议管理员 | Windows 侧前置检查，只读；从 `$PSScriptRoot` 推导仓库根 |
| `scripts/01-install-toolchain.sh` | 是 | apt 镜像 + JDK17 + sbt + sbt/coursier 依赖镜像 |
| `scripts/02-create-project.sh` | 否 | 建 AXI、APB 两个独立工程骨架 |
| `scripts/03-import-source.sh` | 否 | 按工程分别导入各自的 `.scala` |
| `scripts/04-doctor.sh` | 否 | 10 类体检，只读 |
| `scripts/05-make-verilog.sh` | 否 | 逐工程 bloopInstall → 生成 Verilog → 回传 |
| `scripts/06-vscode-extensions.sh` | 否 | 在 WSL 侧装 Metals / Scala 扩展 |

## 5. 常用参数

| 变量 / 参数 | 默认 | 适用脚本 |
|---|---|---|
| `--axi` / `--apb` / `--all` | `--all` | 02 / 03 / 04 / 05 / 06：只处理其中一个工程 |
| `TARGET=axi\|apb\|all` | `all` | 同上（环境变量写法） |
| `REPO_DIR` | 套件目录的上一级 | 全部：改写仓库根 |
| `SRC_AXI` / `SRC_APB` | `$REPO_DIR/AXIcrossbar`、`$REPO_DIR/apb` | 03 / 04 / 05 |
| `WSL_PROJ_ROOT` | `$HOME/spinalhdl-projects` | 02 / 03 / 04 / 05 / 06 |
| `PROJ_AXI` / `PROJ_APB` | `$WSL_PROJ_ROOT/{AXIcrossbar,apb}` | 02 / 03 / 04 / 05 / 06 |
| `--no-mirror` | — | 01：不使用国内镜像 |
| `--apt-mirror=URL` | `https://mirrors.aliyun.com` | 01 |
| `--sbt-version=X` | `1.10.2` | 01：回退安装 sbt 的版本 |
| `--force` | — | 03：用源文件覆盖工程内的同名文件 |
| `--clean` | — | 05：先 `sbt clean` 再全量重建 |
| `--no-export` | — | 05：不把 `.v` 回传到仓库内 |

## 6. 三个最容易踩的坑

1. **不要用别处的 `build.sbt` 覆盖工程** —— 会冲掉 `Compile / scalaSource`，
   导致 `hw/spinal` 下的代码编译不进去。
2. **VS Code 必须打开工程根目录**（`~/spinalhdl-projects/AXIcrossbar` 或 `.../apb`），
   不要只打开 `hw/spinal/test`，否则 Metals 会退化成 Scala CLI 单文件模式；
   也不要试图把两个工程放进同一个窗口。
3. **改完代码要重新生成** —— Verilog 不会自动更新：`Ctrl+Shift+B` 或重跑 05 脚本。
