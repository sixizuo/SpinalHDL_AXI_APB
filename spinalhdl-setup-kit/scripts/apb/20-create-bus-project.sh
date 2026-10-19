#!/usr/bin/env bash
# =============================================================================
#  20-create-bus-project.sh —— 第 3 章 3.1：建 APB 总线的 sbt 工程
#
#  与 AXI 的 10 号脚本一一对应，只是换成 APB 的源码与入口：
#      Apbcrossbar.scala   2×8 APB3 交叉开关 + 生成入口
#      Config.scala        Verilog 输出目录、时钟复位风格
#
#  工程位置：~/spinalhdl-projects/apb
#
#  注意：AXI 与 APB 必须是两个独立工程 —— 两边源码目录里都有
#  package test / object Config，塞进同一个 sbt 工程会直接「重复定义」编译失败。
#
#  用法：
#      bash scripts/apb/20-create-bus-project.sh
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"
. "$_HERE/../lib/project_kit.sh"

load_bus apb
check_toolchain

step "0/3 源文件检查"
for f in $BUS_FILES; do
  [ -f "$BUS_SRC/$f" ] || die "缺少源文件：$BUS_SRC/$f"
done
ok "源码目录：$BUS_SRC"

run_create_bus_project
