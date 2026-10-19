// Generator : SpinalHDL v1.10.1    git head : 2527c7c6b0fb0f95e5e1a5722a0be732b364ce43
// Component : Apb3Crossbar_2x8

`timescale 1ns/1ps

module Apb3Crossbar_2x8 (
  input  wire [31:0]   apbIn_0_PADDR,
  input  wire [0:0]    apbIn_0_PSEL,
  input  wire          apbIn_0_PENABLE,
  output wire          apbIn_0_PREADY,
  input  wire          apbIn_0_PWRITE,
  input  wire [31:0]   apbIn_0_PWDATA,
  output wire [31:0]   apbIn_0_PRDATA,
  output wire          apbIn_0_PSLVERROR,
  input  wire [31:0]   apbIn_1_PADDR,
  input  wire [0:0]    apbIn_1_PSEL,
  input  wire          apbIn_1_PENABLE,
  output wire          apbIn_1_PREADY,
  input  wire          apbIn_1_PWRITE,
  input  wire [31:0]   apbIn_1_PWDATA,
  output wire [31:0]   apbIn_1_PRDATA,
  output wire          apbIn_1_PSLVERROR,
  output wire [31:0]   apbOut_0_PADDR,
  output wire [0:0]    apbOut_0_PSEL,
  output wire          apbOut_0_PENABLE,
  input  wire          apbOut_0_PREADY,
  output wire          apbOut_0_PWRITE,
  output wire [31:0]   apbOut_0_PWDATA,
  input  wire [31:0]   apbOut_0_PRDATA,
  input  wire          apbOut_0_PSLVERROR,
  output wire [31:0]   apbOut_1_PADDR,
  output wire [0:0]    apbOut_1_PSEL,
  output wire          apbOut_1_PENABLE,
  input  wire          apbOut_1_PREADY,
  output wire          apbOut_1_PWRITE,
  output wire [31:0]   apbOut_1_PWDATA,
  input  wire [31:0]   apbOut_1_PRDATA,
  input  wire          apbOut_1_PSLVERROR,
  output wire [31:0]   apbOut_2_PADDR,
  output wire [0:0]    apbOut_2_PSEL,
  output wire          apbOut_2_PENABLE,
  input  wire          apbOut_2_PREADY,
  output wire          apbOut_2_PWRITE,
  output wire [31:0]   apbOut_2_PWDATA,
  input  wire [31:0]   apbOut_2_PRDATA,
  input  wire          apbOut_2_PSLVERROR,
  output wire [31:0]   apbOut_3_PADDR,
  output wire [0:0]    apbOut_3_PSEL,
  output wire          apbOut_3_PENABLE,
  input  wire          apbOut_3_PREADY,
  output wire          apbOut_3_PWRITE,
  output wire [31:0]   apbOut_3_PWDATA,
  input  wire [31:0]   apbOut_3_PRDATA,
  input  wire          apbOut_3_PSLVERROR,
  output wire [31:0]   apbOut_4_PADDR,
  output wire [0:0]    apbOut_4_PSEL,
  output wire          apbOut_4_PENABLE,
  input  wire          apbOut_4_PREADY,
  output wire          apbOut_4_PWRITE,
  output wire [31:0]   apbOut_4_PWDATA,
  input  wire [31:0]   apbOut_4_PRDATA,
  input  wire          apbOut_4_PSLVERROR,
  output wire [31:0]   apbOut_5_PADDR,
  output wire [0:0]    apbOut_5_PSEL,
  output wire          apbOut_5_PENABLE,
  input  wire          apbOut_5_PREADY,
  output wire          apbOut_5_PWRITE,
  output wire [31:0]   apbOut_5_PWDATA,
  input  wire [31:0]   apbOut_5_PRDATA,
  input  wire          apbOut_5_PSLVERROR,
  output wire [31:0]   apbOut_6_PADDR,
  output wire [0:0]    apbOut_6_PSEL,
  output wire          apbOut_6_PENABLE,
  input  wire          apbOut_6_PREADY,
  output wire          apbOut_6_PWRITE,
  output wire [31:0]   apbOut_6_PWDATA,
  input  wire [31:0]   apbOut_6_PRDATA,
  input  wire          apbOut_6_PSLVERROR,
  output wire [31:0]   apbOut_7_PADDR,
  output wire [0:0]    apbOut_7_PSEL,
  output wire          apbOut_7_PENABLE,
  input  wire          apbOut_7_PREADY,
  output wire          apbOut_7_PWRITE,
  output wire [31:0]   apbOut_7_PWDATA,
  input  wire [31:0]   apbOut_7_PRDATA,
  input  wire          apbOut_7_PSLVERROR,
  input  wire          clk,
  input  wire          resetn
);

  wire       [1:0]    _zz__zz_when_Apbcrossbar_l59_4;
  reg        [31:0]   _zz__zz_apbIn_0_PRDATA;
  reg                 _zz__zz_apbIn_0_PREADY_10;
  reg                 _zz__zz_apbIn_0_PSLVERROR;
  reg        [1:0]    _zz_when_Apbcrossbar_l164;
  wire                when_Apbcrossbar_l164;
  reg        [1:0]    _zz_when_Apbcrossbar_l59;
  reg        [1:0]    _zz_when_Apbcrossbar_l59_1;
  wire       [1:0]    _zz_when_Apbcrossbar_l59_2;
  wire       [1:0]    _zz_when_Apbcrossbar_l59_3;
  wire       [1:0]    _zz_when_Apbcrossbar_l59_4;
  reg        [1:0]    _zz_when_Apbcrossbar_l59_5;
  wire                when_Apbcrossbar_l59;
  reg        [1:0]    _zz_apbIn_0_PREADY;
  wire                when_Apbcrossbar_l169;
  wire                _zz_apbOut_0_PSEL;
  wire                _zz_apbOut_0_PADDR;
  wire       [31:0]   _zz_apbOut_0_PADDR_1;
  wire                _zz_apbOut_0_PWRITE;
  wire       [31:0]   _zz_apbOut_0_PWDATA;
  wire                _zz_apbOut_0_PENABLE;
  wire       [7:0]    _zz_apbOut_0_PSEL_1;
  reg        [7:0]    _zz_apbOut_0_PSEL_2;
  wire                _zz_apbIn_0_PREADY_1;
  reg        [7:0]    _zz_apbOut_0_PENABLE_1;
  wire                _zz_apbIn_0_PREADY_2;
  wire                _zz_apbIn_0_PREADY_3;
  wire                _zz_apbIn_0_PREADY_4;
  wire                _zz_apbIn_0_PREADY_5;
  wire                _zz_apbIn_0_PREADY_6;
  wire                _zz_apbIn_0_PREADY_7;
  wire                _zz_apbIn_0_PREADY_8;
  wire       [2:0]    _zz_apbIn_0_PREADY_9;
  wire       [31:0]   _zz_apbIn_0_PRDATA;
  wire                _zz_apbIn_0_PREADY_10;
  wire                _zz_apbIn_0_PSLVERROR;

  assign _zz__zz_when_Apbcrossbar_l59_4 = (_zz_when_Apbcrossbar_l59_3 - 2'b01);
  always @(*) begin
    case(_zz_apbIn_0_PREADY_9)
      3'b000 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_0_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_0_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_0_PSLVERROR;
      end
      3'b001 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_1_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_1_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_1_PSLVERROR;
      end
      3'b010 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_2_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_2_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_2_PSLVERROR;
      end
      3'b011 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_3_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_3_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_3_PSLVERROR;
      end
      3'b100 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_4_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_4_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_4_PSLVERROR;
      end
      3'b101 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_5_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_5_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_5_PSLVERROR;
      end
      3'b110 : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_6_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_6_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_6_PSLVERROR;
      end
      default : begin
        _zz__zz_apbIn_0_PRDATA = apbOut_7_PRDATA;
        _zz__zz_apbIn_0_PREADY_10 = apbOut_7_PREADY;
        _zz__zz_apbIn_0_PSLVERROR = apbOut_7_PSLVERROR;
      end
    endcase
  end

  assign when_Apbcrossbar_l164 = ((|_zz_when_Apbcrossbar_l164) && (_zz_when_Apbcrossbar_l164[0] ? apbIn_0_PSEL[0] : apbIn_1_PSEL[0]));
  always @(*) begin
    _zz_when_Apbcrossbar_l59[0] = (apbIn_0_PSEL[0] && (! when_Apbcrossbar_l164));
    _zz_when_Apbcrossbar_l59[1] = (apbIn_1_PSEL[0] && (! when_Apbcrossbar_l164));
  end

  assign _zz_when_Apbcrossbar_l59_2 = (_zz_when_Apbcrossbar_l59 & _zz_when_Apbcrossbar_l59_1);
  assign _zz_when_Apbcrossbar_l59_3 = ((|_zz_when_Apbcrossbar_l59_2) ? _zz_when_Apbcrossbar_l59_2 : _zz_when_Apbcrossbar_l59);
  assign _zz_when_Apbcrossbar_l59_4 = (_zz_when_Apbcrossbar_l59_3 & (~ _zz__zz_when_Apbcrossbar_l59_4));
  always @(*) begin
    _zz_when_Apbcrossbar_l59_5[0] = 1'b0;
    _zz_when_Apbcrossbar_l59_5[1] = (1'b0 || _zz_when_Apbcrossbar_l59_4[0]);
  end

  assign when_Apbcrossbar_l59 = (|_zz_when_Apbcrossbar_l59_4);
  always @(*) begin
    if(when_Apbcrossbar_l164) begin
      _zz_apbIn_0_PREADY = _zz_when_Apbcrossbar_l164;
    end else begin
      _zz_apbIn_0_PREADY = _zz_when_Apbcrossbar_l59_4;
    end
  end

  assign when_Apbcrossbar_l169 = (! when_Apbcrossbar_l164);
  assign _zz_apbOut_0_PSEL = (|_zz_apbIn_0_PREADY);
  assign _zz_apbOut_0_PADDR = _zz_apbIn_0_PREADY[0];
  assign _zz_apbOut_0_PADDR_1 = (_zz_apbOut_0_PADDR ? apbIn_0_PADDR : apbIn_1_PADDR);
  assign _zz_apbOut_0_PWRITE = (_zz_apbOut_0_PADDR ? apbIn_0_PWRITE : apbIn_1_PWRITE);
  assign _zz_apbOut_0_PWDATA = (_zz_apbOut_0_PADDR ? apbIn_0_PWDATA : apbIn_1_PWDATA);
  assign _zz_apbOut_0_PENABLE = (_zz_apbOut_0_PADDR ? apbIn_0_PENABLE : apbIn_1_PENABLE);
  assign _zz_apbOut_0_PSEL_1 = (_zz_apbOut_0_PADDR ? 8'hff : 8'hff);
  always @(*) begin
    _zz_apbOut_0_PSEL_2[0] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[0]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00000000));
    _zz_apbOut_0_PSEL_2[1] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[1]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00001000));
    _zz_apbOut_0_PSEL_2[2] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[2]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00002000));
    _zz_apbOut_0_PSEL_2[3] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[3]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00003000));
    _zz_apbOut_0_PSEL_2[4] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[4]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00004000));
    _zz_apbOut_0_PSEL_2[5] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[5]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00005000));
    _zz_apbOut_0_PSEL_2[6] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[6]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00006000));
    _zz_apbOut_0_PSEL_2[7] = ((_zz_apbOut_0_PSEL && _zz_apbOut_0_PSEL_1[7]) && ((_zz_apbOut_0_PADDR_1 & (~ 32'h00000fff)) == 32'h00007000));
  end

  assign _zz_apbIn_0_PREADY_1 = (|_zz_apbOut_0_PSEL_2);
  assign apbOut_0_PSEL[0] = _zz_apbOut_0_PSEL_2[0];
  assign apbOut_0_PENABLE = ((_zz_apbOut_0_PSEL_2[0] && _zz_apbOut_0_PENABLE_1[0]) && _zz_apbOut_0_PENABLE);
  assign apbOut_0_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_0_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_0_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_1_PSEL[0] = _zz_apbOut_0_PSEL_2[1];
  assign apbOut_1_PENABLE = ((_zz_apbOut_0_PSEL_2[1] && _zz_apbOut_0_PENABLE_1[1]) && _zz_apbOut_0_PENABLE);
  assign apbOut_1_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_1_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_1_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_2_PSEL[0] = _zz_apbOut_0_PSEL_2[2];
  assign apbOut_2_PENABLE = ((_zz_apbOut_0_PSEL_2[2] && _zz_apbOut_0_PENABLE_1[2]) && _zz_apbOut_0_PENABLE);
  assign apbOut_2_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_2_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_2_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_3_PSEL[0] = _zz_apbOut_0_PSEL_2[3];
  assign apbOut_3_PENABLE = ((_zz_apbOut_0_PSEL_2[3] && _zz_apbOut_0_PENABLE_1[3]) && _zz_apbOut_0_PENABLE);
  assign apbOut_3_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_3_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_3_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_4_PSEL[0] = _zz_apbOut_0_PSEL_2[4];
  assign apbOut_4_PENABLE = ((_zz_apbOut_0_PSEL_2[4] && _zz_apbOut_0_PENABLE_1[4]) && _zz_apbOut_0_PENABLE);
  assign apbOut_4_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_4_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_4_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_5_PSEL[0] = _zz_apbOut_0_PSEL_2[5];
  assign apbOut_5_PENABLE = ((_zz_apbOut_0_PSEL_2[5] && _zz_apbOut_0_PENABLE_1[5]) && _zz_apbOut_0_PENABLE);
  assign apbOut_5_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_5_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_5_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_6_PSEL[0] = _zz_apbOut_0_PSEL_2[6];
  assign apbOut_6_PENABLE = ((_zz_apbOut_0_PSEL_2[6] && _zz_apbOut_0_PENABLE_1[6]) && _zz_apbOut_0_PENABLE);
  assign apbOut_6_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_6_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_6_PWDATA = _zz_apbOut_0_PWDATA;
  assign apbOut_7_PSEL[0] = _zz_apbOut_0_PSEL_2[7];
  assign apbOut_7_PENABLE = ((_zz_apbOut_0_PSEL_2[7] && _zz_apbOut_0_PENABLE_1[7]) && _zz_apbOut_0_PENABLE);
  assign apbOut_7_PADDR = _zz_apbOut_0_PADDR_1;
  assign apbOut_7_PWRITE = _zz_apbOut_0_PWRITE;
  assign apbOut_7_PWDATA = _zz_apbOut_0_PWDATA;
  assign _zz_apbIn_0_PREADY_2 = _zz_apbOut_0_PSEL_2[3];
  assign _zz_apbIn_0_PREADY_3 = _zz_apbOut_0_PSEL_2[5];
  assign _zz_apbIn_0_PREADY_4 = _zz_apbOut_0_PSEL_2[6];
  assign _zz_apbIn_0_PREADY_5 = _zz_apbOut_0_PSEL_2[7];
  assign _zz_apbIn_0_PREADY_6 = (((_zz_apbOut_0_PSEL_2[1] || _zz_apbIn_0_PREADY_2) || _zz_apbIn_0_PREADY_3) || _zz_apbIn_0_PREADY_5);
  assign _zz_apbIn_0_PREADY_7 = (((_zz_apbOut_0_PSEL_2[2] || _zz_apbIn_0_PREADY_2) || _zz_apbIn_0_PREADY_4) || _zz_apbIn_0_PREADY_5);
  assign _zz_apbIn_0_PREADY_8 = (((_zz_apbOut_0_PSEL_2[4] || _zz_apbIn_0_PREADY_3) || _zz_apbIn_0_PREADY_4) || _zz_apbIn_0_PREADY_5);
  assign _zz_apbIn_0_PREADY_9 = {_zz_apbIn_0_PREADY_8,{_zz_apbIn_0_PREADY_7,_zz_apbIn_0_PREADY_6}};
  assign _zz_apbIn_0_PRDATA = _zz__zz_apbIn_0_PRDATA;
  assign _zz_apbIn_0_PREADY_10 = (_zz_apbIn_0_PREADY_1 ? _zz__zz_apbIn_0_PREADY_10 : 1'b1);
  assign _zz_apbIn_0_PSLVERROR = (_zz_apbIn_0_PREADY_1 ? _zz__zz_apbIn_0_PSLVERROR : 1'b1);
  assign apbIn_0_PRDATA = _zz_apbIn_0_PRDATA;
  assign apbIn_0_PREADY = ((apbIn_0_PSEL[0] && _zz_apbIn_0_PREADY[0]) && _zz_apbIn_0_PREADY_10);
  assign apbIn_0_PSLVERROR = ((apbIn_0_PSEL[0] && _zz_apbIn_0_PREADY[0]) && _zz_apbIn_0_PSLVERROR);
  assign apbIn_1_PRDATA = _zz_apbIn_0_PRDATA;
  assign apbIn_1_PREADY = ((apbIn_1_PSEL[0] && _zz_apbIn_0_PREADY[1]) && _zz_apbIn_0_PREADY_10);
  assign apbIn_1_PSLVERROR = ((apbIn_1_PSEL[0] && _zz_apbIn_0_PREADY[1]) && _zz_apbIn_0_PSLVERROR);
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      _zz_when_Apbcrossbar_l164 <= 2'b00;
      _zz_when_Apbcrossbar_l59_1 <= 2'b00;
      _zz_apbOut_0_PENABLE_1 <= 8'h00;
    end else begin
      if(when_Apbcrossbar_l59) begin
        _zz_when_Apbcrossbar_l59_1 <= _zz_when_Apbcrossbar_l59_5;
      end
      if(when_Apbcrossbar_l169) begin
        _zz_when_Apbcrossbar_l164 <= _zz_apbIn_0_PREADY;
      end
      _zz_apbOut_0_PENABLE_1 <= _zz_apbOut_0_PSEL_2;
    end
  end


endmodule
