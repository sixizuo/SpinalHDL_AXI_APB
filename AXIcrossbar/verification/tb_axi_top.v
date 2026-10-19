// =============================================================================
//  tb_axi_top.v —— AXI4 互连的仿真顶层（手写 Verilog）
//
//  这个文件里只有「连线 + 时钟复位 + 判定」，没有任何总线或模型的实现：
//      u_dut     : AxiCrossbar_2x8   ← verilog/AxiCrossbar_2x8.v（生成物）
//      u_m0/u_m1 : AxiMasterModel    ← verification/models/AxiMasterModel.v（生成物）
//      u_s0..u_s7: AxiSlaveModel     ← verification/models/AxiSlaveModel.v（生成物）
//
//  ---------------------------------------------------------------------------
//  想改激励，改下面的 io_base / io_stride / io_seed / io_id 四个常量即可：
//      io_base    起始字节地址（必须落在 8 个从设备窗口之一里，见 AXIcrossbar.scala）
//      io_stride  每轮地址跨度（要 >= beats*4，否则相邻两轮会重叠）
//      io_seed    数据种子（第 r 轮第 b 拍写 seed + r*0x100 + b）
//      io_id      该主设备用的 AXI ID
//  ---------------------------------------------------------------------------
//  判定：两个主设备都 done 且都没有 error → 打印 ==== PASS ==== 并 $finish
//        任一 error 或超时               → 打印 ==== FAIL ==== 并 $finish
//        Vivado 侧的 Tcl 就是靠这两个标记判定的（见 windows/axi/14-run-sim.tcl）
// =============================================================================

