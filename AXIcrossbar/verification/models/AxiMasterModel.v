// Generator : SpinalHDL v1.10.1    git head : 2527c7c6b0fb0f95e5e1a5722a0be732b364ce43
// Component : AxiMasterModel

`timescale 1ns/1ps

module AxiMasterModel (
  output reg           io_axi_aw_valid,
  input  wire          io_axi_aw_ready,
  output reg  [31:0]   io_axi_aw_payload_addr,
  output reg  [3:0]    io_axi_aw_payload_id,
  output reg  [7:0]    io_axi_aw_payload_len,
  output reg  [2:0]    io_axi_aw_payload_size,
  output reg  [1:0]    io_axi_aw_payload_burst,
  output wire [0:0]    io_axi_aw_payload_lock,
  output wire [3:0]    io_axi_aw_payload_cache,
  output wire [2:0]    io_axi_aw_payload_prot,
  output reg           io_axi_w_valid,
  input  wire          io_axi_w_ready,
  output reg  [31:0]   io_axi_w_payload_data,
  output reg  [3:0]    io_axi_w_payload_strb,
  output reg           io_axi_w_payload_last,
  input  wire          io_axi_b_valid,
  output reg           io_axi_b_ready,
  input  wire [3:0]    io_axi_b_payload_id,
  input  wire [1:0]    io_axi_b_payload_resp,
  output reg           io_axi_ar_valid,
  input  wire          io_axi_ar_ready,
  output reg  [31:0]   io_axi_ar_payload_addr,
  output reg  [3:0]    io_axi_ar_payload_id,
  output reg  [7:0]    io_axi_ar_payload_len,
  output reg  [2:0]    io_axi_ar_payload_size,
  output reg  [1:0]    io_axi_ar_payload_burst,
  output wire [0:0]    io_axi_ar_payload_lock,
  output wire [3:0]    io_axi_ar_payload_cache,
  output wire [2:0]    io_axi_ar_payload_prot,
  input  wire          io_axi_r_valid,
  output reg           io_axi_r_ready,
  input  wire [31:0]   io_axi_r_payload_data,
  input  wire [3:0]    io_axi_r_payload_id,
  input  wire [1:0]    io_axi_r_payload_resp,
  input  wire          io_axi_r_payload_last,
  input  wire [31:0]   io_base,
  input  wire [31:0]   io_stride,
  input  wire [31:0]   io_seed,
  input  wire [3:0]    io_id,
  output wire          io_busy,
  output wire          io_error,
  output wire          io_done,
  input  wire          clk,
  input  wire          resetn
);
  localparam St_IDLE = 3'd0;
  localparam St_AW = 3'd1;
  localparam St_W = 3'd2;
  localparam St_B = 3'd3;
  localparam St_AR = 3'd4;
  localparam St_R = 3'd5;
  localparam St_NEXT_1 = 3'd6;

  wire       [47:0]   _zz_addrR;
  wire       [47:0]   _zz_addrR_1;
  wire       [47:0]   _zz_addrR_2;
  wire       [31:0]   _zz_io_axi_w_payload_data;
  wire       [31:0]   _zz_io_axi_w_payload_data_1;
  wire       [31:0]   _zz_io_axi_w_payload_data_2;
  wire       [23:0]   _zz_io_axi_w_payload_data_3;
  wire       [31:0]   _zz_io_axi_w_payload_data_4;
  wire       [47:0]   _zz_addrR_3;
  wire       [47:0]   _zz_addrR_4;
  wire       [47:0]   _zz_addrR_5;
  wire       [31:0]   _zz_when_AxiModels_l348;
  wire       [31:0]   _zz_when_AxiModels_l348_1;
  wire       [31:0]   _zz_when_AxiModels_l348_2;
  wire       [23:0]   _zz_when_AxiModels_l348_3;
  wire       [31:0]   _zz_when_AxiModels_l348_4;
  wire       [47:0]   _zz_addrR_6;
  wire       [47:0]   _zz_addrR_7;
  wire       [47:0]   _zz_addrR_8;
  wire       [15:0]   _zz_addrR_9;
  reg        [2:0]    state;
  reg        [15:0]   round;
  reg        [7:0]    beatR;
  reg        [31:0]   addrR;
  reg        [15:0]   errCnt;
  reg                 doneR;
  reg                 errorR;
  wire                when_AxiModels_l289;
  wire                when_AxiModels_l315;
  wire                when_AxiModels_l348;
  wire                when_AxiModels_l351;
  wire                when_AxiModels_l360;
  `ifndef SYNTHESIS
  reg [47:0] state_string;
  `endif


  assign _zz_addrR = (_zz_addrR_1 + _zz_addrR_2);
  assign _zz_addrR_1 = {16'd0, io_base};
  assign _zz_addrR_2 = (io_stride * round);
  assign _zz_io_axi_w_payload_data = (_zz_io_axi_w_payload_data_1 + _zz_io_axi_w_payload_data_4);
  assign _zz_io_axi_w_payload_data_1 = (io_seed + _zz_io_axi_w_payload_data_2);
  assign _zz_io_axi_w_payload_data_3 = ({8'd0,round} <<< 4'd8);
  assign _zz_io_axi_w_payload_data_2 = {8'd0, _zz_io_axi_w_payload_data_3};
  assign _zz_io_axi_w_payload_data_4 = {24'd0, beatR};
  assign _zz_addrR_3 = (_zz_addrR_4 + _zz_addrR_5);
  assign _zz_addrR_4 = {16'd0, io_base};
  assign _zz_addrR_5 = (io_stride * round);
  assign _zz_when_AxiModels_l348 = (_zz_when_AxiModels_l348_1 + _zz_when_AxiModels_l348_4);
  assign _zz_when_AxiModels_l348_1 = (io_seed + _zz_when_AxiModels_l348_2);
  assign _zz_when_AxiModels_l348_3 = ({8'd0,round} <<< 4'd8);
  assign _zz_when_AxiModels_l348_2 = {8'd0, _zz_when_AxiModels_l348_3};
  assign _zz_when_AxiModels_l348_4 = {24'd0, beatR};
  assign _zz_addrR_6 = (_zz_addrR_7 + _zz_addrR_8);
  assign _zz_addrR_7 = {16'd0, io_base};
  assign _zz_addrR_8 = (io_stride * _zz_addrR_9);
  assign _zz_addrR_9 = (round + 16'h0001);
  `ifndef SYNTHESIS
  always @(*) begin
    case(state)
      St_IDLE : state_string = "IDLE  ";
      St_AW : state_string = "AW    ";
      St_W : state_string = "W     ";
      St_B : state_string = "B     ";
      St_AR : state_string = "AR    ";
      St_R : state_string = "R     ";
      St_NEXT_1 : state_string = "NEXT_1";
      default : state_string = "??????";
    endcase
  end
  `endif

  assign io_error = errorR;
  assign io_done = doneR;
  assign io_busy = (state != St_IDLE);
  always @(*) begin
    io_axi_aw_valid = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
        io_axi_aw_valid = 1'b1;
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_aw_payload_addr = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
        io_axi_aw_payload_addr = addrR;
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_aw_payload_id = 4'bxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
        io_axi_aw_payload_id = io_id;
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_aw_payload_len = 8'bxxxxxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
        io_axi_aw_payload_len = 8'h03;
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_aw_payload_size = 3'bxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
        io_axi_aw_payload_size = 3'b010;
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_aw_payload_burst = 2'bxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
        io_axi_aw_payload_burst = 2'b01;
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  assign io_axi_aw_payload_lock = 1'bx;
  assign io_axi_aw_payload_cache = 4'bxxxx;
  assign io_axi_aw_payload_prot = 3'bxxx;
  always @(*) begin
    io_axi_w_valid = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
        io_axi_w_valid = 1'b1;
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_w_payload_data = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
        io_axi_w_payload_data = _zz_io_axi_w_payload_data;
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_w_payload_strb = 4'bxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
        io_axi_w_payload_strb = 4'b1111;
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_w_payload_last = 1'bx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
        io_axi_w_payload_last = (beatR == 8'h03);
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_b_ready = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
        io_axi_b_ready = 1'b1;
      end
      St_AR : begin
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_ar_valid = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
        io_axi_ar_valid = 1'b1;
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_ar_payload_addr = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
        io_axi_ar_payload_addr = addrR;
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_ar_payload_id = 4'bxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
        io_axi_ar_payload_id = io_id;
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_ar_payload_len = 8'bxxxxxxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
        io_axi_ar_payload_len = 8'h03;
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_ar_payload_size = 3'bxxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
        io_axi_ar_payload_size = 3'b010;
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_axi_ar_payload_burst = 2'bxx;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
        io_axi_ar_payload_burst = 2'b01;
      end
      St_R : begin
      end
      default : begin
      end
    endcase
  end

  assign io_axi_ar_payload_lock = 1'bx;
  assign io_axi_ar_payload_cache = 4'bxxxx;
  assign io_axi_ar_payload_prot = 3'bxxx;
  always @(*) begin
    io_axi_r_ready = 1'b0;
    case(state)
      St_IDLE : begin
      end
      St_AW : begin
      end
      St_W : begin
      end
      St_B : begin
      end
      St_AR : begin
      end
      St_R : begin
        io_axi_r_ready = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign when_AxiModels_l289 = (! doneR);
  assign when_AxiModels_l315 = (beatR == 8'h03);
  assign when_AxiModels_l348 = (io_axi_r_payload_data != _zz_when_AxiModels_l348);
  assign when_AxiModels_l351 = (beatR == 8'h03);
  assign when_AxiModels_l360 = (round == 16'h0007);
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      state <= St_IDLE;
      round <= 16'h0000;
      beatR <= 8'h00;
      addrR <= 32'h00000000;
      errCnt <= 16'h0000;
      doneR <= 1'b0;
      errorR <= 1'b0;
    end else begin
      errorR <= (errorR || (errCnt != 16'h0000));
      case(state)
        St_IDLE : begin
          if(when_AxiModels_l289) begin
            state <= St_AW;
            beatR <= 8'h00;
            addrR <= _zz_addrR[31:0];
          end
        end
        St_AW : begin
          if(io_axi_aw_ready) begin
            state <= St_W;
            beatR <= 8'h00;
          end
        end
        St_W : begin
          if(io_axi_w_ready) begin
            if(when_AxiModels_l315) begin
              state <= St_B;
            end else begin
              beatR <= (beatR + 8'h01);
            end
          end
        end
        St_B : begin
          if(io_axi_b_valid) begin
            state <= St_AR;
            beatR <= 8'h00;
            addrR <= _zz_addrR_3[31:0];
          end
        end
        St_AR : begin
          if(io_axi_ar_ready) begin
            state <= St_R;
            beatR <= 8'h00;
          end
        end
        St_R : begin
          if(io_axi_r_valid) begin
            if(when_AxiModels_l348) begin
              errCnt <= (errCnt + 16'h0001);
            end
            if(when_AxiModels_l351) begin
              state <= St_NEXT_1;
            end else begin
              beatR <= (beatR + 8'h01);
            end
          end
        end
        default : begin
          if(when_AxiModels_l360) begin
            doneR <= 1'b1;
            state <= St_IDLE;
          end else begin
            round <= (round + 16'h0001);
            state <= St_AW;
            beatR <= 8'h00;
            addrR <= _zz_addrR_6[31:0];
          end
        end
      endcase
    end
  end


endmodule
