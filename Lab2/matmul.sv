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
  
  input logic [DATA_WIDTH-1 : 0] a_dout,
  output logic [ADDR_WIDTH-1 : 0] a_rd_addr,

  input logic [DATA_WIDTH-1 : 0] b_dout,
  output logic [ADDR_WIDTH-1 : 0] b_rd_addr,

  output logic [DATA_WIDTH-1 : 0] c_din,
  output logic [ADDR_WIDTH-1 : 0] c_wr_addr,
  output logic c_wr_en
);

  // internal registers
  typedef enum logic [1:0] {IDLE, CALC, DONE} state_t;
  state_t curr_state, next_state;
  logic [ADDR_WIDTH-1 : 0] i;
  logic [LOG2_N-1 : 0] j;
  logic [DATA_WIDTH-1 : 0] accum;

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      curr_state <= IDLE;
      i <= 0;
      done <= 1'b0;
    end 
    else begin // posedge clock
      curr_state <= next_state; // update state

      case (curr_state)
        IDLE: begin
          done <= 1'b0;
          a_rd_addr <= 0;
          b_rd_addr <= 0;
          c_din <= 0;
          c_wr_addr <= 0;
          c_wr_en <= 1'b0;

          i <= 0;
          j <= 0;
          accum <= 0;
        end

        CALC: begin
          if (j < N) begin // accumulation
            j <= j + 1;

            a_rd_addr <= ((i / N) * N) + j; // A is row major
            b_rd_addr <= (j * N) + (i % N); // B must go column major

            accum <= accum + (a_dout * B_dout);
          end

          else if (j == N) begin // writeback
            c_wr_addr <= i;
            c_wr_en <= 1'b1;
            c_din <= accum;
            accum <= 0;
            i <= i + 1;
            j <= 0;
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin  // next-state logic
    next_state = curr_state;  // default behavior if none of the cases are met.

    case (curr_state)
      IDLE: begin
        if (start == 1)
          next_state = CALC;
      end

      CALC: begin
        if (i == N * N) 
          next_state = DONE;
      end

      DONE: begin
      end
    endcase
  end
endmodule