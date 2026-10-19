#!/usr/bin/env bash
# =============================================================================
#  22-create-sim-project.sh —— 第 3 章 3.3：建 APB 仿真激励的 sbt 工程
#
#  工程位置：~/spinalhdl-projects/apb-sim
#  源码：apb/sim/ApbModels.scala
#      ApbMasterModel   主设备：SETUP → ACCESS → GAP 循环，写一轮立刻读回比对
#      ApbSlaveModel    从设备：寄存器堆
#
#  用法：
#      bash scripts/apb/22-create-sim-project.sh
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus apb
check_toolchain

run_create_sim_project
