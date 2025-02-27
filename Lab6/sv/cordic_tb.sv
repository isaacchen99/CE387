`timescale 1ns/1ps

module cordic_tb;
  parameter FIFO_DATA_WIDTH = 16;
  parameter FIFO_BUFFER_SIZE = 16;
  parameter NUM_STAGES = 16;
  
  logic clock;
  logic reset;

  logic wr_en;
  logic [FIFO_DATA_WIDTH-1:0] data_in;
  logic full;

  logic cos_rd_en;
  logic [FIFO_DATA_WIDTH-1:0] cos_data_out;
  logic cos_empty;

  logic sin_rd_en;
  logic [FIFO_DATA_WIDTH-1:0] sin_data_out;
  logic sin_empty;

  cordic_top #(
    .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .NUM_STAGES(NUM_STAGES)
  ) dut (
    .clock(clock),
    .reset(reset),
    
    .wr_en(wr_en),
    .data_in(data_in),
    .full(full),
    
    .cos_rd_en(cos_rd_en),
    .cos_data_out(cos_data_out),
    .cos_empty(cos_empty),
    
    .sin_rd_en(sin_rd_en),
    .sin_data_out(sin_data_out),
    .sin_empty(sin_empty)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    // Initialization
    reset = 1;
    wr_en = 0;
    cos_rd_en = 0;
    sin_rd_en = 0;
    data_in = 0;
    
    #20;
    reset = 0;
    #20;
    
    // Test 1: Angle = 16'h3243 (original test)
    data_in = 16'h3243;
    wr_en = 1;
    #10;
    wr_en = 0;
    
    #250;
    if (!cos_empty) begin
      cos_rd_en = 1;
      #10;
      cos_rd_en = 0;
      $display("Test1: Angle 16'h3243 -> Cosine Output: 0x%h", cos_data_out);
    end else begin
      $display("Test1: Cosine FIFO is empty.");
    end

    if (!sin_empty) begin
      sin_rd_en = 1;
      #10;
      sin_rd_en = 0;
      $display("Test1: Angle 16'h3243 -> Sine Output: 0x%h", sin_data_out);
    end else begin
      $display("Test1: Sine FIFO is empty.");
    end

    // Test 2: Angle = 0 (16'h0000)
    #50;
    data_in = 16'h0000;
    wr_en = 1;
    #10;
    wr_en = 0;
    
    #250;
    if (!cos_empty) begin
      cos_rd_en = 1;
      #10;
      cos_rd_en = 0;
      $display("Test2: Angle 0 (16'h0000) -> Cosine Output: 0x%h", cos_data_out);
    end else begin
      $display("Test2: Cosine FIFO is empty.");
    end

    if (!sin_empty) begin
      sin_rd_en = 1;
      #10;
      sin_rd_en = 0;
      $display("Test2: Angle 0 (16'h0000) -> Sine Output: 0x%h", sin_data_out);
    end else begin
      $display("Test2: Sine FIFO is empty.");
    end

    // Test 3: Angle = -30° (16'hDE7D)
    // -30° in radians is approximately -0.5236 rad.
    // In fixed-point: -0.5236 * 16384 ≈ -8579, which in 16-bit two's complement is 16'hDE7D.
    #50;
    data_in = 16'hDE7D;
    wr_en = 1;
    #10;
    wr_en = 0;
    
    #250;
    if (!cos_empty) begin
      cos_rd_en = 1;
      #10;
      cos_rd_en = 0;
      $display("Test3: Angle -30° (16'hDE7D) -> Cosine Output: 0x%h", cos_data_out);
    end else begin
      $display("Test3: Cosine FIFO is empty.");
    end

    if (!sin_empty) begin
      sin_rd_en = 1;
      #10;
      sin_rd_en = 0;
      $display("Test3: Angle -30° (16'hDE7D) -> Sine Output: 0x%h", sin_data_out);
    end else begin
      $display("Test3: Sine FIFO is empty.");
    end
    
    #50;
    $finish;
  end

endmodule