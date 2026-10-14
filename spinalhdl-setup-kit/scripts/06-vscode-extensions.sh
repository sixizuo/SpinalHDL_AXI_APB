#!/usr/bin/env bash
# =============================================================================
#  06-vscode-extensions.sh
#  在 WSL 侧安装 VS Code 扩展（Metals + Scala 语法高亮），并给出打开工程的指引
#
#  用法（在 WSL 的 Ubuntu 终端里，进入本套件目录后执行）：
#      cd <套件目录>
#      bash scripts/06-vscode-extensions.sh
#
#  前置条件（需在 Windows 侧先做）：
#      1) Windows 上已安装 VS Code
#      2) Windows 侧 VS Code 里已安装扩展  WSL（ms-vscode-remote.remote-wsl）
#      3) 已经用 VS Code「连接到 WSL」打开过任意目录（这样 WSL 里才会出现 code 命令）
#
#  本脚本永远以退出码 0 结束 —— 装不上也不阻断整个流程。
# =============================================================================
set -uo pipefail

# 载入共用的路径推导与输出函数（相对本脚本定位，不依赖任何绝对路径）
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" \
  || { echo "缺少 scripts/lib/common.sh，文件不完整" >&2; exit 1; }

for a in "$@"; do
  case "$a" in
    --axi|--apb|--all) : ;;
    -h|--help) sed -n '2,/^set -uo pipefail/p' "$0" | head -n -1; exit 0 ;;
    *) printf '未知参数：%s（用 -h 查看帮助）\n' "$a" >&2; exit 2 ;;
  esac
done
resolve_targets "$@"

step "1/3 检查 code 命令（WSL 侧）"
if ! command -v code >/dev/null 2>&1; then
  cat <<'EOF'
    在 WSL 里找不到 code 命令 —— 这表示还没用 VS Code 连接过这个 WSL 发行版。

    请在【Windows】上按顺序做：
      1) 安装 VS Code：https://code.visualstudio.com/  （安装时勾选「添加到 PATH」）
      2) 打开 VS Code -> 左侧扩展 -> 搜索并安装：WSL
         扩展 ID：ms-vscode-remote.remote-wsl
      3) 左下角绿色按钮 -> "连接到 WSL"（或 Ctrl+Shift+P -> WSL: Connect to WSL）
      4) 连接成功后，打开一个 WSL 终端，输入 code 就应该有反应了

    完成后重新执行本脚本。
EOF
  step "2/3 跳过（还没有 code 命令）"
  step "3/3 打开工程的命令"
  for t in "${TARGETS[@]}"; do
    info "$(tgt_label "$t")：  code $(tgt_proj "$t")"
  done
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
info "说明：scala-lang.scala 是官方 Scala 语法高亮（只有 TextMate 语法、没有语言服务），"
info "      它本身就是 scalameta.metals 的 extensionPack 成员，两者不冲突，不要卸载。"

step "3/3 已装扩展清单"
ls -1 "$HOME/.vscode-server/extensions" 2>/dev/null | grep -vE '^extensions.json$' | sed 's/^/        /' || warn "还没有 ~/.vscode-server/extensions"

# ---------------------------------------------------------------------------
printf '\n'
info "本次要打开的工程（AXI 与 APB 是两个独立工程，各自单独打开一个窗口）："
for t in "${TARGETS[@]}"; do
  printf '        %-12s %s\n' "$(tgt_label "$t")" "$(tgt_proj "$t")"
done

cat <<EOF

================================================================
 用 VS Code 打开工程：

   A. 【每个工程单独打开一个 VS Code 窗口】——这一步最容易做错：
$(for t in "${TARGETS[@]}"; do printf '        code %s\n' "$(tgt_proj "$t")"; done)
      错误示范：打开 ${PROJ_AXI}/$PROJ_SRC_SUBDIR
      原因：那个子目录里没有 build.sbt，Metals 找不到构建工具，
            会退化成 "Scala CLI 单文件模式"，于是报
            no build tool detected / opened in the wrong working directory，
            并在那里留下一堆 .metals / .scala-build 残留。

      也不要把这两个工程放进同一个 VS Code 窗口：两个工程各有一个
      package test / object Config，混在一起会让 Metals 的构建目标互相干扰。

   B. 打开后依次执行（Ctrl+Shift+P）：
        1) Developer: Reload Window
        2) Metals: Restart Build Server
        3) 首次会自动下载 Metals 服务端（约 100MB，配了镜像会快）
      左下角出现 "Metals" 且不再转圈，就绪。

   C. 打开各自工程里的入口文件，在 object 上方会出现 ▶ 运行按钮：
$(for t in "${TARGETS[@]}"; do printf '        %-12s %s\n' "$(tgt_label "$t")" "$(tgt_proj "$t")/$PROJ_SRC_SUBDIR/  （object: $(tgt_entries "$t")）"; done)

   D. 体检：bash "$SCRIPTS_DIR/04-doctor.sh"
================================================================
EOF
exit 0
