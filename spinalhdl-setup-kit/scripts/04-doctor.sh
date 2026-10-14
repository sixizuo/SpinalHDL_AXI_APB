#!/usr/bin/env bash
# =============================================================================
#  04-doctor.sh —— SpinalHDL(AXI / APB → Verilog) 环境体检
#
#  用法（在 WSL 的 Ubuntu 终端里，进入本套件目录后执行）：
#      cd <套件目录>
#      bash scripts/04-doctor.sh              # 两个工程都查
#      bash scripts/04-doctor.sh --axi        # 只查 AXI
#      bash scripts/04-doctor.sh --apb        # 只查 APB
#
#  只读检查，不修改任何文件。逐项对照下面 10 类已知问题，最后给出 OK/WARN/FAIL
#  统计。遇到 FAIL 时，把对应章节号抄下来去查教程「故障排查」一节。
# =============================================================================
set -uo pipefail

# 载入共用的路径推导与输出函数（相对本脚本定位，不依赖任何绝对路径）
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" \
  || { echo "缺少 scripts/lib/common.sh，文件不完整" >&2; exit 1; }

OK=0; WARN=0; BAD=0

pass() { printf '  \033[1;32m[ OK ]\033[0m %s\n' "$1"; OK=$((OK+1)); }
warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
fail() { printf '  \033[1;31m[FAIL]\033[0m %s\n' "$1"; BAD=$((BAD+1)); }
hdr()  { printf '\n\033[1;36m=== %s ===\033[0m\n' "$1"; }
info() { printf '         %s\n' "$1"; }

for a in "$@"; do
  case "$a" in
    --axi|--apb|--all) : ;;
    -h|--help) sed -n '2,/^set -uo pipefail/p' "$0" | head -n -1; exit 0 ;;
    *) printf '未知参数：%s（用 -h 查看帮助）\n' "$a" >&2; exit 2 ;;
  esac
done
resolve_targets "$@"

printf '\033[1mSpinalHDL 环境体检 —— 目标：%s\033[0m\n' "${TARGETS[*]}"

# ---------------------------------------------------------------------------
hdr "1. 运行环境与路径推导"
info "kernel : $(uname -r)"
info "distro : $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"
info "user   : $(id -un)"
if grep -qi microsoft /proc/version 2>/dev/null; then pass "运行在 WSL 中"; else warn "未检测到 WSL 标志（非 WSL 也能用）"; fi
info "本套件目录 : $KIT_DIR"
info "仓库根     : $REPO_DIR"
if [ -d "$REPO_DIR/AXIcrossbar" ] || [ -d "$REPO_DIR/apb" ]; then
  pass "仓库根下能找到源码目录"
else
  fail "仓库根 $REPO_DIR 下找不到 AXIcrossbar/ 或 apb/ —— 目录结构可能被挪动过"
fi
if on_windows_fs "$WSL_PROJ_ROOT"; then
  warn "工程根 $WSL_PROJ_ROOT 落在 Windows 磁盘（/mnt/...）：跨 9p 编译会明显变慢"
  info "建议改到 WSL 自己的 ext4：export WSL_PROJ_ROOT=\$HOME/spinalhdl-projects"
else
  pass "工程根在 WSL 原生文件系统（编译快）"
fi

# ---------------------------------------------------------------------------
hdr "2. JDK（Metals 要求 11 / 17 / 21）"
if command -v java >/dev/null 2>&1; then
  JDK_BIN="$(command -v javac 2>/dev/null || command -v java)"
  JHOME="$(dirname "$(dirname "$(readlink -f "$JDK_BIN")")")"
  info "java      : $(java -version 2>&1 | head -1)"
  info "JAVA_HOME : $JHOME"
  case "$(java -version 2>&1 | head -1)" in
    *'"17'*|*'"21'*|*'"11'*) pass "JDK 版本满足要求";;
    *) fail "JDK 版本过低，Metals 至少需要 11";;
  esac
