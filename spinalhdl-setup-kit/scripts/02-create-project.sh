#!/usr/bin/env bash
# =============================================================================
#  02-create-project.sh
#  在 WSL 侧创建 AXI 与 APB 两份【互相独立】的 SpinalHDL 工程骨架
#  （纯本地生成，不联网、不 clone）
#
#  用法（在 WSL 的 Ubuntu 终端里，进入本套件目录后执行）：
#      cd <套件目录>
#      bash scripts/02-create-project.sh              # AXI + APB 都建
#      bash scripts/02-create-project.sh --axi        # 只建 AXI
#      bash scripts/02-create-project.sh --apb        # 只建 APB
#
#  默认位置（WSL 内部，ext4 文件系统，编译比 /mnt 快很多）：
#      ~/spinalhdl-projects/AXIcrossbar/     ← AXI 工程
#      ~/spinalhdl-projects/apb/             ← APB 工程
#
#  每个工程里都有：
#      build.sbt                  ← 含【关键】Compile / scalaSource := .../hw/spinal
#      project/build.properties
#      .vscode/settings.json      ← Metals 的 JDK / sbt 路径（自动探测本机真实路径）
#      .vscode/tasks.json         ← 附带一个构建任务：Ctrl+Shift+B 一键生成 Verilog
#      .gitignore
#      hw/spinal/test/            ← .scala 源码放这里（由 03 脚本导入）
#      hw/gen/                    ← 生成的 Verilog 输出目录
#
#  【为什么是两个工程而不是一个】
#  两个源码目录里各有一个同名的  package test / object Config，塞进同一个 sbt
#  工程会直接「重复定义」编译失败；而且它们的顶层模块、生成入口、产物文件名
#  都不一样。分开建之后，改 AXI 不会影响 APB，VS Code 也可以分别打开。
#
#  本脚本幂等：重复执行不会破坏已有内容；内容没变就跳过重写；
#  被覆盖的文件都会先备份成同名 .bak-<时间戳>。
# =============================================================================
set -uo pipefail

# 载入共用的路径推导与输出函数（相对本脚本定位，不依赖任何绝对路径）
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" \
  || { echo "缺少 scripts/lib/common.sh，文件不完整" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
DEFAULT_SBT_VERSION="1.10.2"

for a in "$@"; do
  case "$a" in
    --axi|--apb|--all) : ;;
    -h|--help) sed -n '2,/^set -uo pipefail/p' "$0" | head -n -1; exit 0 ;;
    *) printf '未知参数：%s（用 -h 查看帮助）\n' "$a" >&2; exit 2 ;;
  esac
done
resolve_targets "$@"

# 内容相同就不重写，避免伪造「改动」
write_if_changed() {
  local target="$1" tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  if [ -f "$target" ] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"; info "未变，跳过 $(basename "$target")"
    return 0
  fi
  if [ -f "$target" ]; then
    cp -a "$target" "$target.bak-$STAMP" && info "旧文件已备份 -> $(basename "$target").bak-$STAMP"
  fi
  mkdir -p "$(dirname "$target")"
  mv -f "$tmp" "$target"
  ok "已写入 $target"
}

# ---------------------------------------------------------------------------
step "1/3 检查工具链与路径推导"
command -v java >/dev/null 2>&1 || die "未找到 java，请先执行 scripts/01-install-toolchain.sh"
command -v sbt  >/dev/null 2>&1 || die "未找到 sbt，请先执行 scripts/01-install-toolchain.sh"

JDK_BIN="$(command -v javac 2>/dev/null || command -v java)"
JHOME="$(dirname "$(dirname "$(readlink -f "$JDK_BIN")")")"
SBT_BIN="$(readlink -f "$(command -v sbt)")"

RAW_VER="$(sbt --script-version 2>/dev/null | tr -d '\r' | head -1)"
if printf '%s' "$RAW_VER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  SBT_VERSION="$RAW_VER"
  info "检测到本机 sbt $SBT_VERSION（直接写进 build.properties，省一次下载）"
else
  SBT_VERSION="$DEFAULT_SBT_VERSION"
  info "未探测到 sbt 版本，使用默认 $SBT_VERSION"
fi

