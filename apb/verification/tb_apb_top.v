// =============================================================================
//  tb_apb_top.v —— APB3 互连的仿真顶层（手写 Verilog）
//
//  结构同 tb_axi_top.v，只是把 AXI 换成 APB、8 根信号代替 35 根：
//      u_dut     : Apb3Crossbar_2x8 ← verilog/Apb3Crossbar_2x8.v（生成物）
//      u_m0/u_m1 : ApbMasterModel   ← verification/models/ApbMasterModel.v（生成物）
//      u_s0..u_s7: ApbSlaveModel    ← verification/models/ApbSlaveModel.v（生成物）
//
//  ---------------------------------------------------------------------------
//  两个主设备打的是不同从设备窗口：
//      主设备 0 → apbOut(0)，0x0000_0000 起（sram）
//      主设备 1 → apbOut(4)，0x0000_4000 起（gpio）
//  io_stride = 0x20 = 每轮 8 个字 × 4 字节，四轮正好占满 0x00~0x7F，互不重叠。
//  ⚠ 不要把 io_stride 改小成 0x10 之类：相邻两轮会重叠，读回的数据被后一轮覆盖，
//    波形上握手却完全正常 —— 这是 APB 仿真最容易误判成「互连坏了」的坑。
//  ---------------------------------------------------------------------------
//  判定同 AXI：打印 ==== PASS ==== / ==== FAIL ==== 后 $finish
// =============================================================================

