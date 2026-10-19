#!/usr/bin/env bash
# =============================================================================
#  lib/project_kit.sh —— 「建 sbt 工程骨架 / 同步源码 / 调 sbt 生成 / 回传产物」
#                        四件事的实现，四个 WSL 脚本（10~13、20~23）共用
#
#  【为什么单独抽出来】
#  每个总线要建两个工程（总线 / 激励），两条总线就是四个工程；
#  四个工程的 build.sbt、.vscode、同步、生成、回传逻辑完全一样，
#  差别只在「叫什么、源码是哪几个、入口是哪个」。这些差异都在 common.sh 的
#  load_bus 里，本文件只管流程。
# =============================================================================

# ---------------------------------------------------------------------------
# write_if_changed <目标文件>     内容从 stdin 读
#
# 内容没变就不重写：避免每次执行都刷新 mtime，让 git 里出现一堆「假改动」。
# 真改了就先把旧文件备份成 <名字>.bak-<时间戳>。
# ---------------------------------------------------------------------------
write_if_changed() {
  local target="$1" tmp stamp
  tmp="$(mktemp)"
  cat > "$tmp"
  if [ -f "$target" ] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    info "内容未变，跳过 $(basename "$target")"
    return 0
  fi
  if [ -f "$target" ]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    cp -a "$target" "$target.bak-$stamp"
    info "旧文件已备份 -> $(basename "$target").bak-$stamp"
  fi
  mkdir -p "$(dirname "$target")"
  mv -f "$tmp" "$target"
  ok "已写入 $target"
}

# ---------------------------------------------------------------------------
# check_toolchain   WSL 侧生成 Verilog 所需的两样东西
# ---------------------------------------------------------------------------
check_toolchain() {
  command -v java >/dev/null 2>&1 || die "未找到 java，请先执行 scripts/env/01-install-toolchain.sh"
  command -v sbt  >/dev/null 2>&1 || die "未找到 sbt，请先执行 scripts/env/01-install-toolchain.sh"
  SBT_VERSION_DETECTED="$(sbt --script-version 2>/dev/null | tr -d '\r' | head -1)"
  case "$SBT_VERSION_DETECTED" in
    [0-9]*.[0-9]*.[0-9]*) : ;;
    *) SBT_VERSION_DETECTED="1.10.2" ;;
  esac
  JDK_BIN="$(command -v javac 2>/dev/null || command -v java)"
  JHOME="$(dirname "$(dirname "$(readlink -f "$JDK_BIN")")")"
  SBT_BIN="$(readlink -f "$(command -v sbt)")"
  info "sbt $SBT_VERSION_DETECTED  /  JDK $JHOME"
}

# ---------------------------------------------------------------------------
# make_skeleton <工程目录> <工程名> <说明> <生成入口...>
#
# 建出一个能直接 `sbt runMain ...` 的最小工程：
#     build.sbt / project/build.properties / project/plugins.sbt
#     .gitignore / .vscode/{settings,tasks}.json
#     hw/spinal/test（源码） / hw/gen（Verilog 输出）
# ---------------------------------------------------------------------------
make_skeleton() {
  local dir="$1" name="$2" desc="$3"
  shift 3
  local entries="$*"

  mkdir -p "$dir/$PROJ_SRC_SUBDIR" "$dir/$PROJ_GEN_SUBDIR" "$dir/project" "$dir/.vscode" \
    || die "无法创建 $dir"
  cd "$dir" || die "无法进入 $dir"
  ok "目录就绪：$dir"

  write_if_changed "build.sbt" <<EOF
// =============================================================================
//  由 spinalhdl-setup-kit 的建工程脚本自动生成，可以随时重跑覆盖
//  工程：$name      （$desc）
//
//  【关键一行】
//      Compile / scalaSource := baseDirectory.value / "hw" / "spinal"
//
//  本工程源码放在 hw/spinal 下，不是 sbt 默认的 src/main/scala，
//  所以必须显式告诉 sbt 源码目录在哪。少了这一行：
//      · VS Code / Metals 报  no build target for .../*.scala
//      · 终端里 sbt "runMain $entries" 报找不到主类
//
//  【版本】Scala 2.12.20 + SpinalHDL 1.10.1
//      Scala 不要改成 2.13.x —— Metals 对 2.13 的语义支持会降级。
// =============================================================================

ThisBuild / version      := "1.0"
ThisBuild / scalaVersion := "2.12.20"

val spinalVersion    = "1.10.1"
val spinalCore       = "com.github.spinalhdl" %% "spinalhdl-core"       % spinalVersion
val spinalLib        = "com.github.spinalhdl" %% "spinalhdl-lib"        % spinalVersion
val spinalIdslPlugin = compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion)

