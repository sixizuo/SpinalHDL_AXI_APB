# =============================================================================
#  00-preflight.ps1
#  在【裸 Windows 11】上检查是否具备安装 WSL2 + VS Code + Vivado 仿真环境
#
#  用法（在 Windows 上操作）：
#     1) 开始菜单搜索 PowerShell -> 右键「以管理员身份运行」
#     2) 进入本文件所在目录后执行（不要写死盘符，路径按你实际解压位置来）：
#          Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#          cd "<解压位置>\spinalhdl-setup-kit\windows\env"
#          .\00-preflight.ps1
#
#  本脚本【只读检查】，不改动系统任何设置。
#
#  可选参数：
#      -RepoRoot "<解压位置>\SpinalHDL"
#          仓库根（即 AXIcrossbar / apb / spinalhdl-setup-kit 三个目录的父目录）。
#          默认由本文件所在位置自动往上推两级，通常不用手动指定。
# =============================================================================

param(
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Continue'

function Say  ($m) { Write-Host $m }
function Ok   ($m) { Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Bad  ($m) { Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Hdr  ($m) { Write-Host ""; Write-Host "=== $m ===" -ForegroundColor Cyan }
function Note ($m) { Write-Host "         $m" -ForegroundColor DarkGray }

Write-Host "Windows 前置环境检查 —— SpinalHDL / WSL2 / VS Code" -ForegroundColor White

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# -----------------------------------------------------------------------------
# 路径全部相对推导：本文件在 <仓库根>\spinalhdl-setup-kit\windows\env\ 下，
# 所以往上三级才是仓库根。
# -----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $kitDir   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # ...\spinalhdl-setup-kit
    $RepoRoot = Split-Path -Parent $kitDir                              # ...\(仓库根)
}
$ScriptsDir = Join-Path $kitDir 'scripts'
$SrcAxi     = Join-Path $RepoRoot 'AXIcrossbar'
$SrcApb     = Join-Path $RepoRoot 'apb'

# -----------------------------------------------------------------------------
Hdr "0. 执行身份"
if ($isAdmin) {
    Ok "以管理员身份运行（可以查询系统功能状态）"
} else {
    Warn "当前不是管理员 —— 部分检查会跳过，建议以管理员身份重跑"
    Note "开始菜单搜索 PowerShell -> 右键「以管理员身份运行」"
}

# -----------------------------------------------------------------------------
Hdr "1. Windows 版本"
try {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $build = [int]$cv.CurrentBuild
    $disp  = $cv.DisplayVersion
    if ([string]::IsNullOrWhiteSpace($disp)) { $disp = $cv.ReleaseId }
    Say ("  产品名   : {0}" -f $cv.ProductName)
    Say ("  版本     : {0}   Build {1}.{2}" -f $disp, $cv.CurrentBuild, $cv.UBR)
    if ($build -ge 22000) {
        Ok "Windows 11（Build $build）—— 支持 wsl --install 一键安装"
    } elseif ($build -ge 19041) {
        Warn "这是 Windows 10 2004+（Build $build）—— 安装命令与 Windows 11 相同"
        Note "产品名显示 Windows 10 是正常现象，Windows 11 也会这么显示"
    } else {
        Bad "Build $build 过旧：没有 wsl --install，需要手动启用 WSL 功能"
    }
} catch {
    Warn "读取注册表失败：$($_.Exception.Message)"
}

# -----------------------------------------------------------------------------
Hdr "2. 硬件虚拟化（WSL2 的硬性前提）"
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    if ($cs.HypervisorPresent) {
        Ok "Hypervisor 已启用（Hyper-V / WSL2 已在运行）"
    } else {
        Warn "未检测到 Hypervisor 运行"
        Note "若尚未装 WSL，这是正常的；装完 WSL2 后会变成已启用"
    }
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    Say ("  CPU      : {0}" -f $cpu.Name.Trim())
    if ($cpu.VirtualizationFirmwareEnabled) {
        Ok "CPU 固件虚拟化（Intel VT-x / AMD-V）已开启"
    } else {
        Bad "CPU 固件虚拟化未开启 —— 需要在 BIOS/UEFI 里打开 Virtualization Technology"
        Note "这个开关必须在开机时进 BIOS 设，Windows 里改不了"
    }
} catch {
    Warn "查询硬件信息失败：$($_.Exception.Message)"
}

# -----------------------------------------------------------------------------
Hdr "3. WSL 功能与已安装的发行版"
$wslExe = Join-Path $env:SystemRoot 'System32\wsl.exe'
if (Test-Path $wslExe) {
    Ok "wsl.exe 存在：$wslExe"
    try {
        $prevEnc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        $listOut = & $wslExe -l -v 2>&1 | Out-String
        [Console]::OutputEncoding = $prevEnc
        if ($listOut -match 'Ubuntu') {
            Ok "已安装 Ubuntu 发行版"
            Say $listOut.Trim()
        } elseif ($listOut -match 'NAME|名称') {
            Warn "WSL 可用，但还没有安装 Ubuntu"
            Note "执行： wsl --install -d Ubuntu"
            Say $listOut.Trim()
        } else {
            Warn "暂时读不到发行版列表（可能还没装任何发行版）"
            Say $listOut.Trim()
        }
    } catch {
        Warn "执行 wsl -l -v 失败：$($_.Exception.Message)"
    }
} else {
    Bad "找不到 wsl.exe —— 需要先启用「适用于 Linux 的 Windows 子系统」"
}

if ($isAdmin) {
    foreach ($feat in @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')) {
        try {
            $f = Get-WindowsOptionalFeature -Online -FeatureName $feat -ErrorAction Stop
            if ($f.State -eq 'Enabled') { Ok "可选功能已启用：$feat" }
            else { Warn "可选功能未启用：$feat（State=$($f.State)）"; Note "启用： wsl --install（会自动启用），或 dism 手动启用后重启" }
        } catch {
            Warn "无法查询 $feat ：$($_.Exception.Message)"
        }
    }
} else {
    Warn "跳过可选功能查询（需要管理员）"
}

# -----------------------------------------------------------------------------
Hdr "4. 磁盘空间（WSL2 虚拟磁盘默认放在 C:）"
try {
    Get-PSDrive -PSProvider FileSystem -ErrorAction Stop |
        Where-Object { $_.Used -ne $null -and $_.Free -ne $null } |
        ForEach-Object {
            $freeGB = [math]::Round($_.Free / 1GB, 1)
            $usedGB = [math]::Round($_.Used / 1GB, 1)
            $line = "  {0}:  可用 {1} GB / 已用 {2} GB" -f $_.Name, $freeGB, $usedGB
            if ($_.Name -eq 'C') {
                if ($freeGB -lt 30) { Bad "$line  —— 建议 C 盘至少留 30 GB 给 WSL + 依赖缓存" }
                else { Ok "$line" }
            } else {
                Say $line
            }
        }
} catch {
    Warn "查询磁盘失败：$($_.Exception.Message)"
}

# -----------------------------------------------------------------------------
Hdr "5. VS Code（Windows 侧）"
$codeCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft VS Code\Code.exe')
)
$codeFound = $null
foreach ($p in $codeCandidates) { if (Test-Path $p) { $codeFound = $p; break } }

