// Generator : SpinalHDL v1.10.1    git head : 2527c7c6b0fb0f95e5e1a5722a0be732b364ce43
// Component : ApbMasterModel

`timescale 1ns/1ps

module ApbMasterModel (
  output reg  [31:0]   io_apb_PADDR,
  output reg  [0:0]    io_apb_PSEL,
  output reg           io_apb_PENABLE,
  input  wire          io_apb_PREADY,
  output reg           io_apb_PWRITE,
  output reg  [31:0]   io_apb_PWDATA,
  input  wire [31:0]   io_apb_PRDATA,
  input  wire          io_apb_PSLVERROR,
  input  wire [31:0]   io_base,
  input  wire [31:0]   io_stride,
  input  wire [31:0]   io_seed,
  output wire          io_busy,
  output wire          io_error,
  output wire          io_done,
  input  wire          clk,
  input  wire          resetn
);
  localparam St_IDLE = 2'd0;
  localparam St_SETUP = 2'd1;
  localparam St_ACCESS_1 = 2'd2;
  localparam St_GAP = 2'd3;

  wire       [31:0]   _zz_io_apb_PADDR;
  wire       [47:0]   _zz_io_apb_PADDR_1;
  wire       [47:0]   _zz_io_apb_PADDR_2;
  wire       [47:0]   _zz_io_apb_PADDR_3;
  wire       [31:0]   _zz_io_apb_PADDR_4;
  wire       [10:0]   _zz_io_apb_PADDR_5;
  wire       [31:0]   _zz_io_apb_PWDATA;
  wire       [31:0]   _zz_io_apb_PWDATA_1;
  wire       [31:0]   _zz_io_apb_PWDATA_2;
  wire       [19:0]   _zz_io_apb_PWDATA_3;
  wire       [31:0]   _zz_io_apb_PWDATA_4;
  wire       [31:0]   _zz_io_apb_PADDR_6;
  wire       [47:0]   _zz_io_apb_PADDR_7;
  wire       [47:0]   _zz_io_apb_PADDR_8;
  wire       [47:0]   _zz_io_apb_PADDR_9;
  wire       [31:0]   _zz_io_apb_PADDR_10;
  wire       [10:0]   _zz_io_apb_PADDR_11;
  wire       [31:0]   _zz_io_apb_PWDATA_5;
  wire       [31:0]   _zz_io_apb_PWDATA_6;
  wire       [31:0]   _zz_io_apb_PWDATA_7;
  wire       [19:0]   _zz_io_apb_PWDATA_8;
  wire       [31:0]   _zz_io_apb_PWDATA_9;
  wire       [31:0]   _zz_when_ApbModels_l174;
  wire       [31:0]   _zz_when_ApbModels_l174_1;
  wire       [31:0]   _zz_when_ApbModels_l174_2;
  wire       [19:0]   _zz_when_ApbModels_l174_3;
  wire       [31:0]   _zz_when_ApbModels_l174_4;
  reg        [1:0]    state;
  reg        [15:0]   round;
  reg        [7:0]    idx;
  reg                 wrPhase;
  reg        [15:0]   errCnt;
  reg                 doneR;
  reg                 errorR;
  wire                when_ApbModels_l149;
  wire                when_ApbModels_l174;
  wire                when_ApbModels_l184;
  wire                when_ApbModels_l190;
  `ifndef SYNTHESIS
  reg [63:0] state_string;
  `endif


  assign _zz_io_apb_PADDR_1 = (_zz_io_apb_PADDR_2 + _zz_io_apb_PADDR_3);
  assign _zz_io_apb_PADDR = _zz_io_apb_PADDR_1[31:0];
  assign _zz_io_apb_PADDR_2 = {16'd0, io_base};
  assign _zz_io_apb_PADDR_3 = (io_stride * round);
  assign _zz_io_apb_PADDR_5 = (idx * 3'b100);
  assign _zz_io_apb_PADDR_4 = {21'd0, _zz_io_apb_PADDR_5};
  assign _zz_io_apb_PWDATA = (_zz_io_apb_PWDATA_1 + _zz_io_apb_PWDATA_4);
  assign _zz_io_apb_PWDATA_1 = (io_seed + _zz_io_apb_PWDATA_2);
  assign _zz_io_apb_PWDATA_3 = ({4'd0,round} <<< 3'd4);
  assign _zz_io_apb_PWDATA_2 = {12'd0, _zz_io_apb_PWDATA_3};
  assign _zz_io_apb_PWDATA_4 = {24'd0, idx};
  assign _zz_io_apb_PADDR_7 = (_zz_io_apb_PADDR_8 + _zz_io_apb_PADDR_9);
  assign _zz_io_apb_PADDR_6 = _zz_io_apb_PADDR_7[31:0];
  assign _zz_io_apb_PADDR_8 = {16'd0, io_base};
  assign _zz_io_apb_PADDR_9 = (io_stride * round);
  assign _zz_io_apb_PADDR_11 = (idx * 3'b100);
  assign _zz_io_apb_PADDR_10 = {21'd0, _zz_io_apb_PADDR_11};
  assign _zz_io_apb_PWDATA_5 = (_zz_io_apb_PWDATA_6 + _zz_io_apb_PWDATA_9);
  assign _zz_io_apb_PWDATA_6 = (io_seed + _zz_io_apb_PWDATA_7);
  assign _zz_io_apb_PWDATA_8 = ({4'd0,round} <<< 3'd4);
  assign _zz_io_apb_PWDATA_7 = {12'd0, _zz_io_apb_PWDATA_8};
  assign _zz_io_apb_PWDATA_9 = {24'd0, idx};
  assign _zz_when_ApbModels_l174 = (_zz_when_ApbModels_l174_1 + _zz_when_ApbModels_l174_4);
  assign _zz_when_ApbModels_l174_1 = (io_seed + _zz_when_ApbModels_l174_2);
  assign _zz_when_ApbModels_l174_3 = ({4'd0,round} <<< 3'd4);
  assign _zz_when_ApbModels_l174_2 = {12'd0, _zz_when_ApbModels_l174_3};
  assign _zz_when_ApbModels_l174_4 = {24'd0, idx};
  `ifndef SYNTHESIS
  always @(*) begin
    case(state)
      St_IDLE : state_string = "IDLE    ";
      St_SETUP : state_string = "SETUP   ";
      St_ACCESS_1 : state_string = "ACCESS_1";
      St_GAP : state_string = "GAP     ";
      default : state_string = "????????";
    endcase
  end
  `endif

  assign io_error = errorR;
  assign io_done = doneR;
  assign io_busy = (state != St_IDLE);
  always @(*) begin
    io_apb_PSEL = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_SETUP : begin
        io_apb_PSEL = 1'b1;
      end
      St_ACCESS_1 : begin
        io_apb_PSEL = 1'b1;
      end
      default : begin
        io_apb_PSEL = 1'b0;
      end
    endcase
  end

  always @(*) begin
    io_apb_PENABLE = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_SETUP : begin
        io_apb_PENABLE = 1'b0;
      end
      St_ACCESS_1 : begin
        io_apb_PENABLE = 1'b1;
      end
      default : begin
        io_apb_PENABLE = 1'b0;
      end
    endcase
  end

  always @(*) begin
    io_apb_PADDR = 32'h00000000;
    case(state)
      St_IDLE : begin
      end
      St_SETUP : begin
        io_apb_PADDR = (_zz_io_apb_PADDR + _zz_io_apb_PADDR_4);
      end
      St_ACCESS_1 : begin
        io_apb_PADDR = (_zz_io_apb_PADDR_6 + _zz_io_apb_PADDR_10);
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_apb_PWRITE = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_SETUP : begin
        io_apb_PWRITE = wrPhase;
      end
      St_ACCESS_1 : begin
        io_apb_PWRITE = wrPhase;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_apb_PWDATA = 32'h00000000;
    case(state)
      St_IDLE : begin
      end
      St_SETUP : begin
        io_apb_PWDATA = _zz_io_apb_PWDATA;
      end
      St_ACCESS_1 : begin
        io_apb_PWDATA = _zz_io_apb_PWDATA_5;
      end
      default : begin
      end
    endcase
  end

  assign when_ApbModels_l149 = (! doneR);
  assign when_ApbModels_l174 = ((! wrPhase) && (io_apb_PRDATA != _zz_when_ApbModels_l174));
  assign when_ApbModels_l184 = (idx == 8'h07);
  assign when_ApbModels_l190 = (round == 16'h0003);
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      state <= St_IDLE;
      round <= 16'h0000;
      idx <= 8'h00;
      wrPhase <= 1'b1;
      errCnt <= 16'h0000;
      doneR <= 1'b0;
      errorR <= 1'b0;
    end else begin
      errorR <= (errorR || (errCnt != 16'h0000));
      case(state)
        St_IDLE : begin
          if(when_ApbModels_l149) begin
            state <= St_SETUP;
            round <= 16'h0000;
            idx <= 8'h00;
            wrPhase <= 1'b1;
          end
        end
        St_SETUP : begin
          state <= St_ACCESS_1;
        end
        St_ACCESS_1 : begin
          if(io_apb_PREADY) begin
            if(when_ApbModels_l174) begin
              errCnt <= (errCnt + 16'h0001);
            end
            state <= St_GAP;
          end
        end
        default : begin
          if(when_ApbModels_l184) begin
            if(wrPhase) begin
              wrPhase <= 1'b0;
              idx <= 8'h00;
            end else begin
              if(when_ApbModels_l190) begin
                doneR <= 1'b1;
              end else begin
                round <= (round + 16'h0001);
                idx <= 8'h00;
                wrPhase <= 1'b1;
              end
            end
          end else begin
            idx <= (idx + 8'h01);
          end
        end
      endcase
    end
  end


endmodule
