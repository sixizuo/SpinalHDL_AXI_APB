# =============================================================================
#  14-run-sim.tcl —— AXI4 互连的 Vivado 仿真（Windows 侧，全部逻辑都在本文件）
#
#  由 14-run-sim.cmd 调用，也可以手工执行：
#      vivado -mode batch -source 14-run-sim.tcl -tclargs batch
#      vivado -mode gui   -source 14-run-sim.tcl -tclargs gui
#
#  本文件做四件事，全部在 Windows / Vivado 侧完成，WSL 只管生成 Verilog：
#      ① 建仿真工程          vivado-sim/axi/proj/sim_axi.xpr
#      ② 加源文件            总线 RTL + 主/从模型 + 手写 TB（三部分各自独立）
#      ③ 起仿真 + 挂波形     波形分组由同目录的 14-wave.tcl 在 xsim 里执行，
#                            这样 batch 模式也有波形，GUI 模式直接显示在波形窗口
#      ④ 跑完读日志判定      把 ==== PASS ==== / ==== FAIL ==== 翻译成人能读的结论，
#                            打印到 console，并写一份 verdict.txt 给脚本/CI 用
#
#  ---------------------------------------------------------------------------
#  两种模式的区别
#  ---------------------------------------------------------------------------
#      batch : 跑完自动退出，波形存成 .wdb + .wcfg，适合批量回归、交作业
#      gui   : 跑完停在 Vivado 波形窗口，适合看时序、定位问题
#
#  为什么判定不靠退出码：vivado.bat 在各种 shell 里传回码都不可靠
#  （Git Bash 下恒为 127，xsim 在 $finish 后也可能返回 0xC0000409）。
#  所以本脚本只认 simulate.log 里的 PASS/FAIL 标记，并落盘成 verdict.txt。
# =============================================================================

# ---------------------------------------------------------------- 0. 参数与路径
set mode "batch"
if {[llength $argv] >= 1 && [lindex $argv 0] ne ""} { set mode [lindex $argv 0] }

set part "xc7a100tcsg324-1"
if {[llength $argv] >= 2 && [lindex $argv 1] ne ""} { set part [lindex $argv 1] }
if {[info exists ::env(VIVADO_PART)] && $::env(VIVADO_PART) ne ""} { set part $::env(VIVADO_PART) }

set here    [file dirname [file normalize [info script]]]     ;# .../windows/axi
set kitDir  [file normalize [file join $here .. ..]]          ;# .../spinalhdl-setup-kit
set repoDir [file dirname $kitDir]                            ;# 仓库根
set srcDir  [file join $repoDir AXIcrossbar]

set busDir  "axi"
set workDir [file join $kitDir vivado-sim $busDir]
set projDir [file join $workDir proj]
set wcfg    [file join $workDir tb_axi_top.wcfg]
set verdict [file join $workDir verdict.txt]
set waveTcl [file join $here 14-wave.tcl]
set logFile [file join $projDir sim_axi.sim sim_1 behav xsim simulate.log]
set wdbFile [file join $projDir sim_axi.sim sim_1 behav xsim tb_axi_top.wdb]

proc banner {msg} { puts ""; puts "==> $msg" }
proc note   {msg} { puts "    $msg" }
proc die    {msg} { puts ""; puts "\[ERROR\] $msg"; exit 1 }

puts "============================================================"
puts "  AXI4 crossbar - Vivado simulation"
puts "  mode : $mode"
puts "  part : $part"
puts "  src  : $srcDir"
puts "============================================================"

# ---------------------------------------------------------------- 1. 检查源文件
banner "1/5 check source files"
set sources [list \
    [file join $srcDir verilog AxiCrossbar_2x8.v] \
    [file join $srcDir verilog Axi_CDC.v] \
    [file join $srcDir verification models AxiMasterModel.v] \
    [file join $srcDir verification models AxiSlaveModel.v] \
    [file join $srcDir verification tb_axi_top.v] ]

foreach f $sources {
    if {![file exists $f]} {
        die "missing: $f\n        run 11-make-bus-verilog.sh and 13-make-model-verilog.sh in WSL first"
    }
    note "ok  [file tail $f]"
}
if {![file exists $waveTcl]} { die "missing: $waveTcl" }