if ($codeFound) {
    Ok "已安装 VS Code：$codeFound"
    $ver = (Get-Item $codeFound).VersionInfo.ProductVersion
    if ($ver) { Note "版本：$ver" }
    $extDir = Join-Path $env:USERPROFILE '.vscode\extensions'
    if (Test-Path $extDir) {
        $wslExt = Get-ChildItem $extDir -Directory -Filter 'ms-vscode-remote.remote-wsl-*' -ErrorAction SilentlyContinue
        if ($wslExt) { Ok "已安装 WSL 扩展（$($wslExt[0].Name)）" }
        else {
            Warn "还没有安装 WSL 扩展"
            Note "VS Code -> 扩展 -> 搜索 WSL -> 安装（扩展 ID：ms-vscode-remote.remote-wsl）"
        }
    } else {
        Warn "还没有 $extDir —— VS Code 一次都没启动过，或没装过扩展"
    }
} else {
    Warn "未检测到 VS Code"
    Note "下载：https://code.visualstudio.com/  安装时务必勾选「添加到 PATH」"
}

# -----------------------------------------------------------------------------
Hdr "6. 套件与源码目录（路径由本文件位置相对推导，与存放位置无关）"
Say  ("  本脚本位置 : {0}" -f $PSScriptRoot)
Say  ("  仓库根     : {0}" -f $RepoRoot)
if (Test-Path (Join-Path $RepoRoot 'spinalhdl-setup-kit')) {
    Ok "脊柱套件目录存在：$(Join-Path $RepoRoot 'spinalhdl-setup-kit')"
} else {
    Bad "在仓库根下找不到 spinalhdl-setup-kit\ —— 目录结构可能被改动过"
}
$needScripts = @(
    'env\01-install-toolchain.sh',
    'env\02-vscode-extensions.sh',
    'axi\10-create-bus-project.sh', 'axi\11-make-bus-verilog.sh',
    'axi\12-create-sim-project.sh', 'axi\13-make-model-verilog.sh',
    'apb\20-create-bus-project.sh', 'apb\21-make-bus-verilog.sh',
    'apb\22-create-sim-project.sh', 'apb\23-make-model-verilog.sh'
)
$missScripts = @($needScripts | Where-Object { -not (Test-Path (Join-Path $ScriptsDir $_)) })
if ($missScripts.Count -eq 0) {
    Ok "WSL 侧脚本齐全：$ScriptsDir （共 $($needScripts.Count) 个）"
} else {
    Bad "缺少脚本：$($missScripts -join ', ')"
}

