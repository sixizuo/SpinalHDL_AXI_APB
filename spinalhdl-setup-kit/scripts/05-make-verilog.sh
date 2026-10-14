#!/usr/bin/env bash
# =============================================================================
#  05-make-verilog.sh —— 把 AXI / APB 的 SpinalHDL 代码分别转成 Verilog
#
#  用法（在 WSL 的 Ubuntu 终端里，进入本套件目录后执行）：
#      cd <套件目录>
#      bash scripts/05-make-verilog.sh               # 两个工程都生成
#      bash scripts/05-make-verilog.sh --axi         # 只生成 AXI
#      bash scripts/05-make-verilog.sh --apb         # 只生成 APB
#      bash scripts/05-make-verilog.sh --clean       # 先 sbt clean 再全量重建
#      bash scripts/05-make-verilog.sh --no-export   # 不回传到仓库内的 verilog/
#
#  产出：
#      工程内（WSL）   ~/spinalhdl-projects/AXIcrossbar/hw/gen/AxiCrossbar_2x8.v
#                      ~/spinalhdl-projects/AXIcrossbar/hw/gen/Axi_CDC.v
#                      ~/spinalhdl-projects/apb/hw/gen/Apb3Crossbar_2x8.v
#      回传（仓库内）  <仓库根>/AXIcrossbar/verilog/
#                      <仓库根>/apb/verilog/
#                      （加 --no-export 可关闭；回传目录随仓库位置走，不写死盘符）
#
#  注意：Config.scala 里 targetDirectory = "hw/gen" 是【相对路径】，
#        所以 sbt 必须在各工程的根目录运行（本脚本已自动 cd）。
# =============================================================================
set -uo pipefail

# 载入共用的路径推导与输出函数（相对本脚本定位，不依赖任何绝对路径）
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" \
  || { echo "缺少 scripts/lib/common.sh，文件不完整" >&2; exit 1; }

DO_CLEAN=0
DO_EXPORT=1
for a in "$@"; do
  case "$a" in
    --axi|--apb|--all) : ;;
    --clean)     DO_CLEAN=1 ;;
    --no-export) DO_EXPORT=0 ;;
    -h|--help)   sed -n '2,/^set -uo pipefail/p' "$0" | head -n -1; exit 0 ;;
    *) printf '未知参数：%s（用 -h 查看帮助）\n' "$a" >&2; exit 2 ;;
  esac
done
resolve_targets "$@"

printf '\033[1m生成 Verilog —— 目标：%s\033[0m\n' "${TARGETS[*]}"

# ---------------------------------------------------------------------------
step "1/5 检查工具链与源码"
command -v java >/dev/null 2>&1 || die "未找到 java，请先执行 scripts/01-install-toolchain.sh"
command -v sbt  >/dev/null 2>&1 || die "未找到 sbt，请先执行 scripts/01-install-toolchain.sh"
info "sbt : $(sbt --script-version 2>/dev/null || echo '(版本未知)')"

for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  [ -d "$PROJ" ]        || die "$(tgt_label "$t")：工程目录不存在 $PROJ（先执行 scripts/02-create-project.sh）"
  [ -f "$PROJ/build.sbt" ] || die "$(tgt_label "$t")：$PROJ 下没有 build.sbt（先执行 scripts/02-create-project.sh）"
  grep -qE 'Compile[[:space:]]*/[[:space:]]*scalaSource' "$PROJ/build.sbt" \
    || die "$(tgt_label "$t")：build.sbt 缺少 Compile / scalaSource —— 请先执行 scripts/02-create-project.sh"
  for f in $(tgt_files "$t"); do
    [ -f "$PROJ/$PROJ_SRC_SUBDIR/$f" ] \
      || die "$(tgt_label "$t")：缺少 $PROJ_SRC_SUBDIR/$f —— 请先执行 scripts/03-import-source.sh"
  done
  ok "$(tgt_label "$t")：构建脚本与 $(printf '%s' "$(tgt_files "$t")") 就位"
done

