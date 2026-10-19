#!/usr/bin/env bash
# =============================================================================
#  23-make-model-verilog.sh —— 第 3 章 3.4：生成 APB 主/从模型的 Verilog
#
#  sbt "runMain test.genApbModels" → 回传到 apb/verification/models/
#  产物：
#      ApbMasterModel.v
#      ApbSlaveModel.v
#
#  下一步在 Windows 侧：
#      windows\apb\24-run-sim.cmd
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus apb
check_toolchain

run_make_models

printf '\n'
info "模型产物："
ls -l "$BUS_SRC/verification/models"/*.v 2>/dev/null | awk '{printf "        %-32s %10s 字节\n", $9, $5}'
