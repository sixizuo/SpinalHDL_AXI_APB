﻿# =============================================================================
#  00-windows-preflight.ps1
#  在【裸 Windows 11】上检查是否具备安装 WSL2 + VS Code + SpinalHDL 开发环境的条件
#
#  用法（在 Windows 上操作）：
#     1) 开始菜单搜索 PowerShell -> 右键「以管理员身份运行」
#     2) 进入本文件所在目录后执行（不要写死盘符，路径按你实际解压位置来）：
#          Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#          cd "<解压位置>\spinalhdl-setup-kit\windows"
#          .\00-windows-preflight.ps1
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
# 路径全部相对推导：本文件在 <仓库根>\spinalhdl-setup-kit\windows\ 下
# -----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $kitDir   = Split-Path -Parent $PSScriptRoot          # ...\spinalhdl-setup-kit
    $RepoRoot = Split-Path -Parent $kitDir                # ...\(仓库根)
}
$ScriptsDir = Join-Path $PSScriptRoot '..\scripts'
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
if (Test-Path (Join-Path $ScriptsDir '01-install-toolchain.sh')) {
    Ok "WSL 侧脚本存在：$ScriptsDir"
} else {
    Warn "在 $ScriptsDir 下找不到 01-install-toolchain.sh"
}

$needAxi = @('Axicrossbar.scala', 'fifo.scala', 'Config.scala')
$needApb = @('Apbcrossbar.scala', 'ApbSim.scala', 'Config.scala')

if (Test-Path $SrcAxi) {
    $miss = @($needAxi | Where-Object { -not (Test-Path (Join-Path $SrcAxi $_)) })
    if ($miss.Count -eq 0) { Ok "AXI 源码目录齐全：$SrcAxi  （$($needAxi -join ', ')）" }
    else { Bad "AXI 源码目录 $SrcAxi 缺少：$($miss -join ', ')" }
} else {
    Bad "找不到 AXI 源码目录：$SrcAxi"
}

if (Test-Path $SrcApb) {
    $miss = @($needApb | Where-Object { -not (Test-Path (Join-Path $SrcApb $_)) })
    if ($miss.Count -eq 0) { Ok "APB 源码目录齐全：$SrcApb  （$($needApb -join ', ')）" }
    else { Bad "APB 源码目录 $SrcApb 缺少：$($miss -join ', ')" }
} else {
    Bad "找不到 APB 源码目录：$SrcApb"
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
Hdr "7. 下一步怎么做"
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

    4) 把整套文件（含 AXIcrossbar、apb、spinalhdl-setup-kit 三个目录）放在
       Windows 上任意好记的位置即可 —— 下面的脚本都不写死盘符，
       全部按「脚本自己所在的位置」推导路径，放在哪都能跑。

    5) 打开 Ubuntu 终端，进入 WSL 里的套件目录，然后依次执行：
         cd "$wslKit"
         bash scripts/01-install-toolchain.sh
         bash scripts/02-create-project.sh
         bash scripts/03-import-source.sh
         bash scripts/04-doctor.sh
         bash scripts/05-make-verilog.sh
         bash scripts/06-vscode-extensions.sh

    6) 02/03 会在 WSL 里建两个互不相干的工程（这也是脚本要求的）：
         AXI  ->  ~/spinalhdl-projects/AXIcrossbar
         APB  ->  ~/spinalhdl-projects/apb

"@ -ForegroundColor Gray

Write-Host "Windows 前置检查结束。" -ForegroundColor White
