import radio_const_pkg::*;

module fir #(
  parameter DECIMATION = 1,
  parameter FIFO_DATA_WIDTH = 16,
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

  logic [FIFO_DATA_WIDTH-1:0] shift_reg [NUM_TAPS-1:0];
  logic signed [FIFO_DATA_WIDTH+32-1:0] mult_reg [NUM_TAPS-1:0];
  logic signed [63:0] accumulator;
  logic [3:0] decimation_counter;

  // Next state and output logic
  always_comb begin
    // default assignments
    next_state    = curr_state;
    rd_fifo_rd_en = 1'b0;
    wr_fifo_wr_en = 1'b0;

    case (curr_state)
      IDLE: begin
        if (!rd_fifo_empty)
          next_state = SHIFT;
      end

      SHIFT: begin
        next_state = READ;
      end

      READ: begin
        // First, check if the FIFO is empty.
        if (rd_fifo_empty) begin
          rd_fifo_rd_en = 1'b0;
          next_state    = READ; // Stay in READ if there's no data.
        end else begin
          // When data is available, assert the read enable.
          rd_fifo_rd_en = 1'b1;
          // Only increment the decimation counter after reading valid data.
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
        wr_fifo_wr_en = 1'b1;
        next_state = IDLE;
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
      wr_fifo_data_out   <= '0;
      for (int i = 0; i < NUM_TAPS; i++) begin
        shift_reg[i] <= '0;
      end
    end else begin
      curr_state <= next_state;
      case (curr_state)
        IDLE: begin
          // No action; waiting for new data.
        end

        SHIFT: begin
          // Shift the register by DECIMATION positions.
          for (int i = 0; i < NUM_TAPS - DECIMATION; i++) begin
            shift_reg[i] <= shift_reg[i + DECIMATION];
          end
          // Clear the tail where new data will be stored.
          for (int i = NUM_TAPS - DECIMATION; i < NUM_TAPS; i++) begin
            shift_reg[i] <= '0;
          end
          decimation_counter <= 0;
        end

        READ: begin
          // Only read new data if FIFO is not empty.
          if (!rd_fifo_empty) begin
            shift_reg[NUM_TAPS - DECIMATION + decimation_counter] <= rd_fifo_data_in;
            decimation_counter <= decimation_counter + 1;
          end
          // If FIFO is empty, remain in READ (next_state stays READ).
        end

        MULT: begin
          // Multiply each tap by its corresponding coefficient.
          for (int i = 0; i < NUM_TAPS; i++) begin
            mult_reg[i] <= $signed(shift_reg[i]) * COEFFS[i];
          end
        end

        ADD: begin
          // Accumulate all products.
          logic signed [63:0] sum;
          sum = '0;
          for (int i = 0; i < NUM_TAPS; i++) begin
            sum = sum + mult_reg[i];
          end
          accumulator <= sum;
        end

        DONE: begin
          // Output the filtered result to the write FIFO.
          wr_fifo_data_out <= accumulator[FIFO_DATA_WIDTH-1:0];
          decimation_counter <= 0;
        end

      endcase
    end
  end

endmodule