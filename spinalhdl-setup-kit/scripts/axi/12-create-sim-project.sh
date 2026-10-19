#!/usr/bin/env bash
# =============================================================================
#  12-create-sim-project.sh —— 第 2 章 2.3：建 AXI 仿真激励的 sbt 工程
#
#  做三件事：
#      ① 在 WSL 里建 ~/spinalhdl-projects/AXIcrossbar-sim
#      ② 同步模型源码 AXIcrossbar/sim/AxiModels.scala
#      ③ 自检
#
#  为什么要第二个工程（而不是和总线混在一起）：
#      · 总线工程要能「干净地」生成可交付 RTL，多一个 TB 源码目录就会把它
#        的产物搅浑（SpinalHDL 会把同一个 generateVerilog 里的子模块全部
#        内联进一个 .v 文件）；
#      · 模型工程不引用互连，换一个互连实现模型照样能用；
#      · 两边各自有 build.sbt，改模型不会牵动总线，反之亦然。
#
#  模型源码里的两个组件：
#      AxiMasterModel   主设备：按 base/stride/seed/id 端口发 burst，并逐拍自检
#      AxiSlaveModel    从设备：一块真内存 + 标准 AXI4 从端握手
#
#  用法：
#      bash scripts/axi/12-create-sim-project.sh
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus axi
check_toolchain

run_create_sim_project