lazy val root = (project in file("."))
  .settings(
    name := "$name",
    Compile / scalaSource := baseDirectory.value / "hw" / "spinal",   // 【关键一行】
    libraryDependencies ++= Seq(
      spinalCore,
      spinalLib,
      spinalIdslPlugin
    )
  )

// 生成 Verilog 时把 JVM 用满；独立进程更稳，也避免和 sbt 的类加载器打架
fork := true
EOF

  printf 'sbt.version=%s\n' "$SBT_VERSION_DETECTED" | write_if_changed "project/build.properties"

  write_if_changed "project/plugins.sbt" <<'EOF'
// 默认不启用任何插件：sbt 启动最快，生成 Verilog 不需要它们。
// 想用 VS Code / Metals 时把下面一行的注释去掉（首次会自动联网下载）：
//
//     addSbtPlugin("ch.epfl.scala" % "sbt-bloop" % "1.5.17")
EOF

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

  {
    printf '{\n'
    printf '  // 由 spinalhdl-setup-kit 生成 —— %s\n' "$name"
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
    [ -n "$JHOME" ] && printf ',\n  "metals.javaHome": "%s"' "$JHOME"
    [ -n "$SBT_BIN" ] && printf ',\n  "metals.sbtScript": "%s"' "$SBT_BIN"
    printf '\n}\n'
  } | write_if_changed ".vscode/settings.json"

  {
    local e first=1
    printf '{\n'
    printf '  // 由 spinalhdl-setup-kit 生成 —— %s\n' "$name"
    printf '  "version": "2.0.0",\n'
    printf '  "tasks": [\n'
    printf '    {\n'
    printf '      "label": "SpinalHDL: 生成 Verilog",\n'
    printf '      "detail": "sbt %s，产物在 hw/gen",\n' "$entries"
    printf '      "type": "shell",\n'
    printf '      "command": "sbt",\n'
    printf '      "args": ['
    for e in $entries; do
      [ "$first" -eq 1 ] || printf ', '
      printf '"runMain %s"' "$e"
      first=0
    done
    printf '],\n'
    printf '      "options": { "cwd": "${workspaceFolder}" },\n'
    printf '      "group": { "kind": "build", "isDefault": true },\n'
    printf '      "presentation": { "reveal": "always", "panel": "dedicated", "clear": true },\n'
    printf '      "problemMatcher": []\n'
    printf '    }\n'
    printf '  ]\n'
    printf '}\n'
  } | write_if_changed ".vscode/tasks.json"
}

# ---------------------------------------------------------------------------
# sync_sources <工程目录> <源文件...>
#
# 把仓库里的 .scala 复制到工程的 hw/spinal/test/。
# 只复制列出来的文件 —— 千万别用 cp *.scala：两个工程的源码里都有
# package test / object Config，混在一起会直接「重复定义」编译失败。
# ---------------------------------------------------------------------------
sync_sources() {
  local dir="$1"
  shift
  local f dst
  mkdir -p "$dir/$PROJ_SRC_SUBDIR" || die "无法创建 $dir/$PROJ_SRC_SUBDIR"
  for f in "$@"; do
    [ -f "$f" ] || die "源文件不存在：$f"
    dst="$dir/$PROJ_SRC_SUBDIR/$(basename "$f")"
    if [ -f "$dst" ] && cmp -s "$f" "$dst"; then
      info "未变：$(basename "$f")"
    else
      cp -f "$f" "$dst" && ok "已同步 $(basename "$f")"
    fi
  done
}

# ---------------------------------------------------------------------------
# clean_build_junk <工程目录>
#
# 有些残留会让 sbt 一启动就报奇怪的错（Bloop socket、误生成的 build.sc 等）。
# ---------------------------------------------------------------------------
clean_build_junk() {
  local dir="$1"
  rm -rf "$dir/.metals" "$dir/$PROJ_SRC_SUBDIR/.metals" \
         "$dir/$PROJ_SRC_SUBDIR/.scala-build" "$dir/$PROJ_SRC_SUBDIR/.vscode"
  local f
  for f in build.sc .mill-version; do
    if [ -e "$dir/$f" ] && [ ! -e "$dir/$f.bak" ]; then
      mv -f "$dir/$f" "$dir/$f.bak" && info "$f -> $f.bak"
    fi
  done
}

