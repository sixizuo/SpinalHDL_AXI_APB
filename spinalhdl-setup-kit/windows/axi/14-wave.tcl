# =============================================================================
#  14-wave.tcl —— AXI 仿真的波形分组（在 xsim 进程里执行，不是 Vivado 里）
#
#  为什么波形放在这个文件、而不是写在 14-run-sim.tcl 里：
#      vivado -mode batch 下没有波形窗口，add_wave 会报
#          ERROR: [Wavedata 42-443] ...
#  把这份脚本登记成 sim_1 的 xsim.simulate.custom_tcl 之后，它会在仿真进程
#  启动时执行 —— 两种模式都能录到波形：
#      batch : 波形写进 tb_axi_top.wdb，分组存进 tb_axi_top.wcfg
#      gui   : 同时显示在 Vivado 的波形窗口里
#
#  ---------------------------------------------------------------------------
#  两个必须知道的 xsim 细节（本文件就是按它们写的）
#  ---------------------------------------------------------------------------
#   1) 精确名字照样要写全 —— 模型实例的端口是 io_axi_aw_valid（有下划线、
#      payload 段单独一层），不是互连那边的 axiIn_0_awvalid。
#      写错名字 get_objects 返回 0 个，波形里就空一块。
#   2) 路径末尾的 * 会跨层 —— /u_dut/axiIn_0_* 除了 35 个端口，还会抓到
#      子层次里同名前缀的信号（实测 281 个）。所以互连的入/出口都写成
#      显式清单，一个端口一根一根列。
#
#  分组按「看波形的思路」切：
#      结果灯 → 两个主设备的握手 → 互连入口 → 互连出口（路由）→ 从设备
# =============================================================================

set here   [file dirname [file normalize [info script]]]
set kitDir [file normalize [file join $here .. ..]]
set wcfg   [file join $kitDir vivado-sim axi tb_axi_top.wcfg]

# ---- 互连的扁平端口名（Axi4SpecRenamer 之后就是这种风格，没有 payload 段）----
set AXI_FLAT {
    awvalid awready awaddr awid awlen awsize awburst awlock awcache awprot
    wvalid wready wdata wstrb wlast
    bvalid bready bid bresp
    arvalid arready araddr arid arlen arsize arburst arlock arcache arprot
    rvalid rready rdata rid rresp rlast
}

# ---- 模型实例的端口名（SpinalHDL 自动加的 io_ 前缀 + payload 分段）----
set AXI_MODEL {
    io_axi_aw_valid io_axi_aw_ready io_axi_aw_payload_addr io_axi_aw_payload_id
    io_axi_aw_payload_len io_axi_aw_payload_size io_axi_aw_payload_burst
    io_axi_aw_payload_lock io_axi_aw_payload_cache io_axi_aw_payload_prot
    io_axi_w_valid io_axi_w_ready io_axi_w_payload_data io_axi_w_payload_strb
    io_axi_w_payload_last
    io_axi_b_valid io_axi_b_ready io_axi_b_payload_id io_axi_b_payload_resp
    io_axi_ar_valid io_axi_ar_ready io_axi_ar_payload_addr io_axi_ar_payload_id
    io_axi_ar_payload_len io_axi_ar_payload_size io_axi_ar_payload_burst
    io_axi_ar_payload_lock io_axi_ar_payload_cache io_axi_ar_payload_prot
    io_axi_r_valid io_axi_r_ready io_axi_r_payload_data io_axi_r_payload_id
    io_axi_r_payload_resp io_axi_r_payload_last
}

# 把一批「精确路径」加进一个分组；一个都抓不到就照样建组，不中断流程
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

# ---- 00 结果：先看这几个就知道过没过 ----
set total [expr {$total + [wg 00_clock_and_result [list \
    /tb_axi_top/clk /tb_axi_top/reset_n \
    /tb_axi_top/m0_done /tb_axi_top/m0_error \
    /tb_axi_top/m1_done /tb_axi_top/m1_error]]}]

# ---- 01/02 两个主设备的 AXI 从口（发请求、收响应）----
foreach m {0 1} {
    set paths {}
    foreach s $AXI_MODEL { lappend paths /tb_axi_top/u_m${m}/$s }
    set total [expr {$total + [wg 0[expr {$m + 1}]_master${m}_bus $paths]}]
}

# ---- 03/04 互连入口：主设备看到的请求，ID 还是 4 位 ----
foreach i {0 1} {
    set paths {}
    foreach s $AXI_FLAT { lappend paths /tb_axi_top/u_dut/axiIn_${i}_${s} }
    set total [expr {$total + [wg 0[expr {$i + 3}]_crossbar_in${i} $paths]}]
}

# ---- 05 互连出口：路由结果（ID 已经变成 5 位，最高位是主设备序号）----
set paths {}
foreach s {0 1 2 3 4 5 6 7} {
    foreach sig {awvalid awaddr wvalid wlast bvalid arvalid araddr rvalid rlast} {
        lappend paths /tb_axi_top/u_dut/axiOut_${s}_${sig}
    }
}
set total [expr {$total + [wg 05_crossbar_out $paths]}]

# ---- 06 从设备 0 的全套握手（定位「读回错位」这类问题看这里）----
set paths {}
foreach s $AXI_MODEL { lappend paths /tb_axi_top/u_s0/$s }
set total [expr {$total + [wg 06_slave0_bus $paths]}]

# ---- 07 其余 7 个从设备只看关键几根，否则波形窗口会很卡 ----
set paths {}
foreach s {1 2 3 4 5 6 7} {
    foreach sig {io_axi_aw_valid io_axi_aw_payload_addr io_axi_w_valid \
                 io_axi_w_payload_last io_axi_b_valid io_axi_r_valid \
                 io_axi_r_payload_data} {
        lappend paths /tb_axi_top/u_s${s}/$sig
    }
}
set total [expr {$total + [wg 07_slaves_1_to_7 $paths]}]

puts "\[wave\] total $total signals"

if {[catch {save_wave_config $wcfg} err]} {
    puts "\[wave\] WARNING: cannot save $wcfg : $err"
} else {
    puts "\[wave\] saved $wcfg"
}
