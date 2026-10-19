#!/usr/bin/env bash
# =============================================================================
#  02-vscode-extensions.sh —— 环境准备第三步：给 VS Code 装 Scala 扩展
#
#  用法（WSL 的 Ubuntu 终端，在套件目录下）：
#      bash scripts/env/02-vscode-extensions.sh
#
#  前置条件（都在 Windows 侧做）：
#      1) 装了 VS Code
#      2) VS Code 里装了扩展　WSL（ms-vscode-remote.remote-wsl）
#      3) 用 VS Code「连接到 WSL」打开过一次目录（这样 WSL 里才有 code 命令）
#
#  本脚本永远以退出码 0 结束：装不上也不阻断后面的实验流程，
#  因为它跟「生成 Verilog」「跑仿真」完全无关，只影响写代码时的补全。
# =============================================================================
set -uo pipefail

_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh"

step "1/3 检查 code 命令（WSL 侧）"
if ! command -v code >/dev/null 2>&1; then
  cat <<'EOF'
    在 WSL 里找不到 code 命令 —— 这表示还没用 VS Code 连接过这个 WSL 发行版。

    请在【Windows】上按顺序做：
      1) 安装 VS Code：https://code.visualstudio.com/ （安装时勾选「添加到 PATH」）
      2) 打开 VS Code -> 左侧扩展 -> 搜索并安装：WSL
         扩展 ID：ms-vscode-remote.remote-wsl
      3) 左下角绿色按钮 -> "连接到 WSL"（或 Ctrl+Shift+P -> WSL: Connect to WSL）
      4) 连接成功后打开一个 WSL 终端，输入 code 应该就有反应

    完成后重新执行本脚本。
EOF
  step "2/3 跳过（还没有 code 命令）"
  step "3/3 后面要打开的工程"
  info "AXI 总线工程      $PROJ_AXI"
  info "AXI 激励工程      $PROJ_AXI_SIM"
  info "APB 总线工程      $PROJ_APB"
  info "APB 激励工程      $PROJ_APB_SIM"
  exit 0
fi
ok "code 命令可用：$(command -v code)"

step "2/3 安装扩展（装到 WSL 侧）"
for ext in scalameta.metals scala-lang.scala; do
  info "安装 $ext ……"
  if code --install-extension "$ext" --force >/dev/null 2>&1; then
    ok "$ext 已安装"
  else
    warn "$ext 安装失败（可稍后在 VS Code 扩展面板里手动装）"
  fi
done
info "说明：scala-lang.scala 是官方语法高亮（只有 TextMate 语法、没有语言服务），"
info "      它本身就是 scalameta.metals 的 extensionPack 成员，两者不冲突。"

step "3/3 已装扩展清单"
ls -1 "$HOME/.vscode-server/extensions" 2>/dev/null | grep -vE '^extensions.json$' | sed 's/^/        /' \
  || warn "还没有 ~/.vscode-server/extensions"

cat <<EOF

================================================================
 用 VS Code 打开工程（每个工程单独一个窗口）：

       code $PROJ_AXI           # AXI 总线（Axicrossbar.scala）
       code $PROJ_AXI_SIM       # AXI 激励模型（AxiModels.scala）
       code $PROJ_APB           # APB 总线（Apbcrossbar.scala）
       code $PROJ_APB_SIM       # APB 激励模型（ApbModels.scala）

   注意：要打开【工程根目录】（里面有 build.sbt），不要打开 hw/spinal/test 子目录。
         那个子目录里没有 build.sbt，Metals 会退化成 "Scala CLI 单文件模式"，
         报 no build tool detected，还会留下一堆 .metals / .scala-build 残留。

   打开后（Ctrl+Shift+P）：
       1) Developer: Reload Window
       2) Metals: Restart Build Server
       3) 首次会自动下载 Metals 服务端（约 100MB，配了镜像会快）
     左下角出现 "Metals" 且不再转圈，就绪。
================================================================
EOF
exit 0
