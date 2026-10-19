#!/usr/bin/env bash
# =============================================================================
#  13-make-model-verilog.sh —— 第 2 章 2.4：生成 AXI 主/从模型的 Verilog
#
#  做三件事：
#      ① 检查 12 建好的激励工程
#      ② sbt "runMain test.genAxiModels"
#      ③ 回传到仓库 AXIcrossbar/verification/models/
#
#  产物（每个文件只有一个模块，互不内联）：
#      AxiMasterModel.v    主设备激励发生器
#      AxiSlaveModel.v     从设备内存模型
#
#  下一步在 Windows 侧：
#      windows\axi\14-run-sim.cmd
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus axi
check_toolchain

run_make_models

printf '\n'
info "模型产物："
ls -l "$BUS_SRC/verification/models"/*.v 2>/dev/null | awk '{printf "        %-32s %10s 字节\n", $9, $5}'
