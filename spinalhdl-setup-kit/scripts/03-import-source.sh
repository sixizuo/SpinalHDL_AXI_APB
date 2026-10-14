#!/usr/bin/env bash
# =============================================================================
#  03-import-source.sh —— 把仓库内的 .scala 源码分别导入两个独立工程
#
#  源码目录（固定在这两处，脚本不会去别的地方找；位置由仓库根相对推导）：
#      AXI :  <仓库根>/AXIcrossbar/     Axicrossbar.scala  fifo.scala     Config.scala
#      APB :  <仓库根>/apb/             Apbcrossbar.scala  ApbSim.scala   Config.scala
#
#  目标工程（由 02 脚本创建）：
#      AXI :  ~/spinalhdl-projects/AXIcrossbar/hw/spinal/test/
#      APB :  ~/spinalhdl-projects/apb/hw/spinal/test/
#
#  用法（在 WSL 的 Ubuntu 终端里，进入本套件目录后执行）：
#      cd <套件目录>
#      bash scripts/03-import-source.sh              # 两个工程都导入
#      bash scripts/03-import-source.sh --axi        # 只导 AXI
#      bash scripts/03-import-source.sh --apb        # 只导 APB
#      bash scripts/03-import-source.sh --force      # 用源文件强覆盖工程内的同名文件
#
#  【覆盖策略】默认不覆盖：
#      目标文件不存在            -> 复制过去
#      已存在且内容与源文件相同  -> 跳过
#      已存在但内容不同          -> 保留工程内的版本并提示（不冲掉你在 VS Code 里改过的代码）
#      加 --force               -> 用源文件覆盖，旧文件备份成 .bak-<时间戳>
#
#  本脚本不会导入 build.sbt：工程里的 build.sbt 由 02 脚本生成，已正确设置源码目录。
# =============================================================================
set -uo pipefail

# 载入共用的路径推导与输出函数（相对本脚本定位，不依赖任何绝对路径）
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" \
  || { echo "缺少 scripts/lib/common.sh，文件不完整" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
FORCE=0
for a in "$@"; do
  case "$a" in
    --axi|--apb|--all) : ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,/^set -uo pipefail/p' "$0" | head -n -1; exit 0 ;;
    *) printf '未知参数：%s（用 -h 查看帮助）\n' "$a" >&2; exit 2 ;;
  esac
done
resolve_targets "$@"

# 比较两个文件内容是否等价（忽略 CRLF / LF 换行差异——脚本导入时会把 CRLF 转成 LF）
same_file() {
  cmp -s <(tr -d '\r' < "$1") <(tr -d '\r' < "$2")
}

# ---------------------------------------------------------------------------
step "1/4 检查仓库路径推导"
info "本套件目录 : $KIT_DIR"
info "仓库根     : $REPO_DIR"
printf '\n'
for t in "${TARGETS[@]}"; do
  printf '    %-12s 源码 %s\n' "$(tgt_label "$t")" "$(tgt_src "$t")"
  printf '    %-12s 工程 %s\n' ""              "$(tgt_proj "$t")"
done
printf '\n'
if [ "$REPO_DIR" = "/" ] || [ ! -d "$REPO_DIR" ]; then
  die "推不出合理的仓库根（$REPO_DIR）—— 请确认 scripts/lib/common.sh 还在原位"
fi
ok "仓库根存在"

# ---------------------------------------------------------------------------
step "2/4 检查工程骨架与源码目录"

PROBLEM=0
for t in "${TARGETS[@]}"; do
  d_src="$(tgt_src "$t")"
  d_proj="$(tgt_proj "$t")"
  if [ ! -d "$d_proj" ]; then
    warn "$(tgt_label "$t")：工程目录不存在 $d_proj（请先执行 scripts/02-create-project.sh）"
    PROBLEM=1
  elif [ ! -f "$d_proj/build.sbt" ]; then
    warn "$(tgt_label "$t")：$d_proj 下没有 build.sbt（请先执行 scripts/02-create-project.sh）"
    PROBLEM=1
  else
    ok "  $(tgt_label "$t")：工程骨架就位"
  fi
  if [ ! -d "$d_src" ]; then
    warn "$(tgt_label "$t")：找不到源码目录 $d_src"
    info "  仓库根下应有的两个源码目录："
    info "    $(tgt_src axi)    ← Axicrossbar.scala / fifo.scala / Config.scala"
    info "    $(tgt_src apb)    ← Apbcrossbar.scala / ApbSim.scala / Config.scala"
    PROBLEM=1
  fi
