module fibonacci(
  input logic clk, 
  input logic reset,
  input logic [15:0] din,
  input logic start,
  output logic [15:0] dout,
  output logic done );

  // Add local logic signals
  enum logic [1:0] {IDLE, CALC, DONE} state;
  state current_state, next_state;

  logic [15:0] curr, prev1, prev2;


  always_ff @(posedge clk, posedge reset) begin
    if ( reset == 1'b1 ) begin
       current_state <= IDLE;
       curr <= 16'b0;
       prev1 <= 16'b1;
       prev2 <= 16'b0;
    end else begin
       current_state <= next_state;
        if (current_state == CALC) begin
          curr <= prev1 + prev2;
          prev2 <= prev1;
          prev1 <= curr;
        end else if (current_state == DONE) begin
          dout = curr;
          done = 1'b1;
        end
    end
  end

  always_comb begin
    // default values
    dout = 16'b0;
    done = 1'b0;
    next_state = current_state;

    case (current_state)
       IDLE: begin
        if (start)
          next_state = CALC;
       end

       CALC: begin
        if (curr > din) begin
          next_state = DONE;
        end else begin
          next_state = CALC;
        end
       end

       DONE: begin
        next_state = current_state;
       end
    endcase
  end

endmodule
