import radio_const_pkg::*;

`timescale 1ns/1ps

module tb_fir_top;

  localparam DECIMATION       = 1;      // Process every sample
  localparam FIFO_DATA_WIDTH  = 16;
  localparam NUM_TAPS         = 32;
  localparam int NUM_INPUTS   = 128;


  logic                       clk;
  logic                       rst;

  logic [FIFO_DATA_WIDTH-1:0] in_data;
  logic                       in_wr_en;
  logic                       in_fifo_full;

  logic [FIFO_DATA_WIDTH-1:0] out_data;
  logic                       out_rd_en;
  logic                       out_fifo_empty;

  fir_top #(
    .DECIMATION       (DECIMATION),
    .FIFO_DATA_WIDTH  (FIFO_DATA_WIDTH),
    .NUM_TAPS         (NUM_TAPS),
    .COEFFS           (TEST_COEFFS)
  ) dut (
    .clk            (clk),
    .rst            (rst),

    .in_data        (in_data),
    .in_wr_en       (in_wr_en),
    .in_fifo_full   (in_fifo_full),

    .out_data       (out_data),
    .out_rd_en      (out_rd_en),
    .out_fifo_empty (out_fifo_empty)
  );

  always #5 clk = ~clk;
  initial begin
    // Initialize signals
    clk         = 0;
    rst         = 1;
    in_data     = '0;
    in_wr_en    = 0;
    out_rd_en   = 0;

    #20;
    rst = 0;

    // Write 128 samples to the input FIFO
    for (int i = 0; i < NUM_INPUTS; i++) begin
      // Wait until FIFO is not full
      wait (in_fifo_full == 0);

      // Present data and assert write enable
      in_data  = i;        // example: feed incrementing data
      in_wr_en = 1;

      @(posedge clk);
      // Deassert write enable after one cycle
      in_wr_en = 0;
    end

    // Optionally wait for pipeline flush
    // The FIR has some latency to produce outputs
    #100;

    // --------------------------------------------------------------
    // Read from the output FIFO, printing the results
    // --------------------------------------------------------------
    // We attempt more reads than the 128 inputs, in case the FIR 
    // produces a delayed pipeline result (e.g. up to NUM_TAPS extra).
    for (int j = 0; j < NUM_INPUTS + NUM_TAPS; j++) begin
      if (!out_fifo_empty) begin
        out_rd_en = 1;  // assert read enable
        @(posedge clk);
        out_rd_en = 0;  // deassert read enable

        // Print the just-read sample
        $display("Output sample %0d: %08h", j, out_data);
      end else begin
        // If FIFO is empty, just wait a cycle
        @(posedge clk);
      end
    end

    // Finish the simulation
    #50;
    $finish;
  end

endmodule