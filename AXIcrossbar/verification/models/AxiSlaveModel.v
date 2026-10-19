// Generator : SpinalHDL v1.10.1    git head : 2527c7c6b0fb0f95e5e1a5722a0be732b364ce43
// Component : AxiSlaveModel

`timescale 1ns/1ps

module AxiSlaveModel (
  input  wire          io_axi_aw_valid,
  output wire          io_axi_aw_ready,
  input  wire [31:0]   io_axi_aw_payload_addr,
  input  wire [4:0]    io_axi_aw_payload_id,
  input  wire [7:0]    io_axi_aw_payload_len,
  input  wire [2:0]    io_axi_aw_payload_size,
  input  wire [1:0]    io_axi_aw_payload_burst,
  input  wire [0:0]    io_axi_aw_payload_lock,
  input  wire [3:0]    io_axi_aw_payload_cache,
  input  wire [2:0]    io_axi_aw_payload_prot,
  input  wire          io_axi_w_valid,
  output wire          io_axi_w_ready,
  input  wire [31:0]   io_axi_w_payload_data,
  input  wire [3:0]    io_axi_w_payload_strb,
  input  wire          io_axi_w_payload_last,
  output wire          io_axi_b_valid,
  input  wire          io_axi_b_ready,
  output wire [4:0]    io_axi_b_payload_id,
  output wire [1:0]    io_axi_b_payload_resp,
  input  wire          io_axi_ar_valid,
  output wire          io_axi_ar_ready,
  input  wire [31:0]   io_axi_ar_payload_addr,
  input  wire [4:0]    io_axi_ar_payload_id,
  input  wire [7:0]    io_axi_ar_payload_len,
  input  wire [2:0]    io_axi_ar_payload_size,
  input  wire [1:0]    io_axi_ar_payload_burst,
  input  wire [0:0]    io_axi_ar_payload_lock,
  input  wire [3:0]    io_axi_ar_payload_cache,
  input  wire [2:0]    io_axi_ar_payload_prot,
  output wire          io_axi_r_valid,
  input  wire          io_axi_r_ready,
  output wire [31:0]   io_axi_r_payload_data,
  output wire [4:0]    io_axi_r_payload_id,
  output wire [1:0]    io_axi_r_payload_resp,
  output wire          io_axi_r_payload_last,
  input  wire          clk,
  input  wire          resetn
);

  reg        [31:0]   _zz_mem_port1;
  wire       [15:0]   _zz_mem_port;
  wire                _zz_mem_port_1;
  reg                 awValid;
  reg        [31:0]   awAddr;
  reg        [4:0]    awId;
  reg                 bValid;
  wire                when_AxiModels_l126;
  wire                when_AxiModels_l138;
  wire                when_AxiModels_l154;
  reg                 rValid;
  reg        [31:0]   rData;
  reg        [7:0]    rRemain;
  reg        [4:0]    rId;
  reg        [31:0]   rAddr;
  reg                 rIssue;
  reg                 rIssueD;
  wire       [15:0]   _zz_rPort;
  wire       [31:0]   rPort;
  wire                when_AxiModels_l192;
  wire                when_AxiModels_l204;
  wire                when_AxiModels_l205;
  reg [31:0] mem [0:65535];

  assign _zz_mem_port = awAddr[17 : 2];
  assign _zz_mem_port_1 = (io_axi_w_valid && io_axi_w_ready);
  always @(posedge clk) begin
    if(_zz_mem_port_1) begin
      mem[_zz_mem_port] <= io_axi_w_payload_data;
    end
  end

  always @(posedge clk) begin
    if(rIssue) begin
      _zz_mem_port1 <= mem[_zz_rPort];
    end
  end

  assign io_axi_aw_ready = ((! awValid) && (! bValid));
  assign when_AxiModels_l126 = (io_axi_aw_valid && io_axi_aw_ready);
  assign io_axi_w_ready = (awValid && (! bValid));
  assign when_AxiModels_l138 = (io_axi_w_valid && io_axi_w_ready);
  assign io_axi_b_valid = bValid;
  assign io_axi_b_payload_resp = 2'b00;
  assign io_axi_b_payload_id = awId;
  assign when_AxiModels_l154 = (bValid && io_axi_b_ready);
  assign _zz_rPort = rAddr[17 : 2];
  assign rPort = _zz_mem_port1;
  assign io_axi_ar_ready = (((! rValid) && (! rIssue)) && (! rIssueD));
  assign when_AxiModels_l192 = (io_axi_ar_valid && io_axi_ar_ready);
  assign when_AxiModels_l204 = (rValid && io_axi_r_ready);
  assign when_AxiModels_l205 = (rRemain == 8'h01);
  assign io_axi_r_valid = rValid;
  assign io_axi_r_payload_data = rData;
  assign io_axi_r_payload_resp = 2'b00;
  assign io_axi_r_payload_last = (rRemain == 8'h01);
  assign io_axi_r_payload_id = rId;
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      awValid <= 1'b0;
      awAddr <= 32'h00000000;
      awId <= 5'h00;
      bValid <= 1'b0;
      rValid <= 1'b0;
      rData <= 32'h00000000;
      rRemain <= 8'h00;
      rId <= 5'h00;
      rAddr <= 32'h00000000;
      rIssue <= 1'b0;
      rIssueD <= 1'b0;
    end else begin
      if(when_AxiModels_l126) begin
        awValid <= 1'b1;
        awAddr <= io_axi_aw_payload_addr;
        awId <= io_axi_aw_payload_id;
      end
      if(when_AxiModels_l138) begin
        if(io_axi_w_payload_last) begin
          awValid <= 1'b0;
          bValid <= 1'b1;
        end else begin
          awAddr <= (awAddr + 32'h00000004);
        end
      end
      if(when_AxiModels_l154) begin
        bValid <= 1'b0;
      end
      rIssueD <= rIssue;
      rIssue <= 1'b0;
      if(when_AxiModels_l192) begin
        rAddr <= io_axi_ar_payload_addr;
        rIssue <= 1'b1;
        rRemain <= (io_axi_ar_payload_len + 8'h01);
        rId <= io_axi_ar_payload_id;
      end
      if(rIssueD) begin
        rData <= rPort;
        rValid <= 1'b1;
      end
      if(when_AxiModels_l204) begin
        if(when_AxiModels_l205) begin
          rValid <= 1'b0;
        end else begin
          rRemain <= (rRemain - 8'h01);
          rAddr <= (rAddr + 32'h00000004);
          rIssue <= 1'b1;
          rValid <= 1'b0;
        end
      end
    end
  end


endmodule