`timescale 1ns / 1ps

module tb_apb_top;

  // ---------------------------------------------------------------- 时钟与复位
  reg clk = 0;
  always #5 clk = ~clk;

  reg reset_n = 0;
  initial begin
    reset_n = 0;
    repeat (20) @(posedge clk);
    reset_n = 1;
  end

  wire m0_done, m0_error;
  wire m1_done, m1_error;

  // ================================================================ 主设备 0
  // base=0x00000000  stride=0x20  seed=0x12340000
  wire [31:0]   m0_PADDR;
  wire          m0_PSEL;
  wire          m0_PENABLE;
  wire          m0_PREADY;
  wire          m0_PWRITE;
  wire [31:0]   m0_PWDATA;
  wire [31:0]   m0_PRDATA;
  wire          m0_PSLVERROR;

  ApbMasterModel u_m0 (
    .clk       (clk),
    .resetn    (reset_n),
    .io_base   (32'h0000_0000),
    .io_stride (32'h0000_0020),
    .io_seed   (32'h1234_0000),
    .io_busy   (),
    .io_error  (m0_error),
    .io_done   (m0_done),
    .io_apb_PADDR             (m0_PADDR),
    .io_apb_PSEL              (m0_PSEL),
    .io_apb_PENABLE           (m0_PENABLE),
    .io_apb_PREADY            (m0_PREADY),
    .io_apb_PWRITE            (m0_PWRITE),
    .io_apb_PWDATA            (m0_PWDATA),
    .io_apb_PRDATA            (m0_PRDATA),
    .io_apb_PSLVERROR         (m0_PSLVERROR)
  );

  // ================================================================ 主设备 1
  // base=0x00004000  stride=0x20  seed=0x12440000
  wire [31:0]   m1_PADDR;
  wire          m1_PSEL;
  wire          m1_PENABLE;
  wire          m1_PREADY;
  wire          m1_PWRITE;
  wire [31:0]   m1_PWDATA;
  wire [31:0]   m1_PRDATA;
  wire          m1_PSLVERROR;

  ApbMasterModel u_m1 (
    .clk       (clk),
    .resetn    (reset_n),
    .io_base   (32'h0000_4000),
    .io_stride (32'h0000_0020),
    .io_seed   (32'h1244_0000),
    .io_busy   (),
    .io_error  (m1_error),
    .io_done   (m1_done),
    .io_apb_PADDR             (m1_PADDR),
    .io_apb_PSEL              (m1_PSEL),
    .io_apb_PENABLE           (m1_PENABLE),
    .io_apb_PREADY            (m1_PREADY),
    .io_apb_PWRITE            (m1_PWRITE),
    .io_apb_PWDATA            (m1_PWDATA),
    .io_apb_PRDATA            (m1_PRDATA),
    .io_apb_PSLVERROR         (m1_PSLVERROR)
  );

  // ================================================================ 从设备 0
  wire [31:0]   s0_PADDR;
  wire          s0_PSEL;
  wire          s0_PENABLE;
  wire          s0_PREADY;
  wire          s0_PWRITE;
  wire [31:0]   s0_PWDATA;
  wire [31:0]   s0_PRDATA;
  wire          s0_PSLVERROR;

  ApbSlaveModel u_s0 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s0_PADDR),
    .io_apb_PSEL          (s0_PSEL),
    .io_apb_PENABLE       (s0_PENABLE),
    .io_apb_PREADY        (s0_PREADY),
    .io_apb_PWRITE        (s0_PWRITE),
    .io_apb_PWDATA        (s0_PWDATA),
    .io_apb_PRDATA        (s0_PRDATA),
    .io_apb_PSLVERROR     (s0_PSLVERROR)
  );

  // ================================================================ 从设备 1
  wire [31:0]   s1_PADDR;
  wire          s1_PSEL;
  wire          s1_PENABLE;
  wire          s1_PREADY;
  wire          s1_PWRITE;
  wire [31:0]   s1_PWDATA;
  wire [31:0]   s1_PRDATA;
  wire          s1_PSLVERROR;

  ApbSlaveModel u_s1 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s1_PADDR),
    .io_apb_PSEL          (s1_PSEL),
    .io_apb_PENABLE       (s1_PENABLE),
    .io_apb_PREADY        (s1_PREADY),
    .io_apb_PWRITE        (s1_PWRITE),
    .io_apb_PWDATA        (s1_PWDATA),
    .io_apb_PRDATA        (s1_PRDATA),
    .io_apb_PSLVERROR     (s1_PSLVERROR)
  );

  // ================================================================ 从设备 2
  wire [31:0]   s2_PADDR;
  wire          s2_PSEL;
  wire          s2_PENABLE;
  wire          s2_PREADY;
  wire          s2_PWRITE;
  wire [31:0]   s2_PWDATA;
  wire [31:0]   s2_PRDATA;
  wire          s2_PSLVERROR;

  ApbSlaveModel u_s2 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s2_PADDR),
    .io_apb_PSEL          (s2_PSEL),
    .io_apb_PENABLE       (s2_PENABLE),
    .io_apb_PREADY        (s2_PREADY),
    .io_apb_PWRITE        (s2_PWRITE),
    .io_apb_PWDATA        (s2_PWDATA),
    .io_apb_PRDATA        (s2_PRDATA),
    .io_apb_PSLVERROR     (s2_PSLVERROR)
  );

  // ================================================================ 从设备 3
  wire [31:0]   s3_PADDR;
  wire          s3_PSEL;
  wire          s3_PENABLE;
  wire          s3_PREADY;
  wire          s3_PWRITE;
  wire [31:0]   s3_PWDATA;
  wire [31:0]   s3_PRDATA;
  wire          s3_PSLVERROR;

  ApbSlaveModel u_s3 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s3_PADDR),
    .io_apb_PSEL          (s3_PSEL),
    .io_apb_PENABLE       (s3_PENABLE),
    .io_apb_PREADY        (s3_PREADY),
    .io_apb_PWRITE        (s3_PWRITE),
    .io_apb_PWDATA        (s3_PWDATA),
    .io_apb_PRDATA        (s3_PRDATA),
    .io_apb_PSLVERROR     (s3_PSLVERROR)
  );

  // ================================================================ 从设备 4
  wire [31:0]   s4_PADDR;
  wire          s4_PSEL;
  wire          s4_PENABLE;
  wire          s4_PREADY;
  wire          s4_PWRITE;
  wire [31:0]   s4_PWDATA;
  wire [31:0]   s4_PRDATA;
  wire          s4_PSLVERROR;

  ApbSlaveModel u_s4 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s4_PADDR),
    .io_apb_PSEL          (s4_PSEL),
    .io_apb_PENABLE       (s4_PENABLE),
    .io_apb_PREADY        (s4_PREADY),
    .io_apb_PWRITE        (s4_PWRITE),
    .io_apb_PWDATA        (s4_PWDATA),
    .io_apb_PRDATA        (s4_PRDATA),
    .io_apb_PSLVERROR     (s4_PSLVERROR)
  );

  // ================================================================ 从设备 5
  wire [31:0]   s5_PADDR;
  wire          s5_PSEL;
  wire          s5_PENABLE;
  wire          s5_PREADY;
  wire          s5_PWRITE;
  wire [31:0]   s5_PWDATA;
  wire [31:0]   s5_PRDATA;
  wire          s5_PSLVERROR;

  ApbSlaveModel u_s5 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s5_PADDR),
    .io_apb_PSEL          (s5_PSEL),
    .io_apb_PENABLE       (s5_PENABLE),
    .io_apb_PREADY        (s5_PREADY),
    .io_apb_PWRITE        (s5_PWRITE),
    .io_apb_PWDATA        (s5_PWDATA),
    .io_apb_PRDATA        (s5_PRDATA),
    .io_apb_PSLVERROR     (s5_PSLVERROR)
  );

  // ================================================================ 从设备 6
  wire [31:0]   s6_PADDR;
  wire          s6_PSEL;
  wire          s6_PENABLE;
  wire          s6_PREADY;
  wire          s6_PWRITE;
  wire [31:0]   s6_PWDATA;
  wire [31:0]   s6_PRDATA;
  wire          s6_PSLVERROR;

  ApbSlaveModel u_s6 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s6_PADDR),
    .io_apb_PSEL          (s6_PSEL),
    .io_apb_PENABLE       (s6_PENABLE),
    .io_apb_PREADY        (s6_PREADY),
    .io_apb_PWRITE        (s6_PWRITE),
    .io_apb_PWDATA        (s6_PWDATA),
    .io_apb_PRDATA        (s6_PRDATA),
    .io_apb_PSLVERROR     (s6_PSLVERROR)
  );

  // ================================================================ 从设备 7
  wire [31:0]   s7_PADDR;
  wire          s7_PSEL;
  wire          s7_PENABLE;
  wire          s7_PREADY;
  wire          s7_PWRITE;
  wire [31:0]   s7_PWDATA;
  wire [31:0]   s7_PRDATA;
  wire          s7_PSLVERROR;

  ApbSlaveModel u_s7 (
    .clk    (clk),
    .resetn (reset_n),
    .io_apb_PADDR         (s7_PADDR),
    .io_apb_PSEL          (s7_PSEL),
    .io_apb_PENABLE       (s7_PENABLE),
    .io_apb_PREADY        (s7_PREADY),
    .io_apb_PWRITE        (s7_PWRITE),
    .io_apb_PWDATA        (s7_PWDATA),
    .io_apb_PRDATA        (s7_PRDATA),
    .io_apb_PSLVERROR     (s7_PSLVERROR)
  );

  // ================================================================ 被测互连
  Apb3Crossbar_2x8 u_dut (
    .clk    (clk),
    .resetn (reset_n),

    // ---- 输入 0：来自主设备 0 ----
    .apbIn_0_PADDR            (m0_PADDR),
    .apbIn_0_PSEL             (m0_PSEL),
    .apbIn_0_PENABLE          (m0_PENABLE),
    .apbIn_0_PREADY           (m0_PREADY),
    .apbIn_0_PWRITE           (m0_PWRITE),
    .apbIn_0_PWDATA           (m0_PWDATA),
    .apbIn_0_PRDATA           (m0_PRDATA),
    .apbIn_0_PSLVERROR        (m0_PSLVERROR),

    // ---- 输入 1：来自主设备 1 ----
    .apbIn_1_PADDR            (m1_PADDR),
    .apbIn_1_PSEL             (m1_PSEL),
    .apbIn_1_PENABLE          (m1_PENABLE),
    .apbIn_1_PREADY           (m1_PREADY),
    .apbIn_1_PWRITE           (m1_PWRITE),
    .apbIn_1_PWDATA           (m1_PWDATA),
    .apbIn_1_PRDATA           (m1_PRDATA),
    .apbIn_1_PSLVERROR        (m1_PSLVERROR),

    // ---- 输出 0：去从设备 0 ----
    .apbOut_0_PADDR           (s0_PADDR),
    .apbOut_0_PSEL            (s0_PSEL),
    .apbOut_0_PENABLE         (s0_PENABLE),
    .apbOut_0_PREADY          (s0_PREADY),
    .apbOut_0_PWRITE          (s0_PWRITE),
    .apbOut_0_PWDATA          (s0_PWDATA),
    .apbOut_0_PRDATA          (s0_PRDATA),
    .apbOut_0_PSLVERROR       (s0_PSLVERROR),

    // ---- 输出 1：去从设备 1 ----
    .apbOut_1_PADDR           (s1_PADDR),
    .apbOut_1_PSEL            (s1_PSEL),
    .apbOut_1_PENABLE         (s1_PENABLE),
    .apbOut_1_PREADY          (s1_PREADY),
    .apbOut_1_PWRITE          (s1_PWRITE),
    .apbOut_1_PWDATA          (s1_PWDATA),
    .apbOut_1_PRDATA          (s1_PRDATA),
    .apbOut_1_PSLVERROR       (s1_PSLVERROR),

    // ---- 输出 2：去从设备 2 ----
    .apbOut_2_PADDR           (s2_PADDR),
    .apbOut_2_PSEL            (s2_PSEL),
    .apbOut_2_PENABLE         (s2_PENABLE),
    .apbOut_2_PREADY          (s2_PREADY),
    .apbOut_2_PWRITE          (s2_PWRITE),
    .apbOut_2_PWDATA          (s2_PWDATA),
    .apbOut_2_PRDATA          (s2_PRDATA),
    .apbOut_2_PSLVERROR       (s2_PSLVERROR),

    // ---- 输出 3：去从设备 3 ----
    .apbOut_3_PADDR           (s3_PADDR),
    .apbOut_3_PSEL            (s3_PSEL),
    .apbOut_3_PENABLE         (s3_PENABLE),
    .apbOut_3_PREADY          (s3_PREADY),
    .apbOut_3_PWRITE          (s3_PWRITE),
    .apbOut_3_PWDATA          (s3_PWDATA),
    .apbOut_3_PRDATA          (s3_PRDATA),
    .apbOut_3_PSLVERROR       (s3_PSLVERROR),

    // ---- 输出 4：去从设备 4 ----
    .apbOut_4_PADDR           (s4_PADDR),
    .apbOut_4_PSEL            (s4_PSEL),
    .apbOut_4_PENABLE         (s4_PENABLE),
    .apbOut_4_PREADY          (s4_PREADY),
    .apbOut_4_PWRITE          (s4_PWRITE),
    .apbOut_4_PWDATA          (s4_PWDATA),
    .apbOut_4_PRDATA          (s4_PRDATA),
    .apbOut_4_PSLVERROR       (s4_PSLVERROR),

    // ---- 输出 5：去从设备 5 ----
    .apbOut_5_PADDR           (s5_PADDR),
    .apbOut_5_PSEL            (s5_PSEL),
    .apbOut_5_PENABLE         (s5_PENABLE),
    .apbOut_5_PREADY          (s5_PREADY),
    .apbOut_5_PWRITE          (s5_PWRITE),
    .apbOut_5_PWDATA          (s5_PWDATA),
    .apbOut_5_PRDATA          (s5_PRDATA),
    .apbOut_5_PSLVERROR       (s5_PSLVERROR),

    // ---- 输出 6：去从设备 6 ----
    .apbOut_6_PADDR           (s6_PADDR),
    .apbOut_6_PSEL            (s6_PSEL),
    .apbOut_6_PENABLE         (s6_PENABLE),
    .apbOut_6_PREADY          (s6_PREADY),
    .apbOut_6_PWRITE          (s6_PWRITE),
    .apbOut_6_PWDATA          (s6_PWDATA),
    .apbOut_6_PRDATA          (s6_PRDATA),
    .apbOut_6_PSLVERROR       (s6_PSLVERROR),

    // ---- 输出 7：去从设备 7 ----
    .apbOut_7_PADDR           (s7_PADDR),
    .apbOut_7_PSEL            (s7_PSEL),
    .apbOut_7_PENABLE         (s7_PENABLE),
    .apbOut_7_PREADY          (s7_PREADY),
    .apbOut_7_PWRITE          (s7_PWRITE),
    .apbOut_7_PWDATA          (s7_PWDATA),
    .apbOut_7_PRDATA          (s7_PRDATA),
    .apbOut_7_PSLVERROR       (s7_PSLVERROR)
  );

  // ---------------------------------------------------------------- 判定
  localparam TIMEOUT = 20000;

  integer cyc = 0;
  reg     reported = 0;

  initial begin
    $display("");
    $display("================ APB3 crossbar simulation ================");
    $display("  master 0 : base=0x00000000 stride=0x20 seed=0x12340000");
    $display("  master 1 : base=0x00004000 stride=0x20 seed=0x12440000");
    $display("  4 rounds x 8 words: write the window, then read it back immediately");
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
        $finish;
      end else if (m0_done & m1_done) begin
        reported <= 1;
        $display("==== PASS ==== 2 masters x 4 rounds x 8 words, all read back identical (%0d cycles)", cyc);
        $finish;
      end else if (cyc > TIMEOUT) begin
        reported <= 1;
        $display("==== FAIL ==== timeout after %0d cycles: m0_done=%0d m1_done=%0d",
                 TIMEOUT, m0_done, m1_done);
        $finish;
      end
    end
  end

endmodule