info "java      : $(java -version 2>&1 | head -1)"
info "JAVA_HOME : $JHOME"
info "sbt       : $SBT_BIN"
printf '\n'
info "以下路径全部由「本脚本所在位置」相对推导得出，不依赖盘符："
info "  仓库根 REPO_DIR : $REPO_DIR"
info "  AXI 源码目录    : $SRC_AXI"
info "  APB 源码目录    : $SRC_APB"
info "  工程根          : $WSL_PROJ_ROOT"

if on_windows_fs "$WSL_PROJ_ROOT"; then
  warn "工程根落在 Windows 磁盘上（/mnt/...）—— 跨 9p 文件系统编译会明显变慢"
  info "建议放在 WSL 自己的 ext4 里，例如默认的 \$HOME/spinalhdl-projects"
fi

# ---------------------------------------------------------------------------
step "2/3 逐工程生成骨架（AXI 与 APB 各自独立）"

for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  NAME="$(tgt_name "$t")"
  LABEL="$(tgt_label "$t")"
  ENTRIES="$(tgt_entries "$t")"

  printf '\n\033[1m---- [%s] %s  ->  %s ----\033[0m\n' "$t" "$LABEL" "$PROJ"

  mkdir -p "$PROJ/$PROJ_SRC_SUBDIR" "$PROJ/$PROJ_GEN_SUBDIR" "$PROJ/project" "$PROJ/.vscode" \
    || die "无法创建 $PROJ"
  ok "已创建 $PROJ_SRC_SUBDIR 、$PROJ_GEN_SUBDIR 、project 、.vscode"
  cd "$PROJ" || die "无法进入 $PROJ"

  # ---------------- build.sbt ----------------
  write_if_changed "build.sbt" <<EOF
// =============================================================================
//  由 spinalhdl-setup-kit / 02-create-project.sh 生成
//  工程：$NAME      （$LABEL）
//
//  【关键一行】
//      Compile / scalaSource := baseDirectory.value / "hw" / "spinal"
//
//  本工程的 Scala 源码放在  hw/spinal  下，而不是 sbt 默认的 src/main/scala，
//  所以必须显式告诉 sbt 源码目录在哪。少了这一行，sbt 会去 src/main/scala
//  （并不存在）找源码，结果是 hw/spinal 下的代码不属于任何编译目标：
//      · VS Code / Metals 报   no build target for .../*.scala
//      · 终端里跑 sbt "runMain $ENTRIES" 报找不到主类
//
//  【版本】Scala 2.12.20 + SpinalHDL 1.10.1
//      Scala 不要改成 2.13.x —— Metals 对 2.13.14 的语义支持会降级
//      （日志：using the last known supported version 1.6.3）。
//
//  【注意】AXI 与 APB 是两个独立工程，各有各的 build.sbt；
//          两边源码里都有一个  package test / object Config，
//          千万不要把两个工程的源码目录合并到一个工程里。
// =============================================================================

ThisBuild / version      := "1.0"
ThisBuild / scalaVersion := "2.12.20"

val spinalVersion    = "1.10.1"
val spinalCore       = "com.github.spinalhdl" %% "spinalhdl-core"       % spinalVersion
val spinalLib        = "com.github.spinalhdl" %% "spinalhdl-lib"        % spinalVersion
val spinalIdslPlugin = compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion)
val scalatest        = "org.scalatest" %% "scalatest"          % "3.2.16" % "test"
val scalatestSuite   = "org.scalatest" %% "scalatest-funsuite" % "3.2.16" % "test"

lazy val root = (project in file("."))
  .settings(
    name := "$NAME",
    Compile / scalaSource := baseDirectory.value / "hw" / "spinal",   // 【关键一行】
    libraryDependencies ++= Seq(
      spinalCore,
      spinalLib,
      spinalIdslPlugin,
      scalatest,
      scalatestSuite
    )
  )

// SpinalHDL 生成 Verilog 时会把 JVM 用满，独立进程更稳（也避免和 sbt 的类加载器打架）
fork := true
EOF

  # ---------------- project/build.properties ----------------
  {
    printf 'sbt.version=%s\n' "$SBT_VERSION"
  } | write_if_changed "project/build.properties"

  # ---------------- .gitignore ----------------
  write_if_changed ".gitignore" <<'EOF'
