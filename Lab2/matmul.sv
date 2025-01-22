module matmul #(
  parameter N = 8,
  parameter LOG2_N = 3,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 6
) (
  input logic clock,
  input logic reset,
  input logic start,
  output logic done,

  // Interface to BRAM A
  input logic [DATA_WIDTH-1 : 0] a_dout,
  output logic [ADDR_WIDTH-1 : 0] a_rd_addr,

  // Interface to BRAM B
  input logic [DATA_WIDTH-1 : 0] b_dout,
  output logic [ADDR_WIDTH-1 : 0] b_rd_addr,

  // Interface to BRAM C
  output logic [DATA_WIDTH-1 : 0] c_din,
  output logic [ADDR_WIDTH-1 : 0] c_wr_addr,
  output logic c_wr_en
);

  // State definitions
  typedef enum logic [2:0] {IDLE, INIT, PIPE, WRITE, INC, DONE} state_t;
  state_t curr_state, next_state;

  // Internal counters and registers
  logic [LOG2_N-1:0] i, j, k;
  logic [DATA_WIDTH-1:0] accum;

  // Sequential process for state and register updates
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      curr_state <= IDLE;
      i <= 0;
      j <= 0;
      k <= 0;
      accum <= 0;
      done <= 1'b0;
    end else begin
      curr_state <= next_state;
      
      case (curr_state)
        IDLE: begin
          done <= 1'b0;
        end

        INIT: begin
          accum <= 0;
          k <= 0;
        end

        PIPE: begin
          // Multiply-accumulate operation
          accum <= accum + (a_dout * b_dout);
          k <= k + 1;
        end

        WRITE: begin
          // Writing the accumulated value to BRAM C
        end

        INC: begin
          // Update indices for next element
          if (j == (N - 1)) begin
            j <= 0;
            i <= i + 1;
          end else begin
            j <= j + 1;
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Combinational process for next-state logic and outputs
  always_comb begin
    // Default values for outputs and next state
    next_state = curr_state;
    c_wr_en = 1'b0;
    c_wr_addr = 0;
    c_din = accum;
    a_rd_addr = i * N + k;
    b_rd_addr = k * N + j;

    case (curr_state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end

      INIT: begin
        a_rd_addr = i * N; // Initialize A and B read addresses
        b_rd_addr = j;
        next_state = PIPE;
      end

      PIPE: begin
        if (k < (N - 1)) begin
          a_rd_addr = i * N + (k + 1);
          b_rd_addr = (k + 1) * N + j;
          next_state = PIPE;
        end else begin
          next_state = WRITE;
        end
      end

      WRITE: begin
        c_wr_en = 1'b1;
        c_wr_addr = i * N + j;
        next_state = INC;
      end

      INC: begin
        if ((i == (N - 1)) && (j == (N - 1))) begin
          next_state = DONE;
        end else begin
          next_state = INIT;
        end
      end

      DONE: begin
        // Remain in DONE state
      end
    endcase
  end
endmodule