# ---------------------------------------------------------------------------
step "2/5 逐工程清理会干扰构建的残留"
for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  DEST="$PROJ/$PROJ_SRC_SUBDIR"
  printf '\n\033[1m---- [%s] %s ----\033[0m\n' "$t" "$(tgt_label "$t")"
  cd "$PROJ" || die "无法进入 $PROJ"

  rm -rf .metals
  rm -rf "$PROJ_SRC_SUBDIR/.metals" "$PROJ_SRC_SUBDIR/.scala-build" "$PROJ_SRC_SUBDIR/.vscode"
  for f in build.sc .mill-version; do
    if [ -e "$f" ] && [ ! -e "$f.bak" ]; then
      mv -f "$f" "$f.bak" && info "$f -> $f.bak"
    fi
  done
  info "已清理 $PROJ 下可能干扰 Metals / sbt 的残留"

  if [ -e "$HOME/.local/share/scalacli/bloop/daemon/socket" ]; then
    pkill -f 'bloop.daemon' 2>/dev/null || true
    sleep 1
    rm -rf "$HOME/.local/share/scalacli/bloop"
    info "已清理 scala-cli 遗留的 Bloop daemon（它会导致 Metals 连 BSP 超时）"
  fi
done

# ---------------------------------------------------------------------------
step "3/5 逐工程导出并校验 Bloop 配置"
for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  printf '\n\033[1m---- [%s] %s ----\033[0m\n' "$t" "$(tgt_label "$t")"
  cd "$PROJ" || die "无法进入 $PROJ"

  sbt bloopInstall || die "$(tgt_label "$t")：sbt bloopInstall 失败，请把上面的 sbt 输出发出来"

  shopt -s nullglob
  BLOOP_HIT=""
  scan_bloop() {
    BLOOP_HIT=""
    local f
    for f in .bloop/*.json; do
      grep -q 'hw/spinal' "$f" 2>/dev/null && BLOOP_HIT="$BLOOP_HIT $(basename "$f")"
    done
  }
  scan_bloop
  if [ -z "$BLOOP_HIT" ]; then
    info "首轮未命中，重试一次……"
    sbt bloopInstall || die "$(tgt_label "$t")：sbt bloopInstall 失败"
    scan_bloop
  fi
  shopt -u nullglob

  if [ -n "$BLOOP_HIT" ]; then
    ok "Bloop 已收录 hw/spinal：$BLOOP_HIT"
    info "（文件名由 build.sbt 里 lazy val 的名字决定，本工程是 root.json）"
  else
    ls -la .bloop 2>&1 | sed 's/^/        /'
    die "$(tgt_label "$t")：Bloop 仍未收录 hw/spinal。请把上面输出 + $PROJ/build.sbt 发出来"
  fi
done

# ---------------------------------------------------------------------------
step "4/5 逐工程生成 Verilog"
LOG="/tmp/make-verilog-$$.log"

for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  ENTRIES="$(tgt_entries "$t")"
  printf '\n\033[1m---- [%s] %s ----\033[0m\n' "$t" "$(tgt_label "$t")"
  cd "$PROJ" || die "无法进入 $PROJ"
  info "入口：$(printf 'runMain %s  ' $ENTRIES)"

  if [ "$DO_CLEAN" -eq 1 ]; then
    sbt clean || die "$(tgt_label "$t")：sbt clean 失败"
  fi

  # 组装 runMain 参数
  SBT_ARGS=()
  for e in $ENTRIES; do SBT_ARGS+=("runMain $e"); done

  run_gen() {
    sbt "${SBT_ARGS[@]}" 2>&1 | tee "$LOG"
    return "${PIPESTATUS[0]}"
  }

  if ! run_gen; then
    # 已知坑（仅 AXI 源码里有这一行）：IDE 误自动导入
    #     import javax.swing.text.FlowView
    # 该行未被任何代码使用；万一当前 JDK 不含 java.desktop 模块，编译器会直接失败。
    if grep -q 'javax\.swing' "$LOG" 2>/dev/null && [ -f "$PROJ_SRC_SUBDIR/Axicrossbar.scala" ]; then
      SRC="$PROJ_SRC_SUBDIR/Axicrossbar.scala"
      info "检测到 javax.swing 误导入导致编译失败，自动注释该行后重试……"
      [ -f "$SRC.bak-swing" ] || cp -a "$SRC" "$SRC.bak-swing"
      sed -i 's|^import javax\.swing\.text\.FlowView.*|// import javax.swing.text.FlowView   // IDE 误自动导入，未被使用，已由 05-make-verilog.sh 注释|' "$SRC"
      run_gen || die "$(tgt_label "$t")：自动修复后仍失败，请把上面的 sbt 输出发出来"
    else
      printf '\n----- sbt 输出最后 60 行 -----\n'
      tail -60 "$LOG"
      die "$(tgt_label "$t")：生成 Verilog 失败，请把上面的输出发出来"
    fi
  fi

  VFILES="$(find "$PROJ_GEN_SUBDIR" -maxdepth 1 -name '*.v' 2>/dev/null | sort)"
  if [ -n "$VFILES" ]; then
    ok "已生成："
    # shellcheck disable=SC2086
    ls -l $VFILES | awk '{printf "          %-28s %8s bytes\n", $9, $5}'
  else
    warn "$PROJ_GEN_SUBDIR 里没有 .v 文件，检查上面的 sbt 输出"
  fi
done

# ---------------------------------------------------------------------------
step "5/5 汇总与回传"

for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  EXPORT_DIR="$(tgt_src "$t")/verilog"
  printf '\n\033[1m---- [%s] %s ----\033[0m\n' "$t" "$(tgt_label "$t")"

  VFILES="$(find "$PROJ/$PROJ_GEN_SUBDIR" -maxdepth 1 -name '*.v' 2>/dev/null | sort)"
  info "工程内产物：$PROJ/$PROJ_GEN_SUBDIR"
  if [ -n "$VFILES" ]; then
    # shellcheck disable=SC2086
    ls -l $VFILES | awk '{printf "        %-28s %8s bytes\n", $9, $5}'
  else
    warn "没有产物"
  fi

  if [ "$DO_EXPORT" -eq 1 ] && [ -n "$VFILES" ]; then
    if mkdir -p "$EXPORT_DIR" 2>/dev/null; then
      # shellcheck disable=SC2086
      cp -f $VFILES "$EXPORT_DIR"/ && {
        ok "已回传到 $EXPORT_DIR"
        info "（在 Windows 上就是 $(win_path "$EXPORT_DIR")）"
      }
    else
      warn "无法写入 $EXPORT_DIR，跳过回传（不影响工程内的产物）"
    fi
  elif [ "$DO_EXPORT" -eq 0 ]; then
    info "已指定 --no-export，不回传"
  fi

  # 装了 iverilog / verilator 就顺手做一次语法检查
  if [ -n "$VFILES" ]; then
    if command -v iverilog >/dev/null 2>&1; then
      info "iverilog 语法检查（-t null）"
      # shellcheck disable=SC2086
      iverilog -g2012 -t null $VFILES && ok "iverilog 通过" || warn "iverilog 报了语法警告/错误（不一定影响综合）"
    elif command -v verilator >/dev/null 2>&1; then
      info "verilator lint"
      # shellcheck disable=SC2086
      verilator --lint-only -Wno-fatal $VFILES && ok "verilator lint 通过" || warn "verilator 报了 lint 警告"
    else
      info "（没装 iverilog / verilator，跳过语法检查；可选：sudo apt install -y iverilog）"
    fi
  fi
done

cat <<EOF

================================================================
 完成。两个工程各自独立生成，互不影响。

 AXI 工程
   工程内：$PROJ_AXI/$PROJ_GEN_SUBDIR/     ->  $(tgt_products axi)
   回传  ：$SRC_AXI/verilog/

 APB 工程
   工程内：$PROJ_APB/$PROJ_GEN_SUBDIR/     ->  $(tgt_products apb)
   回传  ：$SRC_APB/verilog/

 改完代码要重新生成，Verilog 不会自动更新：
   1) 在 VS Code 里打开对应工程，按 Ctrl+Shift+B
   2) 或者重新执行本脚本（可加 --axi / --apb 只做其中一个）
================================================================
EOF
