import radio_const_pkg::*;

module multiply #(
  parameter FIFO_DATA_WIDTH = 16,
) (
  input logic clock,
  input logic reset,

  input logic [FIFO_DATA_WIDTH-1:0] rd_fifo_data_in_1,
  input logic rd_fifo_empty_1,
  output logic rd_fifo_rd_en_1,

  input logic [FIFO_DATA_WIDTH-1:0] rd_fifo_data_in_2,
  input logic rd_fifo_empty_2,
  output logic rd_fifo_rd_en_2,

  output logic [FIFO_DATA_WIDTH-1:0] wr_fifo_data_out,
  input logic wr_fifo_full,
  output logic wr_fifo_wr_en
);

// internal signals
typedef enum logic [2:0] {IDLE, CALC, PROC, WRITE} state_t;
state_t curr_state, next_state;
logic [FIFO_DATA_WIDTH+QUANTIZE_SIZE-1 : 0] product_ext;
logic [FIFO_DATA_WIDTH-1 : 0] product;

// next-state and output logic
always_comb begin
  // defaults: 
  next_state = curr_state;
  wr_fifo_wr_en = 1'b0;
  wr_fifo_data_out = '0;
  rd_fifo_rd_en_1 = 1'b0;
  rd_fifo_rd_en_2 = 1'b0;

  case (curr_state)

    IDLE: begin
      if (!rd_fifo_empty_1 && !rd_fifo_empty_2) begin
        next_state = CALC;
      end
    end

    CALC: begin
      next_state = PROC;
      rd_fifo_rd_en_1 = 1'b1;
      rd_fifo_rd_en_2 = 1'b1;
    end

    PROC: begin
      next_state = WRITE;
    end

    WRITE: begin
      next_state = IDLE;
      wr_fifo_wr_en = 1'b1;
      wr_fifo_data_out = product;
    end

  endcase
end

// clocked logic
always_ff @(posedge clock) begin
  if (reset) begin
    curr_state <= IDLE;
  end else begin
    curr_state <= next_state;
    case (curr_state)

      IDLE: begin

      end

      CALC: begin
        product_ext <= rd_fifo_data_in_1 * rd_fifo_data_in_2;
      end

      PROC: begin
        product <= dequantize_i(product_ext);
      end

      WRITE: begin

      end

    endcase
  end
end

endmodule