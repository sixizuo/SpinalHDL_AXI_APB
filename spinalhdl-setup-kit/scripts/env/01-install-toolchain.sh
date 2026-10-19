#!/usr/bin/env bash
# =============================================================================
#  01-install-toolchain.sh —— 环境准备第一步：在 WSL 里装工具链
#  在 WSL(Ubuntu) 里安装 SpinalHDL → Verilog 所需的全部工具链
#
#  用法（在 WSL 的 Ubuntu 终端里，进入本套件目录后执行）：
#      cd <套件目录>
#      bash scripts/env/01-install-toolchain.sh
#
#  可选参数：
#      --no-mirror            不改 apt 源、不写 Maven 镜像（全部走官方源）
#      --apt-mirror=URL       自定义 apt 镜像，默认 https://mirrors.aliyun.com
#      --sbt-version=1.10.2   apt 装不上 sbt 时，用该版本从 Maven 镜像下载 sbt-launch.jar
#      -h | --help            显示帮助
#
#  本脚本会：
#      1) apt 源 → 国内镜像（可关）
#      2) 安装 git curl wget unzip zip ca-certificates
#      3) 安装 openjdk-17-jdk-headless（Metals 要求 JDK 11/17/21）
#      4) 安装 sbt（apt 优先；失败则从 Maven 镜像取 sbt-launch.jar 并生成 ~/.local/bin/sbt）
#      5) 写 ~/.sbt/repositories                    —— sbt 依赖走国内 Maven 镜像
#      6) 写 ~/.config/coursier/mirror.properties   —— Metals 下载 server/bloop 走国内镜像
#
#  被覆盖的系统文件都会留 .bak-<时间戳> 备份，可随时回滚。
# =============================================================================
set -uo pipefail

# 载入共用的路径推导与输出函数（相对本脚本定位，不依赖任何绝对路径）
_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$_HERE/../lib/common.sh" \
  || { echo "缺少 scripts/lib/common.sh，文件不完整" >&2; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
APT_MIRROR="https://mirrors.aliyun.com"
MAVEN_MIRROR="https://maven.aliyun.com/repository/central"
SBT_VERSION="1.10.2"
USE_MIRROR=1

for a in "$@"; do
  case "$a" in
    --no-mirror)       USE_MIRROR=0 ;;
    --apt-mirror=*)    APT_MIRROR="${a#*=}" ;;
    --sbt-version=*)   SBT_VERSION="${a#*=}" ;;
    -h|--help)         sed -n '2,/^set -uo pipefail/p' "$0" | head -n -1; exit 0 ;;
    *) printf '未知参数：%s（用 -h 查看帮助）\n' "$a" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ---------------------------------------------------------------------------
step "0/7 环境检查"
if grep -qi microsoft /proc/version 2>/dev/null; then
  ok "运行在 WSL 中"
else
  warn "没检测到 WSL 标志 —— 本脚本假设你在 WSL 的 Ubuntu 里执行"
fi
info "$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")   内核 $(uname -r)"
command -v apt-get >/dev/null 2>&1 || die "本脚本面向 Ubuntu/Debian（未找到 apt-get）"
ok "检测到 apt"

if [ -n "$SUDO" ]; then
  info "接下来要装系统软件包，会要求输入密码 —— 就是安装 Ubuntu 时设的那个密码"
  $SUDO -v || die "sudo 授权失败"
fi

# ---------------------------------------------------------------------------
step "1/7 配置 apt 源（国内镜像；可用 --no-mirror 跳过）"
if [ "$USE_MIRROR" -eq 0 ]; then
  info "已指定 --no-mirror，跳过"
else
  changed=0
  # 传统格式（Ubuntu 22.04 及更早）
  if [ -f /etc/apt/sources.list ] && grep -qE '[a-z]+\.ubuntu\.com' /etc/apt/sources.list 2>/dev/null; then
    $SUDO cp -a /etc/apt/sources.list "/etc/apt/sources.list.bak-$STAMP"
    $SUDO sed -i -E "s#https?://([a-z0-9.-]+\.)?(archive|security|ports)\.ubuntu\.com#${APT_MIRROR}#g" /etc/apt/sources.list
    changed=1
  fi
  # deb822 格式（Ubuntu 24.04 起）
  for f in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    if grep -qE '[a-z]+\.ubuntu\.com' "$f" 2>/dev/null; then
      $SUDO cp -a "$f" "$f.bak-$STAMP"
      $SUDO sed -i -E "s#https?://([a-z0-9.-]+\.)?(archive|security|ports)\.ubuntu\.com#${APT_MIRROR}#g" "$f"
      changed=1
    fi
  done
  if [ $changed -eq 1 ]; then
    ok "apt 源已指向 ${APT_MIRROR}（原文件备份为 *.bak-$STAMP）"
  else
    ok "无需修改（源里没有 ubuntu.com 域名）"
  fi
