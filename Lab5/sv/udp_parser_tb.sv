`timescale 1ns/1ps
module udp_parser_tb;

  // Clock and reset signals.
  logic clk;
  logic reset;

  // Testbench local signals connected to DUT ports.
  logic        in_fifo_wr_en;
  logic [7:0]  in_fifo_din;
  wire         in_fifo_full;

  logic        out_fifo_rd_en;
  wire  [7:0]  out_fifo_dout;
  wire         out_fifo_empty;
  wire         out_fifo_full;

  udp_parser_top dut (
    .clk           (clk),
    .reset         (reset),
    .in_fifo_wr_en (in_fifo_wr_en),
    .in_fifo_din   (in_fifo_din),
    .in_fifo_full  (in_fifo_full),
    .out_fifo_rd_en(out_fifo_rd_en),
    .out_fifo_dout (out_fifo_dout),
    .out_fifo_empty(out_fifo_empty),
    .out_fifo_full (out_fifo_full)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset = 1;
    in_fifo_wr_en = 0;
    in_fifo_din   = 8'h00;
    out_fifo_rd_en = 0;
    #20;
    reset = 0;
  end

  initial begin
    #300000
    $finish;
  end

  //-------------------------------------------------------------------------
  // Main Test Sequence:
  //   - Read one byte at a time from "input.pcap" and drive in_fifo_din.
  //   - After processing, read one byte at a time from the output FIFO,
  //     write the corresponding ASCII character to "sim_out.txt", and compare
  //     it against the expected character from "test_output.txt".
  //-------------------------------------------------------------------------
  initial begin
    integer input_file, expected_file, sim_out_file;
    integer in_char, expected_char, out_char;

    // Wait for reset deassertion and let signals settle.
    @(negedge reset);

    // Open "input.pcap" for reading.
    input_file = $fopen("input.pcap", "r");
    $display("OPENED INPUT FILE");
    if (input_file == 0) begin
      $display("ERROR: Failed to open input.pcap");
      $finish;
    end

    // Open "test_output.txt" for reading.
    expected_file = $fopen("test_output.txt", "r");
    $display("OPENED REFERENCE FILE");
    if (expected_file == 0) begin
      $display("ERROR: Failed to open test_output.txt");
      $finish;
    end

    // Open "sim_out.txt" for writing.
    sim_out_file = $fopen("sim_out.txt", "w");
    $display("OPENED OUTPUT FILE");
    if (sim_out_file == 0) begin
      $display("ERROR: Failed to open sim_out.txt for writing");
      $finish;
    end

    //-------------------------------------------------------------------------
    // Combined loop to feed the input FIFO and read from the output FIFO.
    // The loop continues until we reach EOF on the input file and the
    // output FIFO becomes empty.
    //-------------------------------------------------------------------------
    while (!$feof(input_file) || !out_fifo_empty) begin

      // If there is still input to be read, feed the input FIFO.
      if (!$feof(input_file)) begin
        in_char = $fgetc(input_file);
        if (in_char != -1) begin
          // Wait until the input FIFO is not full.
          while (in_fifo_full) begin
            @(posedge clk);
          end
          @(posedge clk);
          in_fifo_din   = in_char[7:0];
          in_fifo_wr_en = 1;
          @(posedge clk);
          in_fifo_wr_en = 0;
        end
      end

      // Concurrently, if the output FIFO is not empty, read from it.
      if (!out_fifo_empty) begin
        @(posedge clk);
        out_fifo_rd_en = 1;
        $display("Trying to read output FIFO at time %t", $time);
        @(posedge clk);
        out_fifo_rd_en = 0;
        out_char = out_fifo_dout;
  
        // Write the output character to sim_out.txt.
        $fwrite(sim_out_file, "%c", out_char);
      end

      @(posedge clk);
    end

    $fclose(input_file);


    $fclose(expected_file);
    $fclose(sim_out_file);
    $finish;
  end

endmodule