# ---------------------------------------------------------------------------
# sbt_gen <工程目录> <日志文件> <生成入口...>
#
# 在工程目录里跑 sbt "runMain <入口>"，失败时把原因说清楚。
# ---------------------------------------------------------------------------
sbt_gen() {
  local dir="$1" log="$2"
  shift 2
  local entries=("$@")
  local args=() e
  for e in "${entries[@]}"; do args+=("runMain $e"); done
  info "入口：$(printf 'runMain %s  ' "${entries[@]}")"

  run_sbt() {
    ( cd "$dir" && sbt "${args[@]}" ) 2>&1 | tee "$log"
    return "${PIPESTATUS[0]}"
  }

  if run_sbt; then
    return 0
  fi

  # 已知坑：IDE 误自动导入的 import javax.swing.text.FlowView 会让编译失败
  # （该行未被使用；JDK 缺 java.desktop 模块时直接报错）。
  local swing_hit=""
  local f
  for f in "$dir/$PROJ_SRC_SUBDIR"/*.scala; do
    grep -q 'import javax\.swing' "$f" 2>/dev/null || continue
    swing_hit="$f"
    break
  done
  if [ -n "$swing_hit" ]; then
    info "检测到 javax.swing 误导入，注释掉该行后重试……"
    [ -f "$swing_hit.bak-swing" ] || cp -a "$swing_hit" "$swing_hit.bak-swing"
    sed -i 's|^import javax\.swing\..*|// import javax.swing.*  // IDE 误自动导入，未使用，已注释|' "$swing_hit"
    run_sbt && return 0
  fi

  printf '\n----- sbt 输出最后 40 行 -----\n'
  tail -40 "$log"
  return 1
}

# ---------------------------------------------------------------------------
# export_v <工程产物目录> <仓库目标目录> <文件名...>
#
# 只回传列出来的 .v。缺一个就报错 —— 名字对不上时早点发现，
# 比在 Vivado 里看到 "module not found" 再回来找要省事得多。
# ---------------------------------------------------------------------------
export_v() {
  local gen="$1" dst="$2"
  shift 2
  local f missing=0
  mkdir -p "$dst" || die "无法创建 $dst"
  for f in "$@"; do
    if [ -f "$gen/$f" ]; then
      cp -f "$gen/$f" "$dst/" && ok "回传 $f  ($(wc -c < "$dst/$f" | tr -d ' ') 字节)"
    else
      warn "没找到 $gen/$f"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || return 1
  info "仓库位置：$dst"
  info "Windows 路径：$(win_path "$dst")"
}

# =============================================================================
#  四步流程（10~13 / 20~23 只是 load_bus 之后调用其中一个，逻辑都在这儿）
# =============================================================================

# ---------------------------------------------------------------------------
# run_create_bus_project —— 建「总线工程」：只有互连源码，没有任何 TB
# ---------------------------------------------------------------------------
run_create_bus_project() {
  step "1/3 建工程骨架：$BUS_PROJ"
  make_skeleton "$BUS_PROJ" "$BUS_NAME" "$BUS_LABEL（可独立交付的总线 RTL）" $BUS_ENTRIES

  step "2/3 同步总线源码"
  local files=() f
  for f in $BUS_FILES; do files+=("$BUS_SRC/$f"); done
  sync_sources "$BUS_PROJ" "${files[@]}"

  step "3/3 自检"
  grep -qE 'Compile[[:space:]]*/[[:space:]]*scalaSource' "$BUS_PROJ/build.sbt" \
    || die "build.sbt 缺少 Compile / scalaSource"
  ok "build.sbt 关键行就位"
  for f in $BUS_FILES; do
    [ -f "$BUS_PROJ/$PROJ_SRC_SUBDIR/$f" ] || die "源码没同步进去：$f"
  done
  ok "源码齐了：$BUS_FILES"

  printf '\n'
  info "工程位置（WSL 内部，编译比 /mnt 快很多）："
  info "  $BUS_PROJ"
  info "下一步：bash scripts/$BUS/$((BUS_NUM + 1))-make-bus-verilog.sh"
}