fi

# ---------------------------------------------------------------------------
step "2/7 更新索引并安装基础工具"
$SUDO apt-get update || warn "apt-get update 有报错，继续尝试安装"
$SUDO apt-get install -y git curl wget unzip zip ca-certificates lsb-release \
  || die "基础工具安装失败（可加 --no-mirror 用官方源重试）"
ok "git / curl / wget / unzip / zip 已就绪"

# 关于 Verilator / iverilog：本套件【都不需要】，所以这里刻意不装。
#   仿真由 Windows 侧 Vivado 的 xsim 完成（windows/<总线>/14|24-run-sim.cmd），
#   Verilator 只属于旧的 SpinalSim 路线，且 apt 里的 5.x 与 SpinalHDL 1.10.1 不兼容；
#   iverilog 在 SpinalHDL 1.10.1 里被官方标注为不可用（"This backend doesn't work"）。
#   自己另外要用可以装：sudo apt install -y verilator / iverilog

# ---------------------------------------------------------------------------
step "3/7 安装 JDK 17"
if command -v javac >/dev/null 2>&1 && java -version 2>&1 | grep -qE '"(17|21|11)'; then
  ok "已有可用 JDK：$(java -version 2>&1 | head -1)"
else
  $SUDO apt-get install -y openjdk-17-jdk-headless || die "JDK 安装失败"
  ok "已安装：$(java -version 2>&1 | head -1)"
fi
JDK_BIN="$(command -v javac 2>/dev/null || command -v java)"
JHOME="$(dirname "$(dirname "$(readlink -f "$JDK_BIN")")")"
info "JAVA_HOME = $JHOME"

# ---------------------------------------------------------------------------
step "4/7 安装 sbt"
if command -v sbt >/dev/null 2>&1; then
  ok "已安装 sbt：$(sbt --script-version 2>/dev/null || echo '(版本未知)')"
else
  info "尝试 apt 安装 sbt ……"
  $SUDO apt-get install -y sbt || warn "apt 源里没有 sbt（部分 Ubuntu 版本如此），改走回退方案"
fi

if ! command -v sbt >/dev/null 2>&1; then
  info "回退方案：从 Maven 镜像下载 sbt-launch-$SBT_VERSION.jar，生成 ~/.local/bin/sbt"
  info "（这条路线不依赖 GitHub，只走 Maven 镜像，国内基本都能通）"
  LAUNCH_DIR="$HOME/.local/share/sbt-launch"
  mkdir -p "$LAUNCH_DIR" "$HOME/.local/bin"
  JAR="$LAUNCH_DIR/sbt-launch-$SBT_VERSION.jar"
  if [ ! -s "$JAR" ]; then
    curl -fL --retry 3 --connect-timeout 20 -o "$JAR" \
      "$MAVEN_MIRROR/org/scala-sbt/sbt-launch/$SBT_VERSION/sbt-launch-$SBT_VERSION.jar" \
      || die "下载 sbt-launch.jar 失败。请检查网络后重跑，或手动安装 sbt。"
  fi
  cat > "$HOME/.local/bin/sbt" <<EOF
#!/usr/bin/env bash
# 由 spinalhdl-setup-kit/01-install-toolchain.sh 生成：直接用 sbt-launch.jar 启动 sbt
exec java -Xms512M -Xmx3G -Dfile.encoding=UTF-8 -jar "$JAR" "\$@"
EOF
  chmod +x "$HOME/.local/bin/sbt"
  if ! grep -q 'Added by spinalhdl-setup-kit' "$HOME/.profile" 2>/dev/null; then
    printf '\n# Added by spinalhdl-setup-kit\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
  fi
  export PATH="$HOME/.local/bin:$PATH"
  ok "已生成 $HOME/.local/bin/sbt（新终端自动生效；当前终端已临时加入 PATH）"
