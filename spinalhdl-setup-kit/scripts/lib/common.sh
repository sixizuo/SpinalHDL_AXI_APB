#!/usr/bin/env bash
# =============================================================================
#  lib/common.sh —— 全套件共用的路径推导、总线描述与输出函数
#                  （不单独执行，由各脚本 source）
#
#  【路径全部从「本文件的位置」推出来，不写死任何盘符】
#
#      <仓库根>/                                  ← REPO_DIR
#          ├── AXIcrossbar/                       ← AXI 总线源码
#          │     Axicrossbar.scala / fifo.scala / Config.scala
#          │     ├── sim/AxiModels.scala           ← 激励模型源码
#          │     ├── verilog/                      ← 总线 RTL 产物（可独立交付）
#          │     └── verification/
#          │           ├── models/                 ← 模型 Verilog 产物
#          │           └── tb_axi_top.v            ← 手写 TB 顶层
#          ├── apb/                                ← APB 总线源码（结构同上）
#          └── spinalhdl-setup-kit/                ← 本套件
#                ├── scripts/{env,axi,apb,lib}
#                └── windows/{env,axi,apb}
#
#  【WSL 侧工程放在 ext4 里，不放 /mnt】
#  跨 9p 文件系统编译会慢好几倍，所以 sbt 工程建在
#
#      ~/spinalhdl-projects/AXIcrossbar/        ← 总线工程（只生成总线 RTL）
#      ~/spinalhdl-projects/AXIcrossbar-sim/    ← 激励工程（只生成主/从模型）
#      ~/spinalhdl-projects/apb/
#      ~/spinalhdl-projects/apb-sim/
#
#  仓库目录只用来「放源码 / 收产物」，编译不在这里发生。
#
#  【可覆盖的环境变量】
#      REPO_DIR / SRC_AXI / SRC_APB
#      WSL_PROJ_ROOT（默认 $HOME/spinalhdl-projects）
#      PROJ_AXI / PROJ_APB / PROJ_AXI_SIM / PROJ_APB_SIM
# =============================================================================

_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname -- "$_LIB_DIR")"          # .../spinalhdl-setup-kit/scripts
KIT_DIR="$(dirname -- "$SCRIPTS_DIR")"           # .../spinalhdl-setup-kit
REPO_DIR="${REPO_DIR:-$(dirname -- "$KIT_DIR")}" # 仓库根

SRC_AXI="${SRC_AXI:-$REPO_DIR/AXIcrossbar}"
SRC_APB="${SRC_APB:-$REPO_DIR/apb}"

WSL_PROJ_ROOT="${WSL_PROJ_ROOT:-$HOME/spinalhdl-projects}"
PROJ_AXI="${PROJ_AXI:-$WSL_PROJ_ROOT/AXIcrossbar}"
PROJ_APB="${PROJ_APB:-$WSL_PROJ_ROOT/apb}"
PROJ_AXI_SIM="${PROJ_AXI_SIM:-$WSL_PROJ_ROOT/AXIcrossbar-sim}"
PROJ_APB_SIM="${PROJ_APB_SIM:-$WSL_PROJ_ROOT/apb-sim}"

# 工程内部约定（四个工程一致）
PROJ_SRC_SUBDIR="hw/spinal/test"  # Scala 源码（package 是 test）
PROJ_GEN_SUBDIR="hw/gen"          # Verilog 输出

# ---------------------------------------------------------------------------
#  load_bus axi|apb
#
#  一条总线在不同阶段要用到的东西都在这里，脚本里只写 $BUS_PROJ 这样的名字，
#  不再到处 case 分发。加第三条总线只要在这里加一段。
# ---------------------------------------------------------------------------
load_bus() {
  case "$1" in
    axi)
      BUS=axi
      BUS_NUM=10
      BUS_LABEL="AXI4 互连"
      BUS_SRC="$SRC_AXI"
      BUS_PROJ="$PROJ_AXI"
      BUS_SIM_PROJ="$PROJ_AXI_SIM"
      BUS_NAME="spinalhdl-axi-crossbar"
      BUS_SIM_NAME="spinalhdl-axi-models"

      # 总线工程：源码 / 生成入口 / 产物
      BUS_FILES="Axicrossbar.scala fifo.scala Config.scala"
      BUS_ENTRIES="test.gen2x8 test.genCDC"
      BUS_PRODUCTS="AxiCrossbar_2x8.v Axi_CDC.v"

      # 激励工程：源码 / 生成入口 / 产物
      MODEL_SRC="sim/AxiModels.scala"
      MODEL_ENTRY="test.genAxiModels"
      MODEL_PRODUCTS="AxiMasterModel.v AxiSlaveModel.v"

      # Vivado 侧
      BUS_TOP="AxiCrossbar_2x8"
      TB_FILE="verification/tb_axi_top.v"
      TB_TOP="tb_axi_top"
      ;;
    apb)
      BUS=apb
      BUS_NUM=20
      BUS_LABEL="APB3 互连"
      BUS_SRC="$SRC_APB"
      BUS_PROJ="$PROJ_APB"
      BUS_SIM_PROJ="$PROJ_APB_SIM"
      BUS_NAME="spinalhdl-apb-crossbar"
      BUS_SIM_NAME="spinalhdl-apb-models"

      BUS_FILES="Apbcrossbar.scala Config.scala"
      BUS_ENTRIES="test.genApb2x8"
      BUS_PRODUCTS="Apb3Crossbar_2x8.v"

      MODEL_SRC="sim/ApbModels.scala"
      MODEL_ENTRY="test.genApbModels"
      MODEL_PRODUCTS="ApbMasterModel.v ApbSlaveModel.v"

      BUS_TOP="Apb3Crossbar_2x8"
      TB_FILE="verification/tb_apb_top.v"
      TB_TOP="tb_apb_top"
      ;;
    *)
      printf '未知总线：%s（可用 axi / apb）\n' "$1" >&2
      exit 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
info() { printf '    %s\n' "$1"; }
ok()   { printf '    \033[1;32m[OK]\033[0m %s\n' "$1"; }
warn() { printf '    \033[1;33m[警告]\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31m[中止] %s\033[0m\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 跨平台小工具
# ---------------------------------------------------------------------------
win_path() {
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

on_windows_fs() {
  case "$1" in /mnt/[a-zA-Z]/*) return 0;; *) return 1;; esac
}
