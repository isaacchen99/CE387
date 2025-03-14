import radio_const_pkg::*;

module fir #(
  parameter DECIMATION = 1,
  parameter FIFO_DATA_WIDTH = 32,
  parameter NUM_TAPS = 32,
  parameter logic signed [31:0] COEFFS [NUM_TAPS] = '{default:32'd0}
) (
  input  logic clk,
  input  logic rst,

  input  logic rd_fifo_empty,
  output logic rd_fifo_rd_en,
  input  logic [FIFO_DATA_WIDTH-1:0] rd_fifo_data_in,

  input  logic wr_fifo_full,
  output logic wr_fifo_wr_en,
  output logic [FIFO_DATA_WIDTH-1:0] wr_fifo_data_out
);

  // state declaration
  typedef enum logic [2:0] {IDLE, SHIFT, READ, MULT, ADD, DONE} state_t;
  state_t curr_state, next_state;

  logic [FIFO_DATA_WIDTH-1 : 0] shift_reg [NUM_TAPS-1:0];
  logic signed [FIFO_DATA_WIDTH-1 : 0] mult_reg [NUM_TAPS-1:0];
  logic signed [FIFO_DATA_WIDTH-1 : 0] accumulator;
  logic [3:0] decimation_counter;

  // Next state and output logic
  always_comb begin
    // default assignments
    next_state    = curr_state;
    rd_fifo_rd_en = 1'b0;
    wr_fifo_wr_en = 1'b0;
    wr_fifo_data_out = '0;

    case (curr_state)
      IDLE: begin
        if (!rd_fifo_empty)
          next_state = SHIFT;
      end

      SHIFT: begin
        next_state = READ;
      end

      READ: begin
        if (rd_fifo_empty) begin
          rd_fifo_rd_en = 1'b0;
          next_state    = READ;
        end else begin
          rd_fifo_rd_en = 1'b1;
          if (decimation_counter == (DECIMATION - 1))
            next_state = MULT;
          else
            next_state = READ;
        end
      end

      MULT: begin
        next_state = ADD;
      end

      ADD: begin
        next_state = DONE;
      end

      DONE: begin
        if (wr_fifo_full) begin
          next_state = DONE;
        end else begin
          wr_fifo_wr_en = 1'b1;
          wr_fifo_data_out = accumulator;
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Clocked logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      curr_state         <= IDLE;
      decimation_counter <= 0;
      accumulator        <= '0;
      for (int i = 0; i < NUM_TAPS; i++) begin
        shift_reg[i] <= '0;
      end
    end else begin
      curr_state <= next_state;
      case (curr_state)
        IDLE: begin
        end

        SHIFT: begin
          // shift by DECIMATION positions
          for (int i = 0; i < NUM_TAPS - DECIMATION; i++) begin
            shift_reg[i] <= shift_reg[i + DECIMATION];
          end
          // clear the last DECIMATION elements to 0
          for (int i = NUM_TAPS - DECIMATION; i < NUM_TAPS; i++) begin
            shift_reg[i] <= '0;
          end
          // reset counter
          decimation_counter <= 0;
        end

        READ: begin
          if (!rd_fifo_empty) begin
            shift_reg[NUM_TAPS - DECIMATION + decimation_counter] <= rd_fifo_data_in;
            decimation_counter <= decimation_counter + 1;
          end
        end

        MULT: begin
          for (int i = 0; i < NUM_TAPS; i++) begin
            mult_reg[i] <= $signed(shift_reg[i]) * COEFFS[i];
          end
        end

        ADD: begin
          logic signed [FIFO_DATA_WIDTH-1:0] sum;
          sum = '0;
          for (int i = 0; i < NUM_TAPS; i++) begin
            sum = sum + dequantize_i(mult_reg[i]);
          end
          accumulator <= sum;
        end

        DONE: begin
          decimation_counter <= 0;
        end

      endcase
    end
  end

endmodule