#!/usr/bin/env bash
# =============================================================================
#  10-create-bus-project.sh —— 第 2 章 2.1：建 AXI 总线的 sbt 工程
#
#  做三件事：
#      ① 在 WSL 里建 ~/spinalhdl-projects/AXIcrossbar（build.sbt / .vscode / hw 目录）
#      ② 把仓库里的互连源码同步进工程
#      ③ 自检：少什么当场说清楚，不留到 sbt 报「找不到主类」
#
#  这个工程里【只放互连本身】：
#      Axicrossbar.scala   2×8 交叉开关 + 两个生成入口
#      fifo.scala          互连里用到的 FIFO
#      Config.scala        Verilog 输出目录、时钟复位风格
#
#  刻意不放任何 testbench —— 这样 11 生成出来的 AxiCrossbar_2x8.v 是干净、
#  可独立综合的总线 RTL。激励模型属于另一个工程（见 12）。
#
#  用法（WSL 的 Ubuntu 终端，在套件目录下）：
#      bash scripts/axi/10-create-bus-project.sh
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus axi
check_toolchain

step "0/3 源文件检查"
for f in $BUS_FILES; do
  [ -f "$BUS_SRC/$f" ] || die "缺少源文件：$BUS_SRC/$f"
done
ok "源码目录：$BUS_SRC"

run_create_bus_project
