#!/usr/bin/env bash
# =============================================================================
#  21-make-bus-verilog.sh —— 第 3 章 3.2：生成 APB 总线的 Verilog
#
#  sbt "runMain test.genApb2x8" → 回传到 apb/verilog/
#  产物：
#      Apb3Crossbar_2x8.v   2 主 8 从的 APB3 交叉开关（可独立综合、可独立交付）
#
#  用法：
#      bash scripts/apb/21-make-bus-verilog.sh
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus apb
check_toolchain

run_make_bus_verilog

printf '\n'
info "产物清单："
ls -l "$BUS_SRC/verilog"/*.v 2>/dev/null | awk '{printf "        %-32s %10s 字节\n", $9, $5}'
