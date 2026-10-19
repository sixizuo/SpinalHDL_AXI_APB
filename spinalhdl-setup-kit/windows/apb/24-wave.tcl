# =============================================================================
#  24-wave.tcl —— APB 仿真的波形分组（在 xsim 进程里执行）
#
#  APB 只有 8 根信号，分组比 AXI 简单；但 xsim 的两个坑一样要遵守：
#    · 精确名字要写全（模型端口是 io_apb_PADDR 这种大写风格）
#    · 路径末尾的 * 会跨层，所以互连的入/出口写成显式清单
#
#  分组：结果灯 → 两个主设备的 APB 口 → 互连入口 → 互连出口（PSEL 路由）→ 从设备
# =============================================================================

set here   [file dirname [file normalize [info script]]]
set kitDir [file normalize [file join $here .. ..]]
set wcfg   [file join $kitDir vivado-sim apb tb_apb_top.wcfg]

set APB_SIGS {PADDR PSEL PENABLE PREADY PWRITE PWDATA PRDATA PSLVERROR}

proc wg {name paths} {
    if {[catch {add_wave_group $name} err]} {
        puts "\[wave\] group $name already exists, reuse it"
    }
    set n 0
    foreach p $paths {
        set obj [get_objects -quiet $p]
        if {[llength $obj] > 0} {
            add_wave -into $name $obj
            incr n
        } else {
            puts "\[wave\]   WARNING: not found: $p"
        }
    }
    puts [format "\[wave\] %-24s %4d signals" $name $n]
    return $n
}

set total 0

set total [expr {$total + [wg 00_clock_and_result [list \
    /tb_apb_top/clk /tb_apb_top/reset_n \
    /tb_apb_top/m0_done /tb_apb_top/m0_error \
    /tb_apb_top/m1_done /tb_apb_top/m1_error]]}]

foreach m {0 1} {
    set paths {}
    foreach s $APB_SIGS { lappend paths /tb_apb_top/u_m${m}/io_apb_${s} }
    set total [expr {$total + [wg 0[expr {$m + 1}]_master${m}_apb $paths]}]
}

foreach i {0 1} {
    set paths {}
    foreach s $APB_SIGS { lappend paths /tb_apb_top/u_dut/apbIn_${i}_${s} }
    set total [expr {$total + [wg 0[expr {$i + 3}]_crossbar_in${i} $paths]}]
}

set paths {}
foreach s {0 1 2 3 4 5 6 7} {
    foreach sig $APB_SIGS { lappend paths /tb_apb_top/u_dut/apbOut_${s}_${sig} }
}
set total [expr {$total + [wg 05_crossbar_out $paths]}]

set paths {}
foreach s $APB_SIGS { lappend paths /tb_apb_top/u_s0/io_apb_${s} }
set total [expr {$total + [wg 06_slave0_apb $paths]}]

set paths {}
foreach s {1 2 3 4 5 6 7} {
    foreach sig {PSEL PADDR PENABLE PWRITE PWDATA PRDATA PREADY} {
        lappend paths /tb_apb_top/u_s${s}/io_apb_${sig}
    }
}
set total [expr {$total + [wg 07_slaves_1_to_7 $paths]}]

puts "\[wave\] total $total signals"

if {[catch {save_wave_config $wcfg} err]} {
    puts "\[wave\] WARNING: cannot save $wcfg : $err"
} else {
    puts "\[wave\] saved $wcfg"
}