else
  fail "找不到 java，请执行 scripts/01-install-toolchain.sh"
fi

# ---------------------------------------------------------------------------
hdr "3. sbt"
if command -v sbt >/dev/null 2>&1; then
  info "path    : $(readlink -f "$(command -v sbt)")"
  info "version : $(sbt --script-version 2>/dev/null || echo '(未探测到，回退方案的 sbt 属正常)')"
  pass "sbt 已安装"
else
  fail "找不到 sbt，请执行 scripts/01-install-toolchain.sh"
fi

# ---------------------------------------------------------------------------
hdr "4. 镜像 / 加速配置（可选，不影响功能）"
if [ -f "$HOME/.sbt/repositories" ] && grep -q 'aliyun\|tencent\|huaweicloud' "$HOME/.sbt/repositories" 2>/dev/null; then
  pass "~/.sbt/repositories 已配国内镜像"
else
  warn "~/.sbt/repositories 未配国内镜像（依赖下载可能很慢）"
fi
if [ -f "$HOME/.config/coursier/mirror.properties" ]; then
  pass "coursier mirror 已配置（Metals 下载 server/bloop 会走镜像）"
else
  warn "未配置 coursier mirror"
fi

# ---------------------------------------------------------------------------
hdr "5. 仓库内的源码清点"
for t in "${TARGETS[@]}"; do
  SRC_DIR="$(tgt_src "$t")"
  printf '  [%s] %s\n' "$t" "$(tgt_label "$t")"
  if [ -d "$SRC_DIR" ]; then
    miss=0
    for f in $(tgt_files "$t"); do
      if [ -f "$SRC_DIR/$f" ]; then
        info "$(printf '%-22s' "$f") $(printf '%6s' "$(wc -c < "$SRC_DIR/$f" | tr -d ' ')") bytes"
      else
        info "$(printf '%-22s' "$f") 缺失"; miss=$((miss+1))
      fi
    done
    [ "$miss" -eq 0 ] && pass "$SRC_DIR 下的源文件齐全" || fail "$SRC_DIR 缺 $miss 个文件"
  else
    fail "找不到源码目录 $SRC_DIR"
  fi
done

# ---------------------------------------------------------------------------
hdr "6. 逐个工程检查"

