#!/usr/bin/env bash
# =============================================================================
#  lib/common.sh —— 01~06 各脚本共用的「相对路径推导」与输出函数
#                   （本文件不单独执行，由各脚本 source）
#
#  【为什么全部用相对路径】
#  整套文件会上传到 GitHub，别人下载到哪里是不确定的，所以这里不写死任何
#  盘符、任何绝对路径，全部从「本文件自己的位置」往上推：
#
#      <任意位置>/SpinalHDL/              ← REPO_DIR   仓库根（下载解压出来的目录）
#          ├── AXIcrossbar/               ← SRC_AXI    AXI 源码目录
#          │      Axicrossbar.scala / fifo.scala / Config.scala
#          ├── apb/                       ← SRC_APB    APB 源码目录
#          │      Apbcrossbar.scala / ApbSim.scala / Config.scala
#          └── spinalhdl-setup-kit/
#                 └── scripts/
#                        ├── lib/common.sh   ← 本文件
#                        └── 01~06-*.sh
#
#  【AXI 与 APB 是两个独立工程】
#  两边的源码里各有一个同名（不同内容）的  object Config，放进同一个 sbt 工程
#  会直接编译冲突；而且它们的生成入口、产物文件也不一样。所以 02 脚本在 WSL
#  侧建的是两份互不相干的 sbt 工程，各有各的 build.sbt / 源码目录 / bloop /
#  hw/gen 输出：
#
#      ~/spinalhdl-projects/AXIcrossbar/
#      ~/spinalhdl-projects/apb/
#
#  【可覆盖的环境变量】
#      REPO_DIR        仓库根（默认 = 本文件往上三级）
#      SRC_AXI         仓库内 AXI 源码目录（默认 $REPO_DIR/AXIcrossbar）
#      SRC_APB         仓库内 APB 源码目录（默认 $REPO_DIR/apb）
#      WSL_PROJ_ROOT   WSL 侧工程根（默认 $HOME/spinalhdl-projects）
#      PROJ_AXI        AXI 工程目录（默认 $WSL_PROJ_ROOT/AXIcrossbar）
#      PROJ_APB        APB 工程目录（默认 $WSL_PROJ_ROOT/apb）
#      TARGET=axi|apb|all   只处理其中一个目标（等价于命令行 --axi / --apb / --all）
# =============================================================================

# ---------------------------------------------------------------------------
# 自身位置：无论从哪个 cwd 调用、用 bash xxx.sh 还是 ./xxx.sh，都算得对
# ---------------------------------------------------------------------------
_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname -- "$_LIB_DIR")"          # .../spinalhdl-setup-kit/scripts
KIT_DIR="$(dirname -- "$SCRIPTS_DIR")"           # .../spinalhdl-setup-kit
REPO_DIR="${REPO_DIR:-$(dirname -- "$KIT_DIR")}" # .../SpinalHDL      ← 仓库根

# ---------------------------------------------------------------------------
# 仓库内的两个源码目录（只认这两处，不去别的地方找）
# ---------------------------------------------------------------------------
SRC_AXI="${SRC_AXI:-$REPO_DIR/AXIcrossbar}"
SRC_APB="${SRC_APB:-$REPO_DIR/apb}"

# ---------------------------------------------------------------------------
# WSL 侧：两份独立的 sbt 工程
# ---------------------------------------------------------------------------
WSL_PROJ_ROOT="${WSL_PROJ_ROOT:-$HOME/spinalhdl-projects}"
PROJ_AXI="${PROJ_AXI:-$WSL_PROJ_ROOT/AXIcrossbar}"
PROJ_APB="${PROJ_APB:-$WSL_PROJ_ROOT/apb}"

# 工程内部约定（两个工程一致）
PROJ_SRC_SUBDIR="hw/spinal/test"    # 源码目录（源码 package 是 test）
PROJ_GEN_SUBDIR="hw/gen"            # Verilog 输出目录

# ---------------------------------------------------------------------------
# 目标（axi / apb）
# ---------------------------------------------------------------------------
resolve_targets() {
  local want="${TARGET:-all}" a
  for a in "$@"; do
    case "$a" in
      --axi) want=axi ;;
      --apb) want=apb ;;
      --all) want=all ;;
    esac
  done
  case "$want" in
    all) TARGETS=(axi apb) ;;
    axi) TARGETS=(axi) ;;
    apb) TARGETS=(apb) ;;
    *)   printf '未知目标：%s（可用 axi / apb / all）\n' "$want" >&2; exit 2 ;;
  esac
}

tgt_label()   { case "$1" in axi) printf 'AXI Crossbar';; apb) printf 'APB Crossbar';; esac; }
tgt_proj()    { case "$1" in axi) printf '%s' "$PROJ_AXI";; apb) printf '%s' "$PROJ_APB";; esac; }
tgt_src()     { case "$1" in axi) printf '%s' "$SRC_AXI";;  apb) printf '%s' "$SRC_APB";;  esac; }
tgt_name()    { case "$1" in axi) printf 'spinalhdl-axi-crossbar';; apb) printf 'spinalhdl-apb-crossbar';; esac; }
tgt_files()   { case "$1" in
                  axi) printf 'Axicrossbar.scala fifo.scala Config.scala' ;;
                  apb) printf 'Apbcrossbar.scala ApbSim.scala Config.scala' ;;
                esac; }
tgt_entries() { case "$1" in
                  axi) printf 'test.gen2x8 test.genCDC' ;;
                  apb) printf 'test.genApb2x8' ;;
                esac; }
tgt_products(){ case "$1" in
                  axi) printf 'AxiCrossbar_2x8.v / Axi_CDC.v' ;;
                  apb) printf 'Apb3Crossbar_2x8.v' ;;
                esac; }

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
# WSL 路径 -> Windows 路径（只用于把提示信息写得让人看得懂）
win_path() {
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

# 路径是否落在 Windows 磁盘上（/mnt/c、/mnt/d …）。
# 跨 9p 文件系统编译会明显变慢，所以工程目录要放在 WSL 自己的 ext4 里。
on_windows_fs() {
  case "$1" in /mnt/[a-zA-Z]/*) return 0;; *) return 1;; esac
}