$needWin = @('axi\14-run-sim.cmd', 'axi\14-run-sim.tcl', 'axi\14-wave.tcl',
             'apb\24-run-sim.cmd', 'apb\24-run-sim.tcl', 'apb\24-wave.tcl')
$winDir = Split-Path -Parent $PSScriptRoot
$missWin = @($needWin | Where-Object { -not (Test-Path (Join-Path $winDir $_)) })
if ($missWin.Count -eq 0) {
    Ok "Windows 侧仿真脚本齐全：$winDir"
} else {
    Bad "缺少 Windows 侧脚本：$($missWin -join ', ')"
}

# 每条总线的「源码 + 已生成的 Verilog 产物」
$needAxi = @('Axicrossbar.scala', 'fifo.scala', 'Config.scala', 'sim\AxiModels.scala')
$needApb = @('Apbcrossbar.scala', 'Config.scala', 'sim\ApbModels.scala')

if (Test-Path $SrcAxi) {
    $miss = @($needAxi | Where-Object { -not (Test-Path (Join-Path $SrcAxi $_)) })
    if ($miss.Count -eq 0) { Ok "AXI 源码目录齐全：$SrcAxi  （$($needAxi -join ', ')）" }
    else { Bad "AXI 源码目录 $SrcAxi 缺少：$($miss -join ', ')" }
    $prodAxi = @('verilog\AxiCrossbar_2x8.v', 'verilog\Axi_CDC.v',
                 'verification\models\AxiMasterModel.v', 'verification\models\AxiSlaveModel.v',
                 'verification\tb_axi_top.v')
    $missP = @($prodAxi | Where-Object { -not (Test-Path (Join-Path $SrcAxi $_)) })
    if ($missP.Count -eq 0) { Ok "AXI 的 Verilog 产物齐全（RTL / 模型 / TB）" }
    else { Warn "AXI 还缺：$($missP -join ', ')"; Note "在 WSL 里跑 11 与 13 号脚本即可补齐" }
} else {
    Bad "找不到 AXI 源码目录：$SrcAxi"
}

if (Test-Path $SrcApb) {
    $miss = @($needApb | Where-Object { -not (Test-Path (Join-Path $SrcApb $_)) })
    if ($miss.Count -eq 0) { Ok "APB 源码目录齐全：$SrcApb  （$($needApb -join ', ')）" }
    else { Bad "APB 源码目录 $SrcApb 缺少：$($miss -join ', ')" }
    $prodApb = @('verilog\Apb3Crossbar_2x8.v',
                 'verification\models\ApbMasterModel.v', 'verification\models\ApbSlaveModel.v',
                 'verification\tb_apb_top.v')
    $missP = @($prodApb | Where-Object { -not (Test-Path (Join-Path $SrcApb $_)) })
    if ($missP.Count -eq 0) { Ok "APB 的 Verilog 产物齐全（RTL / 模型 / TB）" }
    else { Warn "APB 还缺：$($missP -join ', ')"; Note "在 WSL 里跑 21 与 23 号脚本即可补齐" }
} else {
    Bad "找不到 APB 源码目录：$SrcApb"
}

