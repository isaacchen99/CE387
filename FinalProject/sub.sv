import radio_const_pkg::*;

module sub #(
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
typedef enum logic [2:0] {IDLE, CALC, WRITE} state_t;
state_t curr_state, next_state;
logic [FIFO_DATA_WIDTH-1 : 0] diff;

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
      next_state = WRITE;
      rd_fifo_rd_en_1 = 1'b1;
      rd_fifo_rd_en_2 = 1'b1;
    end

    WRITE: begin
      next_state = IDLE;
      wr_fifo_wr_en = 1'b1;
      wr_fifo_data_out = diff;
    end

  endcase
end

// clocked logic
always_ff @(posedge clock) begin
  if (reset) begin
    curr_state <= IDLE;
    diff <= '0;
  end else begin
    curr_state <= next_state;
    case (curr_state)

      IDLE: begin

      end

      CALC: begin
        diff <= rd_fifo_data_in_1 - rd_fifo_data_in_2;
      end

      WRITE: begin

      end

    endcase
  end
end

endmodule