fi
SBT_BIN="$(readlink -f "$(command -v sbt)")"
info "sbt 可执行文件 = $SBT_BIN"

# ---------------------------------------------------------------------------
step "5/7 配置 sbt 依赖源（国内 Maven 镜像）"
if [ "$USE_MIRROR" -eq 0 ]; then
  info "已指定 --no-mirror，跳过"
else
  mkdir -p "$HOME/.sbt"
  REPO="$HOME/.sbt/repositories"
  if [ -f "$REPO" ]; then
    cp -a "$REPO" "$REPO.bak-$STAMP" && info "旧配置已备份为 $REPO.bak-$STAMP"
  fi
  cat > "$REPO" <<'EOF'
# 由 spinalhdl-setup-kit/01-install-toolchain.sh 生成
# 作用：sbt 拉依赖时优先走国内镜像，避免 Maven Central 慢或超时
[repositories]
  local
  maven-central: https://maven.aliyun.com/repository/central
  typesafe-ivy-releases: https://repo.typesafe.com/typesafe/ivy-releases/, [organisation]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext], bootOnly
  sbt-plugin-releases: https://repo.scala-sbt.org/scalasbt/sbt-plugin-releases/, [organisation]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext], bootOnly
EOF
  ok "已写入 $REPO"
fi

# ---------------------------------------------------------------------------
step "6/7 配置 coursier 镜像（Metals 下载 server / bloop 时用）"
if [ "$USE_MIRROR" -eq 0 ]; then
  info "已指定 --no-mirror，跳过"
else
  mkdir -p "$HOME/.config/coursier"
  MIR="$HOME/.config/coursier/mirror.properties"
  if [ -f "$MIR" ]; then
    cp -a "$MIR" "$MIR.bak-$STAMP" && info "旧配置已备份为 $MIR.bak-$STAMP"
  fi
  cat > "$MIR" <<'EOF'
# 由 spinalhdl-setup-kit/01-install-toolchain.sh 生成
central.from=https://repo1.maven.org/maven2
central.to=https://maven.aliyun.com/repository/central
EOF
  ok "已写入 $MIR"
fi

# ---------------------------------------------------------------------------
step "7/7 汇总"
printf '    %-12s %s\n' "java"      "$(java -version 2>&1 | head -1)"
printf '    %-12s %s\n' "javac"     "$(javac -version 2>&1 | head -1)"
printf '    %-12s %s\n' "JAVA_HOME" "$JHOME"
printf '    %-12s %s\n' "sbt"       "$SBT_BIN"
printf '    %-12s %s\n' "git"       "$(git --version 2>&1)"

cat <<EOF

================================================================
 工具链安装完成。

 接下来按章做（每条命令都独立，可以随时单独重跑）：

   AXI 总线（第 2 章）
     bash "$SCRIPTS_DIR/axi/10-create-bus-project.sh"    # 建总线 sbt 工程
     bash "$SCRIPTS_DIR/axi/11-make-bus-verilog.sh"      # 生成互连 RTL
     bash "$SCRIPTS_DIR/axi/12-create-sim-project.sh"    # 建激励 sbt 工程
     bash "$SCRIPTS_DIR/axi/13-make-model-verilog.sh"    # 生成主/从模型

   APB 总线（第 3 章）
     bash "$SCRIPTS_DIR/apb/20-create-bus-project.sh"
     bash "$SCRIPTS_DIR/apb/21-make-bus-verilog.sh"
     bash "$SCRIPTS_DIR/apb/22-create-sim-project.sh"
     bash "$SCRIPTS_DIR/apb/23-make-model-verilog.sh"

 然后回到 Windows，双击（或 cmd 里执行）：
     windows\axi\14-run-sim.cmd
     windows\apb\24-run-sim.cmd

 四个 WSL 工程的位置：
     $PROJ_AXI        AXI 总线
     $PROJ_AXI_SIM    AXI 激励模型
     $PROJ_APB        APB 总线
     $PROJ_APB_SIM    APB 激励模型

 如果 sbt 是走「回退方案」装的，建议先执行一次：  source ~/.profile
================================================================
EOF