# ---------------------------------------------------------------- 2. 建工程
banner "2/5 create project"
if {[file exists $projDir]} {
    if {[catch {file delete -force $projDir} err]} {
        die "cannot remove old project: $projDir
        $err
        a previous Vivado is probably still holding it - close it first"
    }
    note "removed old project"
}
file mkdir $projDir
create_project -force sim_axi $projDir -part $part
note "project : [file join $projDir sim_axi.xpr]"
note "part    : $part (project property only, no synthesis/implementation)"

# ---------------------------------------------------------------- 3. 加源文件
banner "3/5 add sources"
add_files -norecurse $sources
set_property top tb_axi_top [get_filesets sources_1]
# launch_simulation 看的是 sim_1 这个 fileset 的 top，必须一起设，
# 否则报 "Top module not set for fileset sim_1"
set_property top tb_axi_top [get_filesets sim_1]
note "top     : tb_axi_top"
foreach f [get_files -of_objects [get_filesets sources_1]] {
    note "  + [file tail $f]"
}

# ---------------------------------------------------------------- 4. 仿真设置
banner "4/5 configure simulation"
set fs [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects $fs
# 把波形脚本登记成 xsim 的启动脚本：
#   batch 模式下 Vivado 没有波形窗口，add_wave 会报 Wavedata 42-443；
#   交给 xsim 自己在仿真进程里执行，两种模式都能录到波形。
set_property -name {xsim.simulate.custom_tcl} -value $waveTcl -objects $fs
note "runtime : all"
note "waves   : [file tail $waveTcl]"

# ---------------------------------------------------------------- 5. 跑仿真
banner "5/5 launch and run"
# 2025.2 里 launch_simulation 的 -mode 指 behavioral / post-synth / post-impl，
# 不是 gui / batch。带 -mode batch 会报 Invalid simulation mode。
# 界面由外层 vivado -mode 决定，这里一律不带参数。
launch_simulation
run all

# ---------------------------------------------------------------- 判定
set verdictTxt "NO-VERDICT"
set hitLine ""
if {[file exists $logFile]} {
    set fh [open $logFile r]
    set txt [read $fh]
    close $fh
    foreach line [split $txt "\n"] {
        if {[string first "==== PASS" $line] >= 0 || [string first "==== FAIL" $line] >= 0} {
            set hitLine [string trim $line]
        }
    }
    if {[string first "==== PASS" $txt] >= 0} {
        set verdictTxt "PASS"
    } elseif {[string first "==== FAIL" $txt] >= 0} {
        set verdictTxt "FAIL"
    }
}

# verdict.txt：给 .cmd / CI / 老师批改用
if {[file exists $workDir]} {
    set fh [open $verdict w]
    puts $fh $verdictTxt
    close $fh
}

puts ""
puts "============================================================"
puts "  RESULT"
puts "------------------------------------------------------------"
puts "  verdict : $verdictTxt"
if {$hitLine ne ""} { puts "  detail  : $hitLine" }
puts "  log     : $logFile"
if {[file exists $wdbFile]} { puts "  wave    : $wdbFile" }
if {[file exists $wcfg]}    { puts "  wcfg    : $wcfg" }
puts "------------------------------------------------------------"
if {$verdictTxt eq "PASS"} {
    puts "  PASS - 2 masters x 8 rounds x 4 beats read back identical."
    puts "         Open the waveform and check that both masters interleave"
    puts "         on axiIn_0/axiIn_1 and that axiOut_x points to the right slave."
} elseif {$verdictTxt eq "FAIL"} {
    puts "  FAIL - see the ==== FAIL ==== line above."
    puts "         Check io_axi_r_payload_data at each master, then the routing"
    puts "         on the crossbar outputs (axiOut_0 .. axiOut_7)."
} else {
    puts "  NO VERDICT - simulate.log has neither PASS nor FAIL."
    puts "               The simulation probably did not finish: check for a"
    puts "               stuck handshake or an elaboration error above."
}
puts "============================================================"

if {$mode eq "gui"} {
    puts ""
    puts "  Waveform window is ready. Close Vivado when you are done."
} else {
    catch {close_sim -quiet}
    catch {close_project}
    exit [expr {$verdictTxt eq "PASS" ? 0 : 1}]
}
