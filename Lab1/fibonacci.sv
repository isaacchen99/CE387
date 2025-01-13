module fibonacci(
  input  logic        clk,
  input  logic        reset,
  input  logic [15:0] din,
  input  logic        start,
  output logic [15:0] dout,
  output logic        done
);

  typedef enum logic [1:0] {IDLE, CALC, DONE} state_t;
  state_t current_state, next_state;

  logic [15:0] prev1, prev2;  
  logic [15:0] next_fib;      
  logic [15:0] output_reg;
  logic        done_reg;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      current_state <= IDLE;
      
      prev1       <= 16'd0; 
      prev2       <= 16'd1;

      output_reg  <= 16'd0;
      done_reg    <= 1'b0;
    end
    else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          done_reg   <= 1'b0;
          output_reg <= 16'd0;

          prev1 <= 16'd0; 
          prev2 <= 16'd1;
        end

        CALC: begin
          next_fib = prev1 + prev2;

          output_reg <= prev1;

          prev2 <= prev1; 
          prev1 <= next_fib;
        end

        DONE: begin
          done_reg <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALC;
        end
      end

      CALC: begin
        if ((prev1 + prev2) > din) begin
          next_state = DONE;
        end
        else begin
          next_state = CALC;
        end
      end

      DONE: begin
        next_state = DONE;
      end
    endcase
  end

  assign dout = output_reg;
  assign done = done_reg;

endmodule