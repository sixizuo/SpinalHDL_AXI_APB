#!/usr/bin/env bash
# =============================================================================
#  11-make-bus-verilog.sh —— 第 2 章 2.2：生成 AXI 总线的 Verilog
#
#  做三件事：
#      ① 检查 10 建好的工程还在不在
#      ② sbt "runMain test.gen2x8" + "runMain test.genCDC"
#      ③ 把产物回传到仓库 AXIcrossbar/verilog/
#
#  产物：
#      AxiCrossbar_2x8.v   2 主 8 从的 AXI4 交叉开关（可独立综合、可独立交付）
#      Axi_CDC.v           跨时钟域桥（互连里引用了它，所以一起生成）
#
#  注意：这里【不生成】任何 testbench。仿真用的主/从设备模型在 13 里生成。
#
#  用法：
#      bash scripts/axi/11-make-bus-verilog.sh
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus axi
check_toolchain

run_make_bus_verilog

printf '\n'
info "产物清单："
ls -l "$BUS_SRC/verilog"/*.v 2>/dev/null | awk '{printf "        %-32s %10s 字节\n", $9, $5}'