# -----------------------------------------------------------------------------
Hdr "7. Vivado（Windows 侧仿真的唯一依赖）"
$vivadoHits = @()
if ($env:VIVADO_BIN -and (Test-Path $env:VIVADO_BIN)) {
    Ok "VIVADO_BIN 已设置：$env:VIVADO_BIN"
    $vivadoHits += $env:VIVADO_BIN
}
foreach ($root in @('C:\AMDDesignTools', 'D:\AMDDesignTools', 'C:\Xilinx', 'D:\Xilinx')) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object {
            $b = Join-Path $_.FullName 'Vivado\bin\vivado.bat'
            if (Test-Path $b) { $vivadoHits += $b }
        }
}
$vivadoHits = @($vivadoHits | Select-Object -Unique)
if ($vivadoHits.Count -eq 0) {
    Warn "没有找到 vivado.bat"
    Note "装了 Vivado 但装在别处时，先设环境变量： set VIVADO_BIN=<...>\Vivado\bin\vivado.bat"
} else {
    Ok "找到 $($vivadoHits.Count) 个 Vivado："
    $vivadoHits | ForEach-Object { Note $_ }
    if ($vivadoHits.Count -gt 1) {
        Note "14/24 号 .cmd 会按版本号倒序取第一个；若该版本没有 license 会报错，"
        Note "此时用 set VIVADO_BIN=<有 license 的那个> 覆盖即可。"
    }
}

# 换算成 WSL 里的 /mnt/<盘符>/... 形式，方便后面直接粘贴到 Ubuntu 终端
function ConvertTo-WslPath ($winPath) {
    try {
        $full = (Resolve-Path -LiteralPath $winPath -ErrorAction Stop).Path
    } catch {
        $full = $winPath
    }
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest  = $Matches[2] -replace '\\', '/'
        return "/mnt/$drive/$rest"
    }
    return $full
}

$wslRepo  = ConvertTo-WslPath $RepoRoot
$wslKit   = ConvertTo-WslPath (Join-Path $RepoRoot 'spinalhdl-setup-kit')
Note "在 WSL 里对应的仓库根： $wslRepo"
Note "在 WSL 里对应的套件目录：$wslKit"

# -----------------------------------------------------------------------------
Hdr "8. 下一步怎么做"
Write-Host @"

    1) 以管理员身份打开 PowerShell，执行：
         wsl --install -d Ubuntu
       然后【重启电脑】。
       （重启后 Ubuntu 会自动启动，要求你设置 Linux 用户名和密码 —— 记牢密码，
        后面所有 sudo 操作都用它。）

    2) 确认默认版本是 WSL2：
         wsl -l -v
         wsl --set-default-version 2

    3) 安装 VS Code，并在 VS Code 里安装扩展：WSL

    4) 确认 Vivado 能打开（只用来跑 xsim，不做综合）。若自动挑选的版本没有 license：
         set VIVADO_BIN=<...>\Vivado\bin\vivado.bat

    5) 打开 Ubuntu 终端，进入套件目录，按章执行：

         第 1 章  环境
           bash scripts/env/01-install-toolchain.sh
           bash scripts/env/02-vscode-extensions.sh

         第 2 章  AXI 总线
           bash scripts/axi/10-create-bus-project.sh
           bash scripts/axi/11-make-bus-verilog.sh
           bash scripts/axi/12-create-sim-project.sh
           bash scripts/axi/13-make-model-verilog.sh

         第 3 章  APB 总线
           bash scripts/apb/20-create-bus-project.sh
           bash scripts/apb/21-make-bus-verilog.sh
           bash scripts/apb/22-create-sim-project.sh
           bash scripts/apb/23-make-model-verilog.sh

         回到 Windows（第 2.5 / 3.5 节）
           windows\axi\14-run-sim.cmd   （加 gui 参数则停在波形窗口）
           windows\apb\24-run-sim.cmd

"@ -ForegroundColor Gray

Write-Host "Windows 前置检查结束。" -ForegroundColor White
