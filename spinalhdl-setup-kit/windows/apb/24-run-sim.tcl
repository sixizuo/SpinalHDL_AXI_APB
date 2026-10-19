# =============================================================================
#  24-run-sim.tcl —— APB3 互连的 Vivado 仿真（Windows 侧，全部逻辑都在本文件）
#
#  与 14-run-sim.tcl 完全同构，只是换了总线与文件清单：
#      ① 建仿真工程          vivado-sim/apb/proj/sim_apb.xpr
#      ② 加源文件            Apb3Crossbar_2x8.v + ApbMasterModel.v/ApbSlaveModel.v
#                            + 手写 tb_apb_top.v
#      ③ 起仿真 + 挂波形     波形分组由 24-wave.tcl 在 xsim 里执行
#      ④ 跑完读日志判定      打印结论到 console，并写 verdict.txt
#
#  用法：
#      vivado -mode batch -source 24-run-sim.tcl -tclargs batch
#      vivado -mode gui   -source 24-run-sim.tcl -tclargs gui
#  或者直接双击 24-run-sim.cmd（默认 batch，加 gui 参数进波形窗口）。
# =============================================================================

# ---------------------------------------------------------------- 0. 参数与路径
set mode "batch"
if {[llength $argv] >= 1 && [lindex $argv 0] ne ""} { set mode [lindex $argv 0] }

set part "xc7a100tcsg324-1"
if {[llength $argv] >= 2 && [lindex $argv 1] ne ""} { set part [lindex $argv 1] }
if {[info exists ::env(VIVADO_PART)] && $::env(VIVADO_PART) ne ""} { set part $::env(VIVADO_PART) }

set here    [file dirname [file normalize [info script]]]     ;# .../windows/apb
set kitDir  [file normalize [file join $here .. ..]]
set repoDir [file dirname $kitDir]
set srcDir  [file join $repoDir apb]

set busDir  "apb"
set workDir [file join $kitDir vivado-sim $busDir]
set projDir [file join $workDir proj]
set wcfg    [file join $workDir tb_apb_top.wcfg]
set verdict [file join $workDir verdict.txt]
set waveTcl [file join $here 24-wave.tcl]
set logFile [file join $projDir sim_apb.sim sim_1 behav xsim simulate.log]
set wdbFile [file join $projDir sim_apb.sim sim_1 behav xsim tb_apb_top.wdb]

proc banner {msg} { puts ""; puts "==> $msg" }
proc note   {msg} { puts "    $msg" }
proc die    {msg} { puts ""; puts "\[ERROR\] $msg"; exit 1 }

puts "============================================================"
puts "  APB3 crossbar - Vivado simulation"
puts "  mode : $mode"
puts "  part : $part"
puts "  src  : $srcDir"
puts "============================================================"

# ---------------------------------------------------------------- 1. 检查源文件
banner "1/5 check source files"
set sources [list \
    [file join $srcDir verilog Apb3Crossbar_2x8.v] \
    [file join $srcDir verification models ApbMasterModel.v] \
    [file join $srcDir verification models ApbSlaveModel.v] \
    [file join $srcDir verification tb_apb_top.v] ]

foreach f $sources {
    if {![file exists $f]} {
        die "missing: $f\n        run 21-make-bus-verilog.sh and 23-make-model-verilog.sh in WSL first"
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
create_project -force sim_apb $projDir -part $part
note "project : [file join $projDir sim_apb.xpr]"
note "part    : $part (project property only, no synthesis/implementation)"

# ---------------------------------------------------------------- 3. 加源文件
banner "3/5 add sources"
add_files -norecurse $sources
set_property top tb_apb_top [get_filesets sources_1]
# launch_simulation 看的是 sim_1 这个 fileset 的 top，必须一起设，
# 否则报 "Top module not set for fileset sim_1"
set_property top tb_apb_top [get_filesets sim_1]
note "top     : tb_apb_top"
foreach f [get_files -of_objects [get_filesets sources_1]] {
    note "  + [file tail $f]"
}

# ---------------------------------------------------------------- 4. 仿真设置
banner "4/5 configure simulation"
set fs [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects $fs
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
    puts "  PASS - 2 masters x 4 rounds x 8 words read back identical."
    puts "         Open the waveform and check that PSEL rotates between"
    puts "         apbOut_0 and apbOut_4 (two masters really interleave)."
} elseif {$verdictTxt eq "FAIL"} {
    puts "  FAIL - see the ==== FAIL ==== line above."
    puts "         Check io_apb_PRDATA at each master, then PSEL/PADDR on"
    puts "         the crossbar outputs (apbOut_0 .. apbOut_7)."
} else {
    puts "  NO VERDICT - simulate.log has neither PASS nor FAIL."
    puts "               The simulation probably did not finish: check for a"
    puts "               stuck PREADY or an elaboration error above."
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
