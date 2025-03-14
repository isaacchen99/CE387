import radio_const_pkg::*;

module read_iq #(
  parameter FIFO_DATA_WIDTH = 32
)
(
  input  logic                clock,
  input  logic                reset,

  // Read FIFO interface (8-bit wide)
  input  logic [7:0]          rd_fifo_data_in,
  input  logic                rd_fifo_empty,
  output logic                rd_fifo_rd_en,

  // Write FIFO for I channel
  output logic [FIFO_DATA_WIDTH-1:0] wr_fifo_data_out_I,
  output logic                wr_fifo_wr_en_I,
  input  logic                wr_fifo_full_I,

  // Write FIFO for Q channel
  output logic [FIFO_DATA_WIDTH-1:0] wr_fifo_data_out_Q,
  output logic                wr_fifo_wr_en_Q,
  input  logic                wr_fifo_full_Q
);

  // State declaration: three states – IDLE, CALC, WRITE
  typedef enum logic [1:0] {IDLE, CALC, WRITE} state_t;
  state_t curr_state, next_state;

  // Register to store the 32-bit word assembled from 4 bytes read from the FIFO.
  logic [FIFO_DATA_WIDTH-1:0] fifo_word;

  // 2-bit counter to count the number of bytes read (0 to 3).
  logic [1:0] byte_cnt;

  // Combinational state and output logic.
  always_comb begin
    // Default assignments.
    rd_fifo_rd_en       = 1'b0;
    wr_fifo_wr_en_I     = 1'b0;
    wr_fifo_wr_en_Q     = 1'b0;
    wr_fifo_data_out_I  = '0;
    wr_fifo_data_out_Q  = '0;
    next_state          = curr_state;

    case (curr_state)
      IDLE: begin
        // Wait for data to become available.
        if (!rd_fifo_empty)
          next_state = CALC;
      end

      CALC: begin
        // Only read a byte if the FIFO is not empty.
        if (!rd_fifo_empty) begin
          rd_fifo_rd_en = 1'b1;
          if (byte_cnt == 2'd3)
            next_state = WRITE;
          else
            next_state = CALC;
        end else begin
          // If FIFO is empty, remain in CALC until data is available.
          next_state = CALC;
        end
      end

      WRITE: begin
        // Wait for the write FIFOs to be available.
        if (!wr_fifo_full_I && !wr_fifo_full_Q) begin
          wr_fifo_wr_en_I    = 1'b1;
          wr_fifo_wr_en_Q    = 1'b1;
          // Extract the I sample:
          //   - fifo_word[15:8] is the MSB (IQ[i*4+1])
          //   - fifo_word[7:0]  is the LSB (IQ[i*4+0])
          wr_fifo_data_out_I = quantize_i($signed({fifo_word[15:8], fifo_word[7:0]}));
          // Extract the Q sample:
          //   - fifo_word[31:24] is the MSB (IQ[i*4+3])
          //   - fifo_word[23:16] is the LSB (IQ[i*4+2])
          wr_fifo_data_out_Q = quantize_i($signed({fifo_word[31:24], fifo_word[23:16]}));
          next_state = IDLE;
        end else begin
          next_state = WRITE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Clocked logic for state transitions and FIFO word accumulation.
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      curr_state <= IDLE;
      fifo_word  <= '0;
      byte_cnt   <= 2'd0;
    end else begin
      curr_state <= next_state;
      // In CALC state, if a read is enabled, accumulate the byte.
      if (curr_state == CALC && rd_fifo_rd_en) begin
         case(byte_cnt)
           2'd0: fifo_word[7:0]    <= rd_fifo_data_in;    // IQ[i*4+0]
           2'd1: fifo_word[15:8]   <= rd_fifo_data_in;    // IQ[i*4+1]
           2'd2: fifo_word[23:16]  <= rd_fifo_data_in;    // IQ[i*4+2]
           2'd3: fifo_word[31:24]  <= rd_fifo_data_in;    // IQ[i*4+3]
         endcase
         // Increment byte counter or reset if all four bytes are read.
         if (byte_cnt < 2'd3)
           byte_cnt <= byte_cnt + 1;
         else
           byte_cnt <= 2'd0;
      end
    end
  end

endmodule