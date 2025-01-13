`timescale 1ns/1ns

module fibonacci_tb;

  logic clk; 
  logic reset = 1'b0;
  logic [15:0] din  = 16'h0;
  logic        start= 1'b0;
  logic [15:0] dout;
  logic        done;

  fibonacci fib (
    .clk   (clk),
    .reset (reset),
    .din   (din),
    .start (start),
    .dout  (dout),
    .done  (done)
  );

  always begin
    clk = 1'b0;
    #5;
    clk = 1'b1;
    #5;
  end

  initial begin
    // Apply reset
    reset = 0;
    #10;
    reset = 1;
    #10;
    reset = 0;
    
    // Test input of 5
    #10;
    din   = 16'd5;
    start = 1'b1;
    #10;
    start = 1'b0;
    
    // Wait for 'done'
    wait (done == 1'b1);

    $display("-----------------------------------------");
    $display("Input: %0d", din);
    if (dout === 5)
      $display("CORRECT RESULT: %0d, GOOD JOB!", dout);
    else
      $display("INCORRECT RESULT: %0d, SHOULD BE: 5", dout);


    #10;
    reset = 1;
    #10;
    reset = 0;
    #10;
    din   = 16'd10;
    start = 1'b1;
    #10;
    start = 1'b0;

    wait (done == 1'b1);

    $display("=========================================");
    $display("TEST 2: Input = %0d", din);

    if (dout === 8)
      $display("CORRECT RESULT: %0d, GOOD JOB!", dout);
    else
      $display("INCORRECT RESULT: %0d, SHOULD BE: 8", dout);

    #10;
    reset = 1;
    #10;
    reset = 0;

    #10;
    din   = 16'd20;
    start = 1'b1;
    #10;
    start = 1'b0;

    wait (done == 1'b1);

    $display("=========================================");
    $display("TEST 3: Input = %0d", din);
    if (dout === 13)
      $display("CORRECT RESULT: %0d, GOOD JOB!", dout);
    else
      $display("INCORRECT RESULT: %0d, SHOULD BE: 13", dout);
    $stop;
  end

endmodule