`timescale 1ns / 1ps

module tb_axi_top;

  // ---------------------------------------------------------------- 时钟与复位
  // 10 ns 周期 = 100 MHz；与 Config.scala 里的 resetActiveLevel = LOW 对应
  reg clk = 0;
  always #5 clk = ~clk;

  reg reset_n = 0;
  initial begin
    reset_n = 0;
    repeat (20) @(posedge clk);   // 保持 20 拍复位
    reset_n = 1;
  end

  // ---------------------------------------------------------------- 结果信号
  wire m0_done, m0_error;
  wire m1_done, m1_error;

  // ================================================================ 主设备 0
  // base=0x1C000000  stride=0x1000  seed=0x11000000  id=3
  wire          m0_awvalid;
  wire          m0_awready;
  wire [31:0]   m0_awaddr;
  wire [3:0]    m0_awid;
  wire [7:0]    m0_awlen;
  wire [2:0]    m0_awsize;
  wire [1:0]    m0_awburst;
  wire          m0_awlock;
  wire [3:0]    m0_awcache;
  wire [2:0]    m0_awprot;
  wire          m0_wvalid;
  wire          m0_wready;
  wire [31:0]   m0_wdata;
  wire [3:0]    m0_wstrb;
  wire          m0_wlast;
  wire          m0_bvalid;
  wire          m0_bready;
  wire [3:0]    m0_bid;
  wire [1:0]    m0_bresp;
  wire          m0_arvalid;
  wire          m0_arready;
  wire [31:0]   m0_araddr;
  wire [3:0]    m0_arid;
  wire [7:0]    m0_arlen;
  wire [2:0]    m0_arsize;
  wire [1:0]    m0_arburst;
  wire          m0_arlock;
  wire [3:0]    m0_arcache;
  wire [2:0]    m0_arprot;
  wire          m0_rvalid;
  wire          m0_rready;
  wire [31:0]   m0_rdata;
  wire [3:0]    m0_rid;
  wire [1:0]    m0_rresp;
  wire          m0_rlast;

  AxiMasterModel u_m0 (
    .clk       (clk),
    .resetn    (reset_n),
    .io_base   (32'h1C00_0000),
    .io_stride (32'h0000_1000),
    .io_seed   (32'h1100_0000),
    .io_id     (4'd3),
    .io_busy   (),
    .io_error  (m0_error),
    .io_done   (m0_done),
    .io_axi_aw_valid          (m0_awvalid),
    .io_axi_aw_ready          (m0_awready),
    .io_axi_aw_payload_addr   (m0_awaddr),
    .io_axi_aw_payload_id     (m0_awid),
    .io_axi_aw_payload_len    (m0_awlen),
    .io_axi_aw_payload_size   (m0_awsize),
    .io_axi_aw_payload_burst  (m0_awburst),
    .io_axi_aw_payload_lock   (m0_awlock),
    .io_axi_aw_payload_cache  (m0_awcache),
    .io_axi_aw_payload_prot   (m0_awprot),

    .io_axi_w_valid           (m0_wvalid),
    .io_axi_w_ready           (m0_wready),
    .io_axi_w_payload_data    (m0_wdata),
    .io_axi_w_payload_strb    (m0_wstrb),
    .io_axi_w_payload_last    (m0_wlast),

    .io_axi_b_valid           (m0_bvalid),
    .io_axi_b_ready           (m0_bready),
    .io_axi_b_payload_id      (m0_bid),
    .io_axi_b_payload_resp    (m0_bresp),

    .io_axi_ar_valid          (m0_arvalid),
    .io_axi_ar_ready          (m0_arready),
    .io_axi_ar_payload_addr   (m0_araddr),
    .io_axi_ar_payload_id     (m0_arid),
    .io_axi_ar_payload_len    (m0_arlen),
    .io_axi_ar_payload_size   (m0_arsize),
    .io_axi_ar_payload_burst  (m0_arburst),
    .io_axi_ar_payload_lock   (m0_arlock),
    .io_axi_ar_payload_cache  (m0_arcache),
    .io_axi_ar_payload_prot   (m0_arprot),

    .io_axi_r_valid           (m0_rvalid),
    .io_axi_r_ready           (m0_rready),
    .io_axi_r_payload_data    (m0_rdata),
    .io_axi_r_payload_id      (m0_rid),
    .io_axi_r_payload_resp    (m0_rresp),
    .io_axi_r_payload_last    (m0_rlast)
  );

  // ================================================================ 主设备 1
  // base=0x1C010000  stride=0x1000  seed=0x22000000  id=7
  wire          m1_awvalid;
  wire          m1_awready;
  wire [31:0]   m1_awaddr;
  wire [3:0]    m1_awid;
  wire [7:0]    m1_awlen;
  wire [2:0]    m1_awsize;
  wire [1:0]    m1_awburst;
  wire          m1_awlock;
  wire [3:0]    m1_awcache;
  wire [2:0]    m1_awprot;
  wire          m1_wvalid;
  wire          m1_wready;
  wire [31:0]   m1_wdata;
  wire [3:0]    m1_wstrb;
  wire          m1_wlast;
  wire          m1_bvalid;
  wire          m1_bready;
  wire [3:0]    m1_bid;
  wire [1:0]    m1_bresp;
  wire          m1_arvalid;
  wire          m1_arready;
  wire [31:0]   m1_araddr;
  wire [3:0]    m1_arid;
  wire [7:0]    m1_arlen;
  wire [2:0]    m1_arsize;
  wire [1:0]    m1_arburst;
  wire          m1_arlock;
  wire [3:0]    m1_arcache;
  wire [2:0]    m1_arprot;
  wire          m1_rvalid;
  wire          m1_rready;
  wire [31:0]   m1_rdata;
  wire [3:0]    m1_rid;
  wire [1:0]    m1_rresp;
  wire          m1_rlast;

  AxiMasterModel u_m1 (
    .clk       (clk),
    .resetn    (reset_n),
    .io_base   (32'h1C01_0000),
    .io_stride (32'h0000_1000),
    .io_seed   (32'h2200_0000),
    .io_id     (4'd7),
    .io_busy   (),
    .io_error  (m1_error),
    .io_done   (m1_done),
    .io_axi_aw_valid          (m1_awvalid),
    .io_axi_aw_ready          (m1_awready),
    .io_axi_aw_payload_addr   (m1_awaddr),
    .io_axi_aw_payload_id     (m1_awid),
    .io_axi_aw_payload_len    (m1_awlen),
    .io_axi_aw_payload_size   (m1_awsize),
    .io_axi_aw_payload_burst  (m1_awburst),
    .io_axi_aw_payload_lock   (m1_awlock),
    .io_axi_aw_payload_cache  (m1_awcache),
    .io_axi_aw_payload_prot   (m1_awprot),

    .io_axi_w_valid           (m1_wvalid),
    .io_axi_w_ready           (m1_wready),
    .io_axi_w_payload_data    (m1_wdata),
    .io_axi_w_payload_strb    (m1_wstrb),
    .io_axi_w_payload_last    (m1_wlast),

    .io_axi_b_valid           (m1_bvalid),
    .io_axi_b_ready           (m1_bready),
    .io_axi_b_payload_id      (m1_bid),
    .io_axi_b_payload_resp    (m1_bresp),

    .io_axi_ar_valid          (m1_arvalid),
    .io_axi_ar_ready          (m1_arready),
    .io_axi_ar_payload_addr   (m1_araddr),
    .io_axi_ar_payload_id     (m1_arid),
    .io_axi_ar_payload_len    (m1_arlen),
    .io_axi_ar_payload_size   (m1_arsize),
    .io_axi_ar_payload_burst  (m1_arburst),
    .io_axi_ar_payload_lock   (m1_arlock),
    .io_axi_ar_payload_cache  (m1_arcache),
    .io_axi_ar_payload_prot   (m1_arprot),

    .io_axi_r_valid           (m1_rvalid),
    .io_axi_r_ready           (m1_rready),
    .io_axi_r_payload_data    (m1_rdata),
    .io_axi_r_payload_id      (m1_rid),
    .io_axi_r_payload_resp    (m1_rresp),
    .io_axi_r_payload_last    (m1_rlast)
  );

  // ================================================================ 从设备 0
  wire          s0_awvalid;
  wire          s0_awready;
  wire [31:0]   s0_awaddr;
  wire [4:0]    s0_awid;
  wire [7:0]    s0_awlen;
  wire [2:0]    s0_awsize;
  wire [1:0]    s0_awburst;
  wire          s0_awlock;
  wire [3:0]    s0_awcache;
  wire [2:0]    s0_awprot;
  wire          s0_wvalid;
  wire          s0_wready;
  wire [31:0]   s0_wdata;
  wire [3:0]    s0_wstrb;
  wire          s0_wlast;
  wire          s0_bvalid;
  wire          s0_bready;
  wire [4:0]    s0_bid;
  wire [1:0]    s0_bresp;
  wire          s0_arvalid;
  wire          s0_arready;
  wire [31:0]   s0_araddr;
  wire [4:0]    s0_arid;
  wire [7:0]    s0_arlen;
  wire [2:0]    s0_arsize;
  wire [1:0]    s0_arburst;
  wire          s0_arlock;
  wire [3:0]    s0_arcache;
  wire [2:0]    s0_arprot;
  wire          s0_rvalid;
  wire          s0_rready;
  wire [31:0]   s0_rdata;
  wire [4:0]    s0_rid;
  wire [1:0]    s0_rresp;
  wire          s0_rlast;

  AxiSlaveModel u_s0 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s0_awvalid),
    .io_axi_aw_ready          (s0_awready),
    .io_axi_aw_payload_addr   (s0_awaddr),
    .io_axi_aw_payload_id     (s0_awid),
    .io_axi_aw_payload_len    (s0_awlen),
    .io_axi_aw_payload_size   (s0_awsize),
    .io_axi_aw_payload_burst  (s0_awburst),
    .io_axi_aw_payload_lock   (s0_awlock),
    .io_axi_aw_payload_cache  (s0_awcache),
    .io_axi_aw_payload_prot   (s0_awprot),

    .io_axi_w_valid           (s0_wvalid),
    .io_axi_w_ready           (s0_wready),
    .io_axi_w_payload_data    (s0_wdata),
    .io_axi_w_payload_strb    (s0_wstrb),
    .io_axi_w_payload_last    (s0_wlast),

    .io_axi_b_valid           (s0_bvalid),
    .io_axi_b_ready           (s0_bready),
    .io_axi_b_payload_id      (s0_bid),
    .io_axi_b_payload_resp    (s0_bresp),

    .io_axi_ar_valid          (s0_arvalid),
    .io_axi_ar_ready          (s0_arready),
    .io_axi_ar_payload_addr   (s0_araddr),
    .io_axi_ar_payload_id     (s0_arid),
    .io_axi_ar_payload_len    (s0_arlen),
    .io_axi_ar_payload_size   (s0_arsize),
    .io_axi_ar_payload_burst  (s0_arburst),
    .io_axi_ar_payload_lock   (s0_arlock),
    .io_axi_ar_payload_cache  (s0_arcache),
    .io_axi_ar_payload_prot   (s0_arprot),

    .io_axi_r_valid           (s0_rvalid),
    .io_axi_r_ready           (s0_rready),
    .io_axi_r_payload_data    (s0_rdata),
    .io_axi_r_payload_id      (s0_rid),
    .io_axi_r_payload_resp    (s0_rresp),
    .io_axi_r_payload_last    (s0_rlast)
  );

  // ================================================================ 从设备 1
  wire          s1_awvalid;
  wire          s1_awready;
  wire [31:0]   s1_awaddr;
  wire [4:0]    s1_awid;
  wire [7:0]    s1_awlen;
  wire [2:0]    s1_awsize;
  wire [1:0]    s1_awburst;
  wire          s1_awlock;
  wire [3:0]    s1_awcache;
  wire [2:0]    s1_awprot;
  wire          s1_wvalid;
  wire          s1_wready;
  wire [31:0]   s1_wdata;
  wire [3:0]    s1_wstrb;
  wire          s1_wlast;
  wire          s1_bvalid;
  wire          s1_bready;
  wire [4:0]    s1_bid;
  wire [1:0]    s1_bresp;
  wire          s1_arvalid;
  wire          s1_arready;
  wire [31:0]   s1_araddr;
  wire [4:0]    s1_arid;
  wire [7:0]    s1_arlen;
  wire [2:0]    s1_arsize;
  wire [1:0]    s1_arburst;
  wire          s1_arlock;
  wire [3:0]    s1_arcache;
  wire [2:0]    s1_arprot;
  wire          s1_rvalid;
  wire          s1_rready;
  wire [31:0]   s1_rdata;
  wire [4:0]    s1_rid;
  wire [1:0]    s1_rresp;
  wire          s1_rlast;

  AxiSlaveModel u_s1 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s1_awvalid),
    .io_axi_aw_ready          (s1_awready),
    .io_axi_aw_payload_addr   (s1_awaddr),
    .io_axi_aw_payload_id     (s1_awid),
    .io_axi_aw_payload_len    (s1_awlen),
    .io_axi_aw_payload_size   (s1_awsize),
    .io_axi_aw_payload_burst  (s1_awburst),
    .io_axi_aw_payload_lock   (s1_awlock),
    .io_axi_aw_payload_cache  (s1_awcache),
    .io_axi_aw_payload_prot   (s1_awprot),

    .io_axi_w_valid           (s1_wvalid),
    .io_axi_w_ready           (s1_wready),
    .io_axi_w_payload_data    (s1_wdata),
    .io_axi_w_payload_strb    (s1_wstrb),
    .io_axi_w_payload_last    (s1_wlast),

    .io_axi_b_valid           (s1_bvalid),
    .io_axi_b_ready           (s1_bready),
    .io_axi_b_payload_id      (s1_bid),
    .io_axi_b_payload_resp    (s1_bresp),

    .io_axi_ar_valid          (s1_arvalid),
    .io_axi_ar_ready          (s1_arready),
    .io_axi_ar_payload_addr   (s1_araddr),
    .io_axi_ar_payload_id     (s1_arid),
    .io_axi_ar_payload_len    (s1_arlen),
    .io_axi_ar_payload_size   (s1_arsize),
    .io_axi_ar_payload_burst  (s1_arburst),
    .io_axi_ar_payload_lock   (s1_arlock),
    .io_axi_ar_payload_cache  (s1_arcache),
    .io_axi_ar_payload_prot   (s1_arprot),

    .io_axi_r_valid           (s1_rvalid),
    .io_axi_r_ready           (s1_rready),
    .io_axi_r_payload_data    (s1_rdata),
    .io_axi_r_payload_id      (s1_rid),
    .io_axi_r_payload_resp    (s1_rresp),
    .io_axi_r_payload_last    (s1_rlast)
  );

  // ================================================================ 从设备 2
  wire          s2_awvalid;
  wire          s2_awready;
  wire [31:0]   s2_awaddr;
  wire [4:0]    s2_awid;
  wire [7:0]    s2_awlen;
  wire [2:0]    s2_awsize;
  wire [1:0]    s2_awburst;
  wire          s2_awlock;
  wire [3:0]    s2_awcache;
  wire [2:0]    s2_awprot;
  wire          s2_wvalid;
  wire          s2_wready;
  wire [31:0]   s2_wdata;
  wire [3:0]    s2_wstrb;
  wire          s2_wlast;
  wire          s2_bvalid;
  wire          s2_bready;
  wire [4:0]    s2_bid;
  wire [1:0]    s2_bresp;
  wire          s2_arvalid;
  wire          s2_arready;
  wire [31:0]   s2_araddr;
  wire [4:0]    s2_arid;
  wire [7:0]    s2_arlen;
  wire [2:0]    s2_arsize;
  wire [1:0]    s2_arburst;
  wire          s2_arlock;
  wire [3:0]    s2_arcache;
  wire [2:0]    s2_arprot;
  wire          s2_rvalid;
  wire          s2_rready;
  wire [31:0]   s2_rdata;
  wire [4:0]    s2_rid;
  wire [1:0]    s2_rresp;
  wire          s2_rlast;

  AxiSlaveModel u_s2 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s2_awvalid),
    .io_axi_aw_ready          (s2_awready),
    .io_axi_aw_payload_addr   (s2_awaddr),
    .io_axi_aw_payload_id     (s2_awid),
    .io_axi_aw_payload_len    (s2_awlen),
    .io_axi_aw_payload_size   (s2_awsize),
    .io_axi_aw_payload_burst  (s2_awburst),
    .io_axi_aw_payload_lock   (s2_awlock),
    .io_axi_aw_payload_cache  (s2_awcache),
    .io_axi_aw_payload_prot   (s2_awprot),

    .io_axi_w_valid           (s2_wvalid),
    .io_axi_w_ready           (s2_wready),
    .io_axi_w_payload_data    (s2_wdata),
    .io_axi_w_payload_strb    (s2_wstrb),
    .io_axi_w_payload_last    (s2_wlast),

    .io_axi_b_valid           (s2_bvalid),
    .io_axi_b_ready           (s2_bready),
    .io_axi_b_payload_id      (s2_bid),
    .io_axi_b_payload_resp    (s2_bresp),

    .io_axi_ar_valid          (s2_arvalid),
    .io_axi_ar_ready          (s2_arready),
    .io_axi_ar_payload_addr   (s2_araddr),
    .io_axi_ar_payload_id     (s2_arid),
    .io_axi_ar_payload_len    (s2_arlen),
    .io_axi_ar_payload_size   (s2_arsize),
    .io_axi_ar_payload_burst  (s2_arburst),
    .io_axi_ar_payload_lock   (s2_arlock),
    .io_axi_ar_payload_cache  (s2_arcache),
    .io_axi_ar_payload_prot   (s2_arprot),

    .io_axi_r_valid           (s2_rvalid),
    .io_axi_r_ready           (s2_rready),
    .io_axi_r_payload_data    (s2_rdata),
    .io_axi_r_payload_id      (s2_rid),
    .io_axi_r_payload_resp    (s2_rresp),
    .io_axi_r_payload_last    (s2_rlast)
  );

  // ================================================================ 从设备 3
  wire          s3_awvalid;
  wire          s3_awready;
  wire [31:0]   s3_awaddr;
  wire [4:0]    s3_awid;
  wire [7:0]    s3_awlen;
  wire [2:0]    s3_awsize;
  wire [1:0]    s3_awburst;
  wire          s3_awlock;
  wire [3:0]    s3_awcache;
  wire [2:0]    s3_awprot;
  wire          s3_wvalid;
  wire          s3_wready;
  wire [31:0]   s3_wdata;
  wire [3:0]    s3_wstrb;
  wire          s3_wlast;
  wire          s3_bvalid;
  wire          s3_bready;
  wire [4:0]    s3_bid;
  wire [1:0]    s3_bresp;
  wire          s3_arvalid;
  wire          s3_arready;
  wire [31:0]   s3_araddr;
  wire [4:0]    s3_arid;
  wire [7:0]    s3_arlen;
  wire [2:0]    s3_arsize;
  wire [1:0]    s3_arburst;
  wire          s3_arlock;
  wire [3:0]    s3_arcache;
  wire [2:0]    s3_arprot;
  wire          s3_rvalid;
  wire          s3_rready;
  wire [31:0]   s3_rdata;
  wire [4:0]    s3_rid;
  wire [1:0]    s3_rresp;
  wire          s3_rlast;

  AxiSlaveModel u_s3 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s3_awvalid),
    .io_axi_aw_ready          (s3_awready),
    .io_axi_aw_payload_addr   (s3_awaddr),
    .io_axi_aw_payload_id     (s3_awid),
    .io_axi_aw_payload_len    (s3_awlen),
    .io_axi_aw_payload_size   (s3_awsize),
    .io_axi_aw_payload_burst  (s3_awburst),
    .io_axi_aw_payload_lock   (s3_awlock),
    .io_axi_aw_payload_cache  (s3_awcache),
    .io_axi_aw_payload_prot   (s3_awprot),

    .io_axi_w_valid           (s3_wvalid),
    .io_axi_w_ready           (s3_wready),
    .io_axi_w_payload_data    (s3_wdata),
    .io_axi_w_payload_strb    (s3_wstrb),
    .io_axi_w_payload_last    (s3_wlast),

    .io_axi_b_valid           (s3_bvalid),
    .io_axi_b_ready           (s3_bready),
    .io_axi_b_payload_id      (s3_bid),
    .io_axi_b_payload_resp    (s3_bresp),

    .io_axi_ar_valid          (s3_arvalid),
    .io_axi_ar_ready          (s3_arready),
    .io_axi_ar_payload_addr   (s3_araddr),
    .io_axi_ar_payload_id     (s3_arid),
    .io_axi_ar_payload_len    (s3_arlen),
    .io_axi_ar_payload_size   (s3_arsize),
    .io_axi_ar_payload_burst  (s3_arburst),
    .io_axi_ar_payload_lock   (s3_arlock),
    .io_axi_ar_payload_cache  (s3_arcache),
    .io_axi_ar_payload_prot   (s3_arprot),

    .io_axi_r_valid           (s3_rvalid),
    .io_axi_r_ready           (s3_rready),
    .io_axi_r_payload_data    (s3_rdata),
    .io_axi_r_payload_id      (s3_rid),
    .io_axi_r_payload_resp    (s3_rresp),
    .io_axi_r_payload_last    (s3_rlast)
  );

  // ================================================================ 从设备 4
  wire          s4_awvalid;
  wire          s4_awready;
  wire [31:0]   s4_awaddr;
  wire [4:0]    s4_awid;
  wire [7:0]    s4_awlen;
  wire [2:0]    s4_awsize;
  wire [1:0]    s4_awburst;
  wire          s4_awlock;
  wire [3:0]    s4_awcache;
  wire [2:0]    s4_awprot;
  wire          s4_wvalid;
  wire          s4_wready;
  wire [31:0]   s4_wdata;
  wire [3:0]    s4_wstrb;
  wire          s4_wlast;
  wire          s4_bvalid;
  wire          s4_bready;
  wire [4:0]    s4_bid;
  wire [1:0]    s4_bresp;
  wire          s4_arvalid;
  wire          s4_arready;
  wire [31:0]   s4_araddr;
  wire [4:0]    s4_arid;
  wire [7:0]    s4_arlen;
  wire [2:0]    s4_arsize;
  wire [1:0]    s4_arburst;
  wire          s4_arlock;
  wire [3:0]    s4_arcache;
  wire [2:0]    s4_arprot;
  wire          s4_rvalid;
  wire          s4_rready;
  wire [31:0]   s4_rdata;
  wire [4:0]    s4_rid;
  wire [1:0]    s4_rresp;
  wire          s4_rlast;

  AxiSlaveModel u_s4 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s4_awvalid),
    .io_axi_aw_ready          (s4_awready),
    .io_axi_aw_payload_addr   (s4_awaddr),
    .io_axi_aw_payload_id     (s4_awid),
    .io_axi_aw_payload_len    (s4_awlen),
    .io_axi_aw_payload_size   (s4_awsize),
    .io_axi_aw_payload_burst  (s4_awburst),
    .io_axi_aw_payload_lock   (s4_awlock),
    .io_axi_aw_payload_cache  (s4_awcache),
    .io_axi_aw_payload_prot   (s4_awprot),

    .io_axi_w_valid           (s4_wvalid),
    .io_axi_w_ready           (s4_wready),
    .io_axi_w_payload_data    (s4_wdata),
    .io_axi_w_payload_strb    (s4_wstrb),
    .io_axi_w_payload_last    (s4_wlast),

    .io_axi_b_valid           (s4_bvalid),
    .io_axi_b_ready           (s4_bready),
    .io_axi_b_payload_id      (s4_bid),
    .io_axi_b_payload_resp    (s4_bresp),

    .io_axi_ar_valid          (s4_arvalid),
    .io_axi_ar_ready          (s4_arready),
    .io_axi_ar_payload_addr   (s4_araddr),
    .io_axi_ar_payload_id     (s4_arid),
    .io_axi_ar_payload_len    (s4_arlen),
    .io_axi_ar_payload_size   (s4_arsize),
    .io_axi_ar_payload_burst  (s4_arburst),
    .io_axi_ar_payload_lock   (s4_arlock),
    .io_axi_ar_payload_cache  (s4_arcache),
    .io_axi_ar_payload_prot   (s4_arprot),

    .io_axi_r_valid           (s4_rvalid),
    .io_axi_r_ready           (s4_rready),
    .io_axi_r_payload_data    (s4_rdata),
    .io_axi_r_payload_id      (s4_rid),
    .io_axi_r_payload_resp    (s4_rresp),
    .io_axi_r_payload_last    (s4_rlast)
  );

  // ================================================================ 从设备 5
  wire          s5_awvalid;
  wire          s5_awready;
  wire [31:0]   s5_awaddr;
  wire [4:0]    s5_awid;
  wire [7:0]    s5_awlen;
  wire [2:0]    s5_awsize;
  wire [1:0]    s5_awburst;
  wire          s5_awlock;
  wire [3:0]    s5_awcache;
  wire [2:0]    s5_awprot;
  wire          s5_wvalid;
  wire          s5_wready;
  wire [31:0]   s5_wdata;
  wire [3:0]    s5_wstrb;
  wire          s5_wlast;
  wire          s5_bvalid;
  wire          s5_bready;
  wire [4:0]    s5_bid;
  wire [1:0]    s5_bresp;
  wire          s5_arvalid;
  wire          s5_arready;
  wire [31:0]   s5_araddr;
  wire [4:0]    s5_arid;
  wire [7:0]    s5_arlen;
  wire [2:0]    s5_arsize;
  wire [1:0]    s5_arburst;
  wire          s5_arlock;
  wire [3:0]    s5_arcache;
  wire [2:0]    s5_arprot;
  wire          s5_rvalid;
  wire          s5_rready;
  wire [31:0]   s5_rdata;
  wire [4:0]    s5_rid;
  wire [1:0]    s5_rresp;
  wire          s5_rlast;

  AxiSlaveModel u_s5 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s5_awvalid),
    .io_axi_aw_ready          (s5_awready),
    .io_axi_aw_payload_addr   (s5_awaddr),
    .io_axi_aw_payload_id     (s5_awid),
    .io_axi_aw_payload_len    (s5_awlen),
    .io_axi_aw_payload_size   (s5_awsize),
    .io_axi_aw_payload_burst  (s5_awburst),
    .io_axi_aw_payload_lock   (s5_awlock),
    .io_axi_aw_payload_cache  (s5_awcache),
    .io_axi_aw_payload_prot   (s5_awprot),

    .io_axi_w_valid           (s5_wvalid),
    .io_axi_w_ready           (s5_wready),
    .io_axi_w_payload_data    (s5_wdata),
    .io_axi_w_payload_strb    (s5_wstrb),
    .io_axi_w_payload_last    (s5_wlast),

    .io_axi_b_valid           (s5_bvalid),
    .io_axi_b_ready           (s5_bready),
    .io_axi_b_payload_id      (s5_bid),
    .io_axi_b_payload_resp    (s5_bresp),

    .io_axi_ar_valid          (s5_arvalid),
    .io_axi_ar_ready          (s5_arready),
    .io_axi_ar_payload_addr   (s5_araddr),
    .io_axi_ar_payload_id     (s5_arid),
    .io_axi_ar_payload_len    (s5_arlen),
    .io_axi_ar_payload_size   (s5_arsize),
    .io_axi_ar_payload_burst  (s5_arburst),
    .io_axi_ar_payload_lock   (s5_arlock),
    .io_axi_ar_payload_cache  (s5_arcache),
    .io_axi_ar_payload_prot   (s5_arprot),

    .io_axi_r_valid           (s5_rvalid),
    .io_axi_r_ready           (s5_rready),
    .io_axi_r_payload_data    (s5_rdata),
    .io_axi_r_payload_id      (s5_rid),
    .io_axi_r_payload_resp    (s5_rresp),
    .io_axi_r_payload_last    (s5_rlast)
  );

  // ================================================================ 从设备 6
  wire          s6_awvalid;
  wire          s6_awready;
  wire [31:0]   s6_awaddr;
  wire [4:0]    s6_awid;
  wire [7:0]    s6_awlen;
  wire [2:0]    s6_awsize;
  wire [1:0]    s6_awburst;
  wire          s6_awlock;
  wire [3:0]    s6_awcache;
  wire [2:0]    s6_awprot;
  wire          s6_wvalid;
  wire          s6_wready;
  wire [31:0]   s6_wdata;
  wire [3:0]    s6_wstrb;
  wire          s6_wlast;
  wire          s6_bvalid;
  wire          s6_bready;
  wire [4:0]    s6_bid;
  wire [1:0]    s6_bresp;
  wire          s6_arvalid;
  wire          s6_arready;
  wire [31:0]   s6_araddr;
  wire [4:0]    s6_arid;
  wire [7:0]    s6_arlen;
  wire [2:0]    s6_arsize;
  wire [1:0]    s6_arburst;
  wire          s6_arlock;
  wire [3:0]    s6_arcache;
  wire [2:0]    s6_arprot;
  wire          s6_rvalid;
  wire          s6_rready;
  wire [31:0]   s6_rdata;
  wire [4:0]    s6_rid;
  wire [1:0]    s6_rresp;
  wire          s6_rlast;

  AxiSlaveModel u_s6 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s6_awvalid),
    .io_axi_aw_ready          (s6_awready),
    .io_axi_aw_payload_addr   (s6_awaddr),
    .io_axi_aw_payload_id     (s6_awid),
    .io_axi_aw_payload_len    (s6_awlen),
    .io_axi_aw_payload_size   (s6_awsize),
    .io_axi_aw_payload_burst  (s6_awburst),
    .io_axi_aw_payload_lock   (s6_awlock),
    .io_axi_aw_payload_cache  (s6_awcache),
    .io_axi_aw_payload_prot   (s6_awprot),

    .io_axi_w_valid           (s6_wvalid),
    .io_axi_w_ready           (s6_wready),
    .io_axi_w_payload_data    (s6_wdata),
    .io_axi_w_payload_strb    (s6_wstrb),
    .io_axi_w_payload_last    (s6_wlast),

    .io_axi_b_valid           (s6_bvalid),
    .io_axi_b_ready           (s6_bready),
    .io_axi_b_payload_id      (s6_bid),
    .io_axi_b_payload_resp    (s6_bresp),

    .io_axi_ar_valid          (s6_arvalid),
    .io_axi_ar_ready          (s6_arready),
    .io_axi_ar_payload_addr   (s6_araddr),
    .io_axi_ar_payload_id     (s6_arid),
    .io_axi_ar_payload_len    (s6_arlen),
    .io_axi_ar_payload_size   (s6_arsize),
    .io_axi_ar_payload_burst  (s6_arburst),
    .io_axi_ar_payload_lock   (s6_arlock),
    .io_axi_ar_payload_cache  (s6_arcache),
    .io_axi_ar_payload_prot   (s6_arprot),

    .io_axi_r_valid           (s6_rvalid),
    .io_axi_r_ready           (s6_rready),
    .io_axi_r_payload_data    (s6_rdata),
    .io_axi_r_payload_id      (s6_rid),
    .io_axi_r_payload_resp    (s6_rresp),
    .io_axi_r_payload_last    (s6_rlast)
  );

  // ================================================================ 从设备 7
  wire          s7_awvalid;
  wire          s7_awready;
  wire [31:0]   s7_awaddr;
  wire [4:0]    s7_awid;
  wire [7:0]    s7_awlen;
  wire [2:0]    s7_awsize;
  wire [1:0]    s7_awburst;
  wire          s7_awlock;
  wire [3:0]    s7_awcache;
  wire [2:0]    s7_awprot;
  wire          s7_wvalid;
  wire          s7_wready;
  wire [31:0]   s7_wdata;
  wire [3:0]    s7_wstrb;
  wire          s7_wlast;
  wire          s7_bvalid;
  wire          s7_bready;
  wire [4:0]    s7_bid;
  wire [1:0]    s7_bresp;
  wire          s7_arvalid;
  wire          s7_arready;
  wire [31:0]   s7_araddr;
  wire [4:0]    s7_arid;
  wire [7:0]    s7_arlen;
  wire [2:0]    s7_arsize;
  wire [1:0]    s7_arburst;
  wire          s7_arlock;
  wire [3:0]    s7_arcache;
  wire [2:0]    s7_arprot;
  wire          s7_rvalid;
  wire          s7_rready;
  wire [31:0]   s7_rdata;
  wire [4:0]    s7_rid;
  wire [1:0]    s7_rresp;
  wire          s7_rlast;

  AxiSlaveModel u_s7 (
    .clk    (clk),
    .resetn (reset_n),
    .io_axi_aw_valid          (s7_awvalid),
    .io_axi_aw_ready          (s7_awready),
    .io_axi_aw_payload_addr   (s7_awaddr),
    .io_axi_aw_payload_id     (s7_awid),
    .io_axi_aw_payload_len    (s7_awlen),
    .io_axi_aw_payload_size   (s7_awsize),
    .io_axi_aw_payload_burst  (s7_awburst),
    .io_axi_aw_payload_lock   (s7_awlock),
    .io_axi_aw_payload_cache  (s7_awcache),
    .io_axi_aw_payload_prot   (s7_awprot),

    .io_axi_w_valid           (s7_wvalid),
    .io_axi_w_ready           (s7_wready),
    .io_axi_w_payload_data    (s7_wdata),
    .io_axi_w_payload_strb    (s7_wstrb),
    .io_axi_w_payload_last    (s7_wlast),

    .io_axi_b_valid           (s7_bvalid),
    .io_axi_b_ready           (s7_bready),
    .io_axi_b_payload_id      (s7_bid),
    .io_axi_b_payload_resp    (s7_bresp),

    .io_axi_ar_valid          (s7_arvalid),
    .io_axi_ar_ready          (s7_arready),
    .io_axi_ar_payload_addr   (s7_araddr),
    .io_axi_ar_payload_id     (s7_arid),
    .io_axi_ar_payload_len    (s7_arlen),
    .io_axi_ar_payload_size   (s7_arsize),
    .io_axi_ar_payload_burst  (s7_arburst),
    .io_axi_ar_payload_lock   (s7_arlock),
    .io_axi_ar_payload_cache  (s7_arcache),
    .io_axi_ar_payload_prot   (s7_arprot),

    .io_axi_r_valid           (s7_rvalid),
    .io_axi_r_ready           (s7_rready),
    .io_axi_r_payload_data    (s7_rdata),
    .io_axi_r_payload_id      (s7_rid),
    .io_axi_r_payload_resp    (s7_rresp),
    .io_axi_r_payload_last    (s7_rlast)
  );

  // ================================================================ 被测互连
  AxiCrossbar_2x8 u_dut (
    .clk    (clk),
    .resetn (reset_n),

    // ---- 输入 0：来自主设备 0 ----
    .axiIn_0_awvalid          (m0_awvalid),
    .axiIn_0_awready          (m0_awready),
    .axiIn_0_awaddr           (m0_awaddr),
    .axiIn_0_awid             (m0_awid),
    .axiIn_0_awlen            (m0_awlen),
    .axiIn_0_awsize           (m0_awsize),
    .axiIn_0_awburst          (m0_awburst),
    .axiIn_0_awlock           (m0_awlock),
    .axiIn_0_awcache          (m0_awcache),
    .axiIn_0_awprot           (m0_awprot),

    .axiIn_0_wvalid           (m0_wvalid),
    .axiIn_0_wready           (m0_wready),
    .axiIn_0_wdata            (m0_wdata),
    .axiIn_0_wstrb            (m0_wstrb),
    .axiIn_0_wlast            (m0_wlast),

    .axiIn_0_bvalid           (m0_bvalid),
    .axiIn_0_bready           (m0_bready),
    .axiIn_0_bid              (m0_bid),
    .axiIn_0_bresp            (m0_bresp),

    .axiIn_0_arvalid          (m0_arvalid),
    .axiIn_0_arready          (m0_arready),
    .axiIn_0_araddr           (m0_araddr),
    .axiIn_0_arid             (m0_arid),
    .axiIn_0_arlen            (m0_arlen),
    .axiIn_0_arsize           (m0_arsize),
    .axiIn_0_arburst          (m0_arburst),
    .axiIn_0_arlock           (m0_arlock),
    .axiIn_0_arcache          (m0_arcache),
    .axiIn_0_arprot           (m0_arprot),

    .axiIn_0_rvalid           (m0_rvalid),
    .axiIn_0_rready           (m0_rready),
    .axiIn_0_rdata            (m0_rdata),
    .axiIn_0_rid              (m0_rid),
    .axiIn_0_rresp            (m0_rresp),
    .axiIn_0_rlast            (m0_rlast),

    // ---- 输入 1：来自主设备 1 ----
    .axiIn_1_awvalid          (m1_awvalid),
    .axiIn_1_awready          (m1_awready),
    .axiIn_1_awaddr           (m1_awaddr),
    .axiIn_1_awid             (m1_awid),
    .axiIn_1_awlen            (m1_awlen),
    .axiIn_1_awsize           (m1_awsize),
    .axiIn_1_awburst          (m1_awburst),
    .axiIn_1_awlock           (m1_awlock),
    .axiIn_1_awcache          (m1_awcache),
    .axiIn_1_awprot           (m1_awprot),

    .axiIn_1_wvalid           (m1_wvalid),
    .axiIn_1_wready           (m1_wready),
    .axiIn_1_wdata            (m1_wdata),
    .axiIn_1_wstrb            (m1_wstrb),
    .axiIn_1_wlast            (m1_wlast),

    .axiIn_1_bvalid           (m1_bvalid),
    .axiIn_1_bready           (m1_bready),
    .axiIn_1_bid              (m1_bid),
    .axiIn_1_bresp            (m1_bresp),

    .axiIn_1_arvalid          (m1_arvalid),
    .axiIn_1_arready          (m1_arready),
    .axiIn_1_araddr           (m1_araddr),
    .axiIn_1_arid             (m1_arid),
    .axiIn_1_arlen            (m1_arlen),
    .axiIn_1_arsize           (m1_arsize),
    .axiIn_1_arburst          (m1_arburst),
    .axiIn_1_arlock           (m1_arlock),
    .axiIn_1_arcache          (m1_arcache),
    .axiIn_1_arprot           (m1_arprot),

    .axiIn_1_rvalid           (m1_rvalid),
    .axiIn_1_rready           (m1_rready),
    .axiIn_1_rdata            (m1_rdata),
    .axiIn_1_rid              (m1_rid),
    .axiIn_1_rresp            (m1_rresp),
    .axiIn_1_rlast            (m1_rlast),

    // ---- 输出 0：去从设备 0 ----
    .axiOut_0_awvalid         (s0_awvalid),
    .axiOut_0_awready         (s0_awready),
    .axiOut_0_awaddr          (s0_awaddr),
    .axiOut_0_awid            (s0_awid),
    .axiOut_0_awlen           (s0_awlen),
    .axiOut_0_awsize          (s0_awsize),
    .axiOut_0_awburst         (s0_awburst),
    .axiOut_0_awlock          (s0_awlock),
    .axiOut_0_awcache         (s0_awcache),
    .axiOut_0_awprot          (s0_awprot),

    .axiOut_0_wvalid          (s0_wvalid),
    .axiOut_0_wready          (s0_wready),
    .axiOut_0_wdata           (s0_wdata),
    .axiOut_0_wstrb           (s0_wstrb),
    .axiOut_0_wlast           (s0_wlast),

    .axiOut_0_bvalid          (s0_bvalid),
    .axiOut_0_bready          (s0_bready),
    .axiOut_0_bid             (s0_bid),
    .axiOut_0_bresp           (s0_bresp),

    .axiOut_0_arvalid         (s0_arvalid),
    .axiOut_0_arready         (s0_arready),
    .axiOut_0_araddr          (s0_araddr),
    .axiOut_0_arid            (s0_arid),
    .axiOut_0_arlen           (s0_arlen),
    .axiOut_0_arsize          (s0_arsize),
    .axiOut_0_arburst         (s0_arburst),
    .axiOut_0_arlock          (s0_arlock),
    .axiOut_0_arcache         (s0_arcache),
    .axiOut_0_arprot          (s0_arprot),

    .axiOut_0_rvalid          (s0_rvalid),
    .axiOut_0_rready          (s0_rready),
    .axiOut_0_rdata           (s0_rdata),
    .axiOut_0_rid             (s0_rid),
    .axiOut_0_rresp           (s0_rresp),
    .axiOut_0_rlast           (s0_rlast),

    // ---- 输出 1：去从设备 1 ----
    .axiOut_1_awvalid         (s1_awvalid),
    .axiOut_1_awready         (s1_awready),
    .axiOut_1_awaddr          (s1_awaddr),
    .axiOut_1_awid            (s1_awid),
    .axiOut_1_awlen           (s1_awlen),
    .axiOut_1_awsize          (s1_awsize),
    .axiOut_1_awburst         (s1_awburst),
    .axiOut_1_awlock          (s1_awlock),
    .axiOut_1_awcache         (s1_awcache),
    .axiOut_1_awprot          (s1_awprot),

    .axiOut_1_wvalid          (s1_wvalid),
    .axiOut_1_wready          (s1_wready),
    .axiOut_1_wdata           (s1_wdata),
    .axiOut_1_wstrb           (s1_wstrb),
    .axiOut_1_wlast           (s1_wlast),

    .axiOut_1_bvalid          (s1_bvalid),
    .axiOut_1_bready          (s1_bready),
    .axiOut_1_bid             (s1_bid),
    .axiOut_1_bresp           (s1_bresp),

    .axiOut_1_arvalid         (s1_arvalid),
    .axiOut_1_arready         (s1_arready),
    .axiOut_1_araddr          (s1_araddr),
    .axiOut_1_arid            (s1_arid),
    .axiOut_1_arlen           (s1_arlen),
    .axiOut_1_arsize          (s1_arsize),
    .axiOut_1_arburst         (s1_arburst),
    .axiOut_1_arlock          (s1_arlock),
    .axiOut_1_arcache         (s1_arcache),
    .axiOut_1_arprot          (s1_arprot),

    .axiOut_1_rvalid          (s1_rvalid),
    .axiOut_1_rready          (s1_rready),
    .axiOut_1_rdata           (s1_rdata),
    .axiOut_1_rid             (s1_rid),
    .axiOut_1_rresp           (s1_rresp),
    .axiOut_1_rlast           (s1_rlast),

    // ---- 输出 2：去从设备 2 ----
    .axiOut_2_awvalid         (s2_awvalid),
    .axiOut_2_awready         (s2_awready),
    .axiOut_2_awaddr          (s2_awaddr),
    .axiOut_2_awid            (s2_awid),
    .axiOut_2_awlen           (s2_awlen),
    .axiOut_2_awsize          (s2_awsize),
    .axiOut_2_awburst         (s2_awburst),
    .axiOut_2_awlock          (s2_awlock),
    .axiOut_2_awcache         (s2_awcache),
    .axiOut_2_awprot          (s2_awprot),

    .axiOut_2_wvalid          (s2_wvalid),
    .axiOut_2_wready          (s2_wready),
    .axiOut_2_wdata           (s2_wdata),
    .axiOut_2_wstrb           (s2_wstrb),
    .axiOut_2_wlast           (s2_wlast),

    .axiOut_2_bvalid          (s2_bvalid),
    .axiOut_2_bready          (s2_bready),
    .axiOut_2_bid             (s2_bid),
    .axiOut_2_bresp           (s2_bresp),

    .axiOut_2_arvalid         (s2_arvalid),
    .axiOut_2_arready         (s2_arready),
    .axiOut_2_araddr          (s2_araddr),
    .axiOut_2_arid            (s2_arid),
    .axiOut_2_arlen           (s2_arlen),
    .axiOut_2_arsize          (s2_arsize),
    .axiOut_2_arburst         (s2_arburst),
    .axiOut_2_arlock          (s2_arlock),
    .axiOut_2_arcache         (s2_arcache),
    .axiOut_2_arprot          (s2_arprot),

    .axiOut_2_rvalid          (s2_rvalid),
    .axiOut_2_rready          (s2_rready),
    .axiOut_2_rdata           (s2_rdata),
    .axiOut_2_rid             (s2_rid),
    .axiOut_2_rresp           (s2_rresp),
    .axiOut_2_rlast           (s2_rlast),

    // ---- 输出 3：去从设备 3 ----
    .axiOut_3_awvalid         (s3_awvalid),
    .axiOut_3_awready         (s3_awready),
    .axiOut_3_awaddr          (s3_awaddr),
    .axiOut_3_awid            (s3_awid),
    .axiOut_3_awlen           (s3_awlen),
    .axiOut_3_awsize          (s3_awsize),
    .axiOut_3_awburst         (s3_awburst),
    .axiOut_3_awlock          (s3_awlock),
    .axiOut_3_awcache         (s3_awcache),
    .axiOut_3_awprot          (s3_awprot),

    .axiOut_3_wvalid          (s3_wvalid),
    .axiOut_3_wready          (s3_wready),
    .axiOut_3_wdata           (s3_wdata),
    .axiOut_3_wstrb           (s3_wstrb),
    .axiOut_3_wlast           (s3_wlast),

    .axiOut_3_bvalid          (s3_bvalid),
    .axiOut_3_bready          (s3_bready),
    .axiOut_3_bid             (s3_bid),
    .axiOut_3_bresp           (s3_bresp),

    .axiOut_3_arvalid         (s3_arvalid),
    .axiOut_3_arready         (s3_arready),
    .axiOut_3_araddr          (s3_araddr),
    .axiOut_3_arid            (s3_arid),
    .axiOut_3_arlen           (s3_arlen),
    .axiOut_3_arsize          (s3_arsize),
    .axiOut_3_arburst         (s3_arburst),
    .axiOut_3_arlock          (s3_arlock),
    .axiOut_3_arcache         (s3_arcache),
    .axiOut_3_arprot          (s3_arprot),

    .axiOut_3_rvalid          (s3_rvalid),
    .axiOut_3_rready          (s3_rready),
    .axiOut_3_rdata           (s3_rdata),
    .axiOut_3_rid             (s3_rid),
    .axiOut_3_rresp           (s3_rresp),
    .axiOut_3_rlast           (s3_rlast),

    // ---- 输出 4：去从设备 4 ----
    .axiOut_4_awvalid         (s4_awvalid),
    .axiOut_4_awready         (s4_awready),
    .axiOut_4_awaddr          (s4_awaddr),
    .axiOut_4_awid            (s4_awid),
    .axiOut_4_awlen           (s4_awlen),
    .axiOut_4_awsize          (s4_awsize),
    .axiOut_4_awburst         (s4_awburst),
    .axiOut_4_awlock          (s4_awlock),
    .axiOut_4_awcache         (s4_awcache),
    .axiOut_4_awprot          (s4_awprot),

    .axiOut_4_wvalid          (s4_wvalid),
    .axiOut_4_wready          (s4_wready),
    .axiOut_4_wdata           (s4_wdata),
    .axiOut_4_wstrb           (s4_wstrb),
    .axiOut_4_wlast           (s4_wlast),

    .axiOut_4_bvalid          (s4_bvalid),
    .axiOut_4_bready          (s4_bready),
    .axiOut_4_bid             (s4_bid),
    .axiOut_4_bresp           (s4_bresp),

    .axiOut_4_arvalid         (s4_arvalid),
    .axiOut_4_arready         (s4_arready),
    .axiOut_4_araddr          (s4_araddr),
    .axiOut_4_arid            (s4_arid),
    .axiOut_4_arlen           (s4_arlen),
    .axiOut_4_arsize          (s4_arsize),
    .axiOut_4_arburst         (s4_arburst),
    .axiOut_4_arlock          (s4_arlock),
    .axiOut_4_arcache         (s4_arcache),
    .axiOut_4_arprot          (s4_arprot),

    .axiOut_4_rvalid          (s4_rvalid),
    .axiOut_4_rready          (s4_rready),
    .axiOut_4_rdata           (s4_rdata),
    .axiOut_4_rid             (s4_rid),
    .axiOut_4_rresp           (s4_rresp),
    .axiOut_4_rlast           (s4_rlast),

    // ---- 输出 5：去从设备 5 ----
    .axiOut_5_awvalid         (s5_awvalid),
    .axiOut_5_awready         (s5_awready),
    .axiOut_5_awaddr          (s5_awaddr),
    .axiOut_5_awid            (s5_awid),
    .axiOut_5_awlen           (s5_awlen),
    .axiOut_5_awsize          (s5_awsize),
    .axiOut_5_awburst         (s5_awburst),
    .axiOut_5_awlock          (s5_awlock),
    .axiOut_5_awcache         (s5_awcache),
    .axiOut_5_awprot          (s5_awprot),

    .axiOut_5_wvalid          (s5_wvalid),
    .axiOut_5_wready          (s5_wready),
    .axiOut_5_wdata           (s5_wdata),
    .axiOut_5_wstrb           (s5_wstrb),
    .axiOut_5_wlast           (s5_wlast),

    .axiOut_5_bvalid          (s5_bvalid),
    .axiOut_5_bready          (s5_bready),
    .axiOut_5_bid             (s5_bid),
    .axiOut_5_bresp           (s5_bresp),

    .axiOut_5_arvalid         (s5_arvalid),
    .axiOut_5_arready         (s5_arready),
    .axiOut_5_araddr          (s5_araddr),
    .axiOut_5_arid            (s5_arid),
    .axiOut_5_arlen           (s5_arlen),
    .axiOut_5_arsize          (s5_arsize),
    .axiOut_5_arburst         (s5_arburst),
    .axiOut_5_arlock          (s5_arlock),
    .axiOut_5_arcache         (s5_arcache),
    .axiOut_5_arprot          (s5_arprot),

    .axiOut_5_rvalid          (s5_rvalid),
    .axiOut_5_rready          (s5_rready),
    .axiOut_5_rdata           (s5_rdata),
    .axiOut_5_rid             (s5_rid),
    .axiOut_5_rresp           (s5_rresp),
    .axiOut_5_rlast           (s5_rlast),

    // ---- 输出 6：去从设备 6 ----
    .axiOut_6_awvalid         (s6_awvalid),
    .axiOut_6_awready         (s6_awready),
    .axiOut_6_awaddr          (s6_awaddr),
    .axiOut_6_awid            (s6_awid),
    .axiOut_6_awlen           (s6_awlen),
    .axiOut_6_awsize          (s6_awsize),
    .axiOut_6_awburst         (s6_awburst),
    .axiOut_6_awlock          (s6_awlock),
    .axiOut_6_awcache         (s6_awcache),
    .axiOut_6_awprot          (s6_awprot),

    .axiOut_6_wvalid          (s6_wvalid),
    .axiOut_6_wready          (s6_wready),
    .axiOut_6_wdata           (s6_wdata),
    .axiOut_6_wstrb           (s6_wstrb),
    .axiOut_6_wlast           (s6_wlast),

    .axiOut_6_bvalid          (s6_bvalid),
    .axiOut_6_bready          (s6_bready),
    .axiOut_6_bid             (s6_bid),
    .axiOut_6_bresp           (s6_bresp),

    .axiOut_6_arvalid         (s6_arvalid),
    .axiOut_6_arready         (s6_arready),
    .axiOut_6_araddr          (s6_araddr),
    .axiOut_6_arid            (s6_arid),
    .axiOut_6_arlen           (s6_arlen),
    .axiOut_6_arsize          (s6_arsize),
    .axiOut_6_arburst         (s6_arburst),
    .axiOut_6_arlock          (s6_arlock),
    .axiOut_6_arcache         (s6_arcache),
    .axiOut_6_arprot          (s6_arprot),

    .axiOut_6_rvalid          (s6_rvalid),
    .axiOut_6_rready          (s6_rready),
    .axiOut_6_rdata           (s6_rdata),
    .axiOut_6_rid             (s6_rid),
    .axiOut_6_rresp           (s6_rresp),
    .axiOut_6_rlast           (s6_rlast),

    // ---- 输出 7：去从设备 7 ----
    .axiOut_7_awvalid         (s7_awvalid),
    .axiOut_7_awready         (s7_awready),
    .axiOut_7_awaddr          (s7_awaddr),
    .axiOut_7_awid            (s7_awid),
    .axiOut_7_awlen           (s7_awlen),
    .axiOut_7_awsize          (s7_awsize),
    .axiOut_7_awburst         (s7_awburst),
    .axiOut_7_awlock          (s7_awlock),
    .axiOut_7_awcache         (s7_awcache),
    .axiOut_7_awprot          (s7_awprot),

    .axiOut_7_wvalid          (s7_wvalid),
    .axiOut_7_wready          (s7_wready),
    .axiOut_7_wdata           (s7_wdata),
    .axiOut_7_wstrb           (s7_wstrb),
    .axiOut_7_wlast           (s7_wlast),

    .axiOut_7_bvalid          (s7_bvalid),
    .axiOut_7_bready          (s7_bready),
    .axiOut_7_bid             (s7_bid),
    .axiOut_7_bresp           (s7_bresp),

    .axiOut_7_arvalid         (s7_arvalid),
    .axiOut_7_arready         (s7_arready),
    .axiOut_7_araddr          (s7_araddr),
    .axiOut_7_arid            (s7_arid),
    .axiOut_7_arlen           (s7_arlen),
    .axiOut_7_arsize          (s7_arsize),
    .axiOut_7_arburst         (s7_arburst),
    .axiOut_7_arlock          (s7_arlock),
    .axiOut_7_arcache         (s7_arcache),
    .axiOut_7_arprot          (s7_arprot),

    .axiOut_7_rvalid          (s7_rvalid),
    .axiOut_7_rready          (s7_rready),
    .axiOut_7_rdata           (s7_rdata),
    .axiOut_7_rid             (s7_rid),
    .axiOut_7_rresp           (s7_rresp),
    .axiOut_7_rlast           (s7_rlast)
  );

  // ---------------------------------------------------------------- 判定
  localparam TIMEOUT = 200000;   // 拍

  integer cyc = 0;
  reg     reported = 0;

  initial begin
    $display("");
    $display("================ AXI4 crossbar simulation ================");
    $display("  master 0 : base=0x1C000000 stride=0x1000 seed=0x11000000 id=3");
    $display("  master 1 : base=0x1C010000 stride=0x1000 seed=0x22000000 id=7");
    $display("  8 rounds x 4 beats each; the two masters should interleave on the crossbar");
    $display("====================================================");
    $display("");
  end

  always @(posedge clk) begin
    if (reset_n && !reported) begin
      cyc <= cyc + 1;

      if (m0_error | m1_error) begin
        reported <= 1;
        $display("==== FAIL ==== data mismatch: m0_error=%0d m1_error=%0d (cycle %0d)",
                 m0_error, m1_error, cyc);
        $display("  hint: compare io_axi_r_payload_data at the masters, then check routing on crossbar outputs");
        $finish;
      end else if (m0_done & m1_done) begin
        reported <= 1;
        $display("==== PASS ==== 2 masters x 8 rounds x 4 beats, all read back identical (%0d cycles)", cyc);
        $finish;
      end else if (cyc > TIMEOUT) begin
        reported <= 1;
        $display("==== FAIL ==== timeout after %0d cycles: m0_done=%0d m1_done=%0d",
                 TIMEOUT, m0_done, m1_done);
        $display("  hint: some slave never returned B/R - check for a stuck handshake");
        $finish;
      end
    end
  end

endmodule