done
[ "$PROBLEM" -eq 0 ] || die "上面列出的问题先解决，再重跑本脚本"
ok "工程骨架与源码目录都在"

# ---------------------------------------------------------------------------
step "3/4 逐个工程导入源码"

for t in "${TARGETS[@]}"; do
  SRC_DIR="$(tgt_src "$t")"
  PROJ="$(tgt_proj "$t")"
  DEST="$PROJ/$PROJ_SRC_SUBDIR"
  FILES="$(tgt_files "$t")"

  printf '\n\033[1m---- [%s] %s ----\033[0m\n' "$t" "$(tgt_label "$t")"
  info "源  $SRC_DIR"
  info "目标 $DEST"

  # 源文件清点
  MISSING=0; N=0
  for f in $FILES; do
    N=$((N+1))
    if [ -f "$SRC_DIR/$f" ]; then
      info "  $(printf '%-22s' "$f") $(printf '%6s' "$(wc -c < "$SRC_DIR/$f" | tr -d ' ')") bytes"
    else
      warn "  缺少 $f"
      MISSING=$((MISSING+1))
    fi
  done
  [ "$MISSING" -eq 0 ] || die "$(tgt_label "$t") 的源码目录里缺少 $MISSING 个必需文件，请补齐后重跑"
  ok "  $N 个源文件齐全"

  mkdir -p "$DEST" || die "无法创建 $DEST"

  for f in $FILES; do
    src="$SRC_DIR/$f"
    dst="$DEST/$f"
    if [ ! -f "$dst" ]; then
      cp -f "$src" "$dst" || die "复制 $f 失败"
      ok "  已导入 $f"
    elif same_file "$src" "$dst"; then
      info "  已是最新，跳过 $f"
    elif [ "$FORCE" -eq 1 ]; then
      cp -a "$dst" "$dst.bak-$STAMP"
      cp -f "$src" "$dst" || die "复制 $f 失败"
      ok "  已用源文件覆盖 $f（旧版本备份为 $f.bak-$STAMP）"
    else
      warn "  $f 已存在且与源文件不同 —— 保留工程内的版本"
      info "  （如需用源文件强制覆盖，重跑并加 --force）"
    fi
  done

  # Windows 侧的 CRLF 换行会让 scalac 报怪错，统一转成 LF
  for f in "$DEST"/*.scala; do
    [ -f "$f" ] || continue
    if grep -qU $'\r' "$f" 2>/dev/null; then
      sed -i 's/\r$//' "$f" && info "  已把 $(basename "$f") 的 CRLF 转为 LF"
    fi
  done

  # 核对工程配置
  if grep -qE 'Compile[[:space:]]*/[[:space:]]*scalaSource' "$PROJ/build.sbt"; then
    ok "  build.sbt 含 Compile / scalaSource"
  else
    die "  build.sbt 缺少 Compile / scalaSource —— 请重新执行 scripts/02-create-project.sh"
  fi
  if [ -f "$PROJ/build.sc" ] || [ -f "$PROJ/.mill-version" ]; then
    warn "  工程里存在 build.sc / .mill-version（mill 构建文件）→ Metals 可能误判构建工具"
  fi

  printf '\n'
  info "  ---- 当前源码目录 ----"
  ls -l "$DEST" | sed 's/^/          /'
  printf '\n'
  info "  ---- 生成入口（由 05 脚本调用）----"
  for e in $(tgt_entries "$t"); do
    grep -n -E "^\s*object\s+${e##*.}\b" "$DEST"/*.scala 2>/dev/null | sed 's/^/          /'
  done
done

# ---------------------------------------------------------------------------
step "4/4 汇总"
for t in "${TARGETS[@]}"; do
  printf '    %-12s %s\n' "$(tgt_label "$t")" "$(tgt_proj "$t")/$PROJ_SRC_SUBDIR"
  printf '    %-12s   %s\n' "" "$(tgt_files "$t")"
done

cat <<EOF

================================================================
 源码导入完成。

 AXI 与 APB 是两份独立工程，源码分别落在各自的 hw/spinal/test 下，
 互不影响（注意两边各有一个 object Config，本就不该放进同一个工程）。

 下一步：
     bash "$SCRIPTS_DIR/04-doctor.sh"
================================================================
EOF