for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  DEST="$PROJ/$PROJ_SRC_SUBDIR"
  printf '\n  \033[1m---- [%s] %s —— %s ----\033[0m\n' "$t" "$(tgt_label "$t")" "$PROJ"

  if [ ! -d "$PROJ" ]; then
    fail "    工程目录不存在（先跑 scripts/02-create-project.sh）"
    continue
  fi
  pass "    工程目录存在"

  # 骨架文件
  for f in build.sbt project/build.properties .vscode/settings.json; do
    [ -e "$PROJ/$f" ] && pass "    $f" || fail "    缺少 $f"
  done

  # 源码文件
  for f in $(tgt_files "$t"); do
    [ -e "$DEST/$f" ] && pass "    $PROJ_SRC_SUBDIR/$f" || fail "    缺少 $PROJ_SRC_SUBDIR/$f（跑 03-import-source.sh）"
  done

  # 核心项：scalaSource
  if [ -f "$PROJ/build.sbt" ]; then
    if grep -qE 'Compile[[:space:]]*/[[:space:]]*scalaSource' "$PROJ/build.sbt"; then
      pass "    build.sbt 含 Compile / scalaSource"
      grep -nE 'scalaVersion|spinalVersion|scalaSource' "$PROJ/build.sbt" | sed 's/^/             /'
    else
      fail "    build.sbt 缺少 Compile / scalaSource —— hw/spinal 下的源码不会参与编译！"
      info "    修复：重跑 scripts/02-create-project.sh"
    fi
  fi

  # 生成入口
  for e in $(tgt_entries "$t"); do
    o="${e##*.}"
    if grep -rqE "^\s*object\s+$o\b" "$PROJ/hw/spinal" 2>/dev/null; then
      pass "    找到 object $o"
    else
      warn "    没找到 object $o"
    fi
  done

  # Bloop
  shopt -s nullglob
  BLOOP_HIT=""
  if [ -d "$PROJ/.bloop" ]; then
    for f in "$PROJ"/.bloop/*.json; do
      grep -q 'hw/spinal' "$f" 2>/dev/null && BLOOP_HIT="$BLOOP_HIT $(basename "$f")"
    done
    if [ -n "$BLOOP_HIT" ]; then
      pass "    Bloop 已收录 hw/spinal：$BLOOP_HIT"
    else
      warn "    Bloop 配置里没有 hw/spinal —— 跑一次 05-make-verilog.sh 会重新导出"
    fi
  else
    warn "    还没有 .bloop 目录（打开 VS Code 或跑 05 脚本后生成）"
  fi
  shopt -u nullglob

  # 隔离性检查：源码目录里不该混入另一个工程的文件
  EXPECTED="$(tgt_files "$t")"
  EXTRA=""
  for f in "$DEST"/*.scala; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    case " $EXPECTED " in *" $b "*) ;; *) EXTRA="$EXTRA $b" ;; esac
  done
  if [ -n "$EXTRA" ]; then
    warn "    源码目录里混入了不属于本工程的文件：$EXTRA —— 两个工程应当互相独立"
  else
    pass "    源码目录只含本工程的 $(printf '%s' "$EXPECTED")"
  fi

  # 产物
  if [ -d "$PROJ/$PROJ_GEN_SUBDIR" ]; then
    V="$(find "$PROJ/$PROJ_GEN_SUBDIR" -maxdepth 1 -name '*.v' 2>/dev/null)"
    if [ -n "$V" ]; then
      # shellcheck disable=SC2086
      find "$PROJ/$PROJ_GEN_SUBDIR" -maxdepth 1 -name '*.v' -printf '             %f  (%s bytes)\n' | sort
      pass "    已生成 Verilog（预期产物：$(tgt_products "$t")）"
    else
      warn "    $PROJ_GEN_SUBDIR 为空，还没生成 Verilog（跑 05-make-verilog.sh）"
    fi
  else
    warn "    还没有 $PROJ_GEN_SUBDIR 目录"
  fi

  # 回传到仓库的目录
  EXPORT_DIR="$(tgt_src "$t")/verilog"
  if [ -d "$EXPORT_DIR" ] && [ -n "$(find "$EXPORT_DIR" -maxdepth 1 -name '*.v' 2>/dev/null)" ]; then
    pass "    已回传到 $(win_path "$EXPORT_DIR")"
  else
    info "    回传目录 $EXPORT_DIR 暂无 .v（05 脚本会自动回传）"
  fi
done

# ---------------------------------------------------------------------------
hdr "7. VS Code（WSL 侧）"
EX="$HOME/.vscode-server/extensions"
if [ -d "$EX" ]; then
  ls -1 "$EX" | grep -vE '^extensions.json$' | sed 's/^/         /'
  ls -1 "$EX" | grep -q '^scalameta.metals-' && pass "scalameta.metals 已装在 WSL 侧" || fail "WSL 侧缺 scalameta.metals"
  ls -1 "$EX" | grep -q '^scala-lang.scala-'  && pass "scala-lang.scala 已装（Scala 语法高亮）" || warn "建议装 scala-lang.scala"
else
  warn "找不到 $EX —— 说明还没用 VS Code「连接到 WSL」打开过工程"
  info "先在 Windows 安装 VS Code + WSL 扩展，再执行 code $(tgt_proj axi)"
fi
command -v code >/dev/null 2>&1 && pass "WSL 里 code 命令可用" || warn "WSL 里没有 code 命令（用 VS Code 连接一次 WSL 后就会出现）"

# ---------------------------------------------------------------------------
hdr "8. SpinalHDL 依赖缓存（离线可用性）"
C="$HOME/.cache/coursier/v1/https/repo1.maven.org/maven2/com/github/spinalhdl"
if [ -d "$C" ]; then
  for a in spinalhdl-core_2.12 spinalhdl-lib_2.12 spinalhdl-idsl-plugin_2.12 spinalhdl-sim_2.12; do
    v="$(ls "$C/$a" 2>/dev/null | tr '\n' ' ')"
    [ -n "$v" ] && pass "$a : $v" || warn "$a 未缓存（首次编译需联网）"
  done
  ls "$C" 2>/dev/null | grep -q '_2.13' && info "（缓存里还有 2.13 版本，属正常，本工程用 2.12）"
else
  warn "还没有 SpinalHDL 依赖缓存，首次编译需联网（已配镜像的话会快很多）"
fi

# ---------------------------------------------------------------------------
hdr "9. 历史坑位集中复查"
for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  DEST="$PROJ/$PROJ_SRC_SUBDIR"
  printf '  [%s] %s\n' "$t" "$(tgt_label "$t")"
  if [ -e "$PROJ/build.sc" ] || [ -e "$PROJ/.mill-version" ]; then
    warn "    工程里有 build.sc / .mill-version（mill 构建文件）→ Metals 可能误判构建工具"
  else
    pass "    无 mill 构建文件干扰"
  fi
  if [ -d "$DEST/.metals" ] || [ -d "$DEST/.scala-build" ]; then
    warn "    $PROJ_SRC_SUBDIR 下有 .metals/.scala-build 残留（曾把 VS Code 开在这个子目录里）"
    info "    后果：Metals 找不到构建工具，退化成 Scala CLI 单文件模式"
    info "    清理：rm -rf $DEST/.metals $DEST/.scala-build $DEST/.vscode"
  else
    pass "    无错误工作区残留"
  fi
  if [ -f "$DEST/Axicrossbar.scala" ]; then
    if grep -q 'javax\.swing' "$DEST/Axicrossbar.scala" 2>/dev/null; then
      warn "    Axicrossbar.scala 里有 IDE 误自动导入 import javax.swing.text.FlowView（未使用）"
      info "    JDK 17 带 java.desktop 时仍可编译；建议删掉这一行"
    else
      pass "    无 javax.swing 误导入"
    fi
  fi
done

if [ -e "$HOME/.local/share/scalacli/bloop/daemon/socket" ]; then
  warn "检测到 scala-cli 遗留的 Bloop daemon socket，可能抢占 BSP 端口导致 Metals 连接超时"
  info "清理：pkill -f bloop.daemon; rm -rf ~/.local/share/scalacli/bloop"
fi

# ---------------------------------------------------------------------------
hdr "10. 两个工程的隔离性"
if [ "$(printf '%s' "${TARGETS[*]}")" = "axi apb" ]; then
  if [ "$PROJ_AXI" = "$PROJ_APB" ]; then
    fail "AXI 与 APB 的工程目录是同一个（$PROJ_AXI）—— 两边都有 object Config，会重复定义"
  else
    pass "AXI 与 APB 工程目录相互独立"
    info "AXI : $PROJ_AXI"
    info "APB : $PROJ_APB"
  fi
else
  info "只检查了 ${TARGETS[*]}，跳过隔离性检查"
fi

# ---------------------------------------------------------------------------
printf '\n\033[1m========================================\033[0m\n'
printf ' 体检结果：OK=%d  WARN=%d  FAIL=%d\n' "$OK" "$WARN" "$BAD"
if [ "$BAD" -eq 0 ]; then
  printf ' 结论：环境可用。\n'
else
  printf ' 结论：有阻塞项（FAIL），按上面的提示修复后重跑。\n'
fi
printf '\033[1m========================================\033[0m\n'
exit 0
