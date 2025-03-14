import radio_const_pkg::*;

module fir_cmplx #(
  parameter DECIMATION = 1,
  parameter FIFO_DATA_WIDTH = 32,
  parameter NUM_TAPS = 32,
  parameter logic signed [31:0] COEFFS_REAL [NUM_TAPS] = '{default:32'd0},
  parameter logic signed [31:0] COEFFS_IMAG [NUM_TAPS] = '{default:32'd0}
) (
  input  logic clk,
  input  logic rst,

  // FIFO interface for the real input channel
  input  logic rd_fifo_empty_real,
  output logic rd_fifo_rd_en_real,
  input  logic [FIFO_DATA_WIDTH-1:0] rd_fifo_data_in_real,

  // FIFO interface for the imaginary input channel
  input  logic rd_fifo_empty_imag,
  output logic rd_fifo_rd_en_imag,
  input  logic [FIFO_DATA_WIDTH-1:0] rd_fifo_data_in_imag,

  // FIFO interface for the real output channel
  input  logic wr_fifo_full_real,
  output logic wr_fifo_wr_en_real,
  output logic [FIFO_DATA_WIDTH-1:0] wr_fifo_data_out_real,

  // FIFO interface for the imaginary output channel
  input  logic wr_fifo_full_imag,
  output logic wr_fifo_wr_en_imag,
  output logic [FIFO_DATA_WIDTH-1:0] wr_fifo_data_out_imag
);

  typedef enum logic [2:0] {IDLE, SHIFT, READ, MULT, ADD, DONE} state_t;
  state_t curr_state, next_state;

  logic [FIFO_DATA_WIDTH-1:0] shift_reg_real [NUM_TAPS-1:0];
  logic [FIFO_DATA_WIDTH-1:0] shift_reg_imag [NUM_TAPS-1:0];

  logic signed [FIFO_DATA_WIDTH-1:0] mult_reg_real [NUM_TAPS-1:0];
  logic signed [FIFO_DATA_WIDTH-1:0] mult_reg_imag [NUM_TAPS-1:0];

  logic signed [FIFO_DATA_WIDTH-1:0] accumulator_real;
  logic signed [FIFO_DATA_WIDTH-1:0] accumulator_imag;
  
  // Decimation counter
  logic [3:0] decimation_counter;

  // Next state and output logic
  always_comb begin
    // default assignments
    next_state            = curr_state;
    rd_fifo_rd_en_real    = 1'b0;
    rd_fifo_rd_en_imag    = 1'b0;
    wr_fifo_wr_en_real    = 1'b0;
    wr_fifo_wr_en_imag    = 1'b0;
    wr_fifo_data_out_real = '0;
    wr_fifo_data_out_imag = '0;

    case (curr_state)
      IDLE: begin
        // Wait until both FIFOs have data
        if (!rd_fifo_empty_real && !rd_fifo_empty_imag)
          next_state = SHIFT;
      end

      SHIFT: begin
        next_state = READ;
      end

      READ: begin
        if (rd_fifo_empty_real || rd_fifo_empty_imag) begin
          next_state = READ;
        end else begin
          rd_fifo_rd_en_real = 1'b1;
          rd_fifo_rd_en_imag = 1'b1;
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
        if (wr_fifo_full_imag || wr_fifo_full_real) begin
          next_state = DONE;
        end else begin
          wr_fifo_wr_en_real = 1'b1;
          wr_fifo_wr_en_imag = 1'b1;
          wr_fifo_data_out_real = accumulator_real;
          wr_fifo_data_out_imag = accumulator_imag;
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Clocked logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      curr_state            <= IDLE;
      decimation_counter    <= 0;
      accumulator_real      <= '0;
      accumulator_imag      <= '0;
      for (int i = 0; i < NUM_TAPS; i++) begin
        shift_reg_real[i] <= '0;
        shift_reg_imag[i] <= '0;
      end
    end else begin
      curr_state <= next_state;
      case (curr_state)
        IDLE: begin
          // No operations in IDLE
        end

        SHIFT: begin
          // Shift the registers by DECIMATION positions (for both real and imag)
          for (int i = 0; i < NUM_TAPS - DECIMATION; i++) begin
            shift_reg_real[i] <= shift_reg_real[i + DECIMATION];
            shift_reg_imag[i] <= shift_reg_imag[i + DECIMATION];
          end
          // Clear the last DECIMATION elements
          for (int i = NUM_TAPS - DECIMATION; i < NUM_TAPS; i++) begin
            shift_reg_real[i] <= '0;
            shift_reg_imag[i] <= '0;
          end
          decimation_counter <= 0;
        end

        READ: begin
          if (!rd_fifo_empty_real && !rd_fifo_empty_imag) begin
            // Load new real and imaginary samples into the shift registers
            shift_reg_real[NUM_TAPS - DECIMATION + decimation_counter] <= rd_fifo_data_in_real;
            shift_reg_imag[NUM_TAPS - DECIMATION + decimation_counter] <= rd_fifo_data_in_imag;
            decimation_counter <= decimation_counter + 1;
          end
        end

        MULT: begin
          // Perform complex multiplications for each tap.
          // Standard complex multiplication: (a+jb)*(c+jd) = (ac - bd) + j(ad + bc)
          for (int i = 0; i < NUM_TAPS; i++) begin
            mult_reg_real[i] <= $signed(shift_reg_real[i]) * COEFFS_REAL[i]
                                - $signed(shift_reg_imag[i]) * COEFFS_IMAG[i];
            mult_reg_imag[i] <= $signed(shift_reg_real[i]) * COEFFS_IMAG[i]
                                + $signed(shift_reg_imag[i]) * COEFFS_REAL[i];
          end
        end

        ADD: begin
          logic signed [FIFO_DATA_WIDTH-1:0] sum_real;
          logic signed [FIFO_DATA_WIDTH-1:0] sum_imag;
          sum_real = '0;
          sum_imag = '0;
          // Accumulate the multiplication results for both channels
          for (int i = 0; i < NUM_TAPS; i++) begin
            sum_real = sum_real + dequantize_i(mult_reg_real[i]);
            sum_imag = sum_imag + dequantize_i(mult_reg_imag[i]);
          end
          accumulator_real <= sum_real;
          accumulator_imag <= sum_imag;
        end

        DONE: begin
          decimation_counter <= 0;
        end

      endcase
    end
  end

endmodule