# ---------------------------------------------------------------------------
# run_make_bus_verilog —— sbt 生成总线 RTL，并回传到仓库 verilog/
# ---------------------------------------------------------------------------
run_make_bus_verilog() {
  step "1/3 检查工程是否就绪"
  [ -f "$BUS_PROJ/build.sbt" ] || die "找不到 $BUS_PROJ/build.sbt，请先执行 $BUS_NUM-create-bus-project.sh"
  local f
  for f in $BUS_FILES; do
    [ -f "$BUS_PROJ/$PROJ_SRC_SUBDIR/$f" ] || die "工程里缺少 $f，请重新执行建工程脚本"
  done
  ok "$BUS_PROJ 就绪"

  step "2/3 sbt 生成 Verilog"
  local log="/tmp/${BUS}-bus-$$.log"
  sbt_gen "$BUS_PROJ" "$log" $BUS_ENTRIES || die "生成失败，完整日志：$log"
  ok "生成完成，产物在 $BUS_PROJ/$PROJ_GEN_SUBDIR"

  step "3/3 回传到仓库"
  export_v "$BUS_PROJ/$PROJ_GEN_SUBDIR" "$BUS_SRC/verilog" $BUS_PRODUCTS || die "产物不全，检查上面的警告"
  printf '\n'
  info "这些 .v 是【可独立使用】的总线 RTL：不含 testbench、不含激励模型，"
  info "可以直接加进任何工程综合。"
}

# ---------------------------------------------------------------------------
# run_create_sim_project —— 建「激励工程」：只有模型源码，不含互连
# ---------------------------------------------------------------------------
run_create_sim_project() {
  step "1/3 建工程骨架：$BUS_SIM_PROJ"
  make_skeleton "$BUS_SIM_PROJ" "$BUS_SIM_NAME" "$BUS_LABEL 仿真激励模型" $MODEL_ENTRY

  step "2/3 同步模型源码"
  [ -f "$BUS_SRC/$MODEL_SRC" ] || die "模型源码不存在：$BUS_SRC/$MODEL_SRC"
  sync_sources "$BUS_SIM_PROJ" "$BUS_SRC/$MODEL_SRC"

  step "3/3 自检"
  ok "模型源码：$MODEL_SRC"
  info "这个工程刻意【不包含】互连源码：模型和 DUT 只在 Verilog 层通过端口相连，"
  info "所以换一个互连实现，模型照样能用。"
  printf '\n'
  info "下一步：bash scripts/$BUS/$((BUS_NUM + 3))-make-model-verilog.sh"
}

# ---------------------------------------------------------------------------
# run_make_models —— 生成主/从模型 Verilog，回传到 verification/models/
# ---------------------------------------------------------------------------
run_make_models() {
  step "1/3 检查工程是否就绪"
  [ -f "$BUS_SIM_PROJ/build.sbt" ] || die "找不到 $BUS_SIM_PROJ/build.sbt，请先执行 $((BUS_NUM + 2))-create-sim-project.sh"
  [ -f "$BUS_SIM_PROJ/$PROJ_SRC_SUBDIR/$(basename "$MODEL_SRC")" ] \
    || die "工程里缺少 $(basename "$MODEL_SRC")，请重新执行建工程脚本"
  ok "$BUS_SIM_PROJ 就绪"

  step "2/3 sbt 生成 Verilog"
  local log="/tmp/${BUS}-models-$$.log"
  sbt_gen "$BUS_SIM_PROJ" "$log" "$MODEL_ENTRY" || die "生成失败，完整日志：$log"

  step "3/3 回传到仓库"
  export_v "$BUS_SIM_PROJ/$PROJ_GEN_SUBDIR" "$BUS_SRC/verification/models" $MODEL_PRODUCTS \
    || die "产物不全，检查上面的警告"
  printf '\n'
  info "下一步（Windows 侧）：运行 windows/$BUS/$(bus_sim_script) 做 Vivado 仿真"
}

# 14 / 24 的脚本名，用来在提示里写清楚
bus_sim_script() {
  case "$BUS" in
    axi) printf '14-run-sim.cmd' ;;
    apb) printf '24-run-sim.cmd' ;;
  esac
}