target/
project/target/
project/project/
.bloop/
.metals/
.scala-build/
.bsp/
*.class
EOF

  # ---------------- .vscode/settings.json ----------------
  {
    printf '{\n'
    printf '  // 由 spinalhdl-setup-kit / 02-create-project.sh 生成 —— %s\n' "$NAME"
    printf '  // 缓存/扫描排除：不排除的话 VS Code 的文件监听器会被编译产物拖垮\n'
    printf '  "files.watcherExclude": {\n'
    printf '    "**/target/**": true,\n'
    printf '    "**/.bloop/**": true,\n'
    printf '    "**/.metals/**": true,\n'
    printf '    "**/.scala-build/**": true\n'
    printf '  },\n'
    printf '  "files.exclude": {\n'
    printf '    "**/.bloop": true,\n'
    printf '    "**/.scala-build": true\n'
    printf '  },\n'
    printf '  "files.eol": "\\n"'
    if [ -n "$JHOME" ]; then
      printf ',\n  // Metals 编译工程用的 JDK（必须是 11/17/21）\n'
      printf '  "metals.javaHome": "%s"' "$JHOME"
    fi
    if [ -n "$SBT_BIN" ]; then
      printf ',\n  // 明确指定 sbt 可执行文件，避免 Metals 自己找不到\n'
      printf '  "metals.sbtScript": "%s"' "$SBT_BIN"
    fi
    printf '\n}\n'
  } | write_if_changed ".vscode/settings.json"

  # ---------------- .vscode/tasks.json ----------------
  ARGS_JSON=""
  for e in $ENTRIES; do
    [ -n "$ARGS_JSON" ] && ARGS_JSON="$ARGS_JSON, "
    ARGS_JSON="$ARGS_JSON\"runMain $e\""
  done
  {
    printf '{\n'
    printf '  // 由 spinalhdl-setup-kit / 02-create-project.sh 生成 —— %s\n' "$NAME"
    printf '  "version": "2.0.0",\n'
    printf '  "tasks": [\n'
    printf '    {\n'
    printf '      "label": "SpinalHDL: 生成 Verilog",\n'
    printf '      "detail": "sbt %s，产物在 hw/gen",\n' "$ENTRIES"
    printf '      "type": "shell",\n'
    printf '      "command": "sbt",\n'
    printf '      "args": [%s],\n' "$ARGS_JSON"
    printf '      "options": { "cwd": "${workspaceFolder}" },\n'
    printf '      "group": { "kind": "build", "isDefault": true },\n'
    printf '      "presentation": { "reveal": "always", "panel": "dedicated", "clear": true },\n'
    printf '      "problemMatcher": []\n'
    printf '    },\n'
    printf '    {\n'
    printf '      "label": "SpinalHDL: 重新导出 Bloop 配置",\n'
    printf '      "detail": "Metals 报 no build target 时用这个",\n'
    printf '      "type": "shell",\n'
    printf '      "command": "sbt",\n'
    printf '      "args": ["bloopInstall"],\n'
    printf '      "options": { "cwd": "${workspaceFolder}" },\n'
    printf '      "presentation": { "reveal": "always", "panel": "dedicated", "clear": true },\n'
    printf '      "problemMatcher": []\n'
    printf '    }\n'
    printf '  ]\n'
    printf '}\n'
  } | write_if_changed ".vscode/tasks.json"

  printf '\n'
  find . -maxdepth 2 -not -path './.*/*' -not -name '.' | sort | sed 's/^/        /'
done

# ---------------------------------------------------------------------------
step "3/3 汇总"
for t in "${TARGETS[@]}"; do
  PROJ="$(tgt_proj "$t")"
  printf '    %-12s %s\n' "$(tgt_label "$t")" "$PROJ"
  printf '    %-12s %s\n' ""              "  源码：$PROJ/$PROJ_SRC_SUBDIR"
  printf '    %-12s %s\n' ""              "  产物：$PROJ/$PROJ_GEN_SUBDIR"
done

cat <<EOF

================================================================
 工程骨架创建完成（$(printf '%s' "${TARGETS[*]}")）。

 注意：不要用别处的 build.sbt 覆盖这些工程生成的 build.sbt —— 那会冲掉
       Compile / scalaSource，导致 hw/spinal 下的源码编译不进去。

 下一步：
     bash "$SCRIPTS_DIR/03-import-source.sh"
================================================================
EOF
