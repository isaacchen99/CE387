`timescale 1ns/1ps

module motion_detect_tb;

  // Change these paths as needed
  parameter string BASE_BMP_FILE       = "base.bmp";
  parameter string PEDESTRIAN_BMP_FILE = "pedestrians.bmp";
  parameter string OUTPUT_BMP_FILE     = "output.bmp";
  parameter string GOLDEN_BMP_FILE     = "golden_output.bmp"; // Optional reference
  parameter int    BMP_HEADER_SIZE     = 54;

  // Testbench clock/reset
  logic clk   = 0;
  logic reset = 1;

  // Create instance of the top-level DUT
  // (Ensure motion_detect_top.sv is in your compile list)
  motion_detect_top dut (
    .clk   (clk),
    .reset (reset)
  );

  // Clock generation (100 MHz example => period=10ns)
  always #5 clk = ~clk;

  // Release reset after some cycles
  initial begin
    reset = 1;
    repeat (10) @(posedge clk);
    reset = 0;
    $display("TB: Deasserted reset at time %0t", $time);
  end

  //-------------------------------------------------------------------------
  // File I/O data structures
  //-------------------------------------------------------------------------
  // We'll store each BMP in a byte array.
  // Make sure the arrays are large enough for your images.
  // For demonstration, we use a 5MB array (which may be overkill).
  byte base_bmp_mem       [0 : 5_000_000];
  byte pedestrian_bmp_mem [0 : 5_000_000];
  byte output_bmp_mem     [0 : 5_000_000];

  integer fd_base, fd_ped, fd_out;
  integer base_bmp_size, pedestrian_bmp_size;
  integer bytes_read, bytes_written, output_bmp_size;

  //-------------------------------------------------------------------------
  // Test Sequence
  //-------------------------------------------------------------------------
  initial begin
    // Wait for reset deassert
    @(negedge reset);
    $display("TB: Starting test sequence at time %0t", $time);

    // 1) Read base.bmp from disk
    fd_base = $fopen(BASE_BMP_FILE, "rb");
    if (fd_base == 0) begin
      $error("Cannot open %0s", BASE_BMP_FILE);
      $finish;
    end
    bytes_read = $fread(base_bmp_mem, fd_base);
    base_bmp_size = bytes_read;
    $fclose(fd_base);
    $display("TB: Read %0d bytes from %0s", base_bmp_size, BASE_BMP_FILE);

    // 2) Read pedestrians.bmp from disk
    fd_ped = $fopen(PEDESTRIAN_BMP_FILE, "rb");
    if (fd_ped == 0) begin
      $error("Cannot open %0s", PEDESTRIAN_BMP_FILE);
      $finish;
    end
    bytes_read = $fread(pedestrian_bmp_mem, fd_ped);
    pedestrian_bmp_size = bytes_read;
    $fclose(fd_ped);
    $display("TB: Read %0d bytes from %0s", pedestrian_bmp_size, PEDESTRIAN_BMP_FILE);

    // 3) Push background pixel data (beyond 54-byte header) into DUT's background FIFO
    push_bmp_to_fifo_bg(base_bmp_mem, base_bmp_size);

    // 4) Push pedestrian pixel data into the frame FIFO for subtract
    push_bmp_to_fifo_fr(pedestrian_bmp_mem, pedestrian_bmp_size);

    // 5) Push pedestrian pixel data again into the highlight path's frame FIFO
    push_bmp_to_fifo_for_highlight(pedestrian_bmp_mem, pedestrian_bmp_size);

    // 6) Let the pipeline run
    //    In a real TB, you'd wait until the pipeline has flushed all data through.
    //    We'll just wait a certain number of cycles for demonstration.
    repeat (10000) @(posedge clk);

    // 7) Read the final 32-bit highlighted pixels from the DUT output FIFO
    output_bmp_size = BMP_HEADER_SIZE; // start with header size
    output_bmp_size += read_highlight_output_fifo(output_bmp_mem, BMP_HEADER_SIZE);

    // 8) Insert a BMP header in the first 54 bytes of output_bmp_mem
    //    Typically you copy from the input BMP header if the resolution is the same
    for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
      // Choose whichever header you want (base or pedestrian),
      // as long as the image resolution is consistent.
      output_bmp_mem[i] = pedestrian_bmp_mem[i];
    end

    // 9) Write out the result
    fd_out = $fopen(OUTPUT_BMP_FILE, "wb");
    if (fd_out == 0) begin
      $error("Cannot open output file %0s", OUTPUT_BMP_FILE);
      $finish;
    end
    bytes_written = $fwrite(fd_out, output_bmp_mem, output_bmp_size);
    $fclose(fd_out);
    $display("TB: Wrote %0d bytes to %0s", bytes_written, OUTPUT_BMP_FILE);

    // 10) Optional compare with a golden file
    compare_files(OUTPUT_BMP_FILE, GOLDEN_BMP_FILE);

    $display("TB: Simulation completed at time %0t", $time);
    $finish;
  end

  //-------------------------------------------------------------------------
  // TASK: push_bmp_to_fifo_bg
  // Push the base (background) image data (beyond the header) into
  // the DUT's background FIFO. We do 4 bytes → 1 word (32 bits).
  //-------------------------------------------------------------------------
  task push_bmp_to_fifo_bg(input byte bmp_mem[], input int bmp_size);
    int idx = BMP_HEADER_SIZE;
    while (idx < bmp_size) begin
      logic [31:0] word;
      if ((idx + 3) >= bmp_size) break; // avoid overrun
      word[ 7: 0]  = bmp_mem[idx + 0];
      word[15: 8]  = bmp_mem[idx + 1];
      word[23:16]  = bmp_mem[idx + 2];
      word[31:24]  = bmp_mem[idx + 3];
      idx += 4;

      @(posedge clk);
      // Stall if FIFO is full
      while (dut.bg_fifo_full) @(posedge clk);
      dut.bg_fifo_wr_en <= 1'b1;
      dut.bg_fifo_din   <= word;
      @(posedge clk);
      dut.bg_fifo_wr_en <= 1'b0;
    end
    $display("TB: Finished pushing BG pixels. Pushed %0d bytes.", idx - BMP_HEADER_SIZE);
  endtask

  //-------------------------------------------------------------------------
  // TASK: push_bmp_to_fifo_fr
  // Push the pedestrian frame image data (beyond the header) into
  // the DUT's frame FIFO for subtraction (32 bits).
  //-------------------------------------------------------------------------
  task push_bmp_to_fifo_fr(input byte bmp_mem[], input int bmp_size);
    int idx = BMP_HEADER_SIZE;
    while (idx < bmp_size) begin
      logic [31:0] word;
      if ((idx + 3) >= bmp_size) break;
      word[ 7: 0]  = bmp_mem[idx + 0];
      word[15: 8]  = bmp_mem[idx + 1];
      word[23:16]  = bmp_mem[idx + 2];
      word[31:24]  = bmp_mem[idx + 3];
      idx += 4;

      @(posedge clk);
      while (dut.fr_fifo_full) @(posedge clk);
      dut.fr_fifo_wr_en <= 1'b1;
      dut.fr_fifo_din   <= word;
      @(posedge clk);
      dut.fr_fifo_wr_en <= 1'b0;
    end
    $display("TB: Finished pushing FRAME (sub) pixels. Pushed %0d bytes.", idx - BMP_HEADER_SIZE);
  endtask

  //-------------------------------------------------------------------------
  // TASK: push_bmp_to_fifo_for_highlight
  // Push the same pedestrian image data into the highlight frame FIFO
  //-------------------------------------------------------------------------
  task push_bmp_to_fifo_for_highlight(input byte bmp_mem[], input int bmp_size);
    int idx = BMP_HEADER_SIZE;
    while (idx < bmp_size) begin
      logic [31:0] word;
      if ((idx + 3) >= bmp_size) break;
      word[ 7: 0]  = bmp_mem[idx + 0];
      word[15: 8]  = bmp_mem[idx + 1];
      word[23:16]  = bmp_mem[idx + 2];
      word[31:24]  = bmp_mem[idx + 3];
      idx += 4;

      @(posedge clk);
      while (dut.fr_hl_fifo_full) @(posedge clk);
      dut.fr_hl_fifo_wr_en <= 1'b1;
      dut.fr_hl_fifo_din   <= word;
      @(posedge clk);
      dut.fr_hl_fifo_wr_en <= 1'b0;
    end
    $display("TB: Finished pushing FRAME (highlight) pixels. Pushed %0d bytes.", idx - BMP_HEADER_SIZE);
  endtask

  //-------------------------------------------------------------------------
  // FUNCTION: read_highlight_output_fifo
  // Reads 32-bit words from the highlight output FIFO, storing them into
  // output_bmp_mem. Returns how many bytes were read.
  //-------------------------------------------------------------------------
  function int read_highlight_output_fifo(
      output byte bmp_mem[],
      input  int  start_index
  );
    int idx = start_index;
    while (1) begin
      @(posedge clk);
      // If empty, break
      if (dut.highlight_fifo_empty) begin
        if (dut.highlight_fifo_wr_en == 1'b0)
          // If no more writes are coming, we can assume done
          break;
      end
      else begin
        // Pull one word
        dut.highlight_fifo_rd_en <= 1'b1;
        @(posedge clk);
        dut.highlight_fifo_rd_en <= 1'b0;

        // Data should be valid the cycle after rd_en
        logic [31:0] out_word = dut.highlight_fifo_dout;

        // Store into memory as 4 bytes
        bmp_mem[idx + 0] = out_word[ 7: 0];
        bmp_mem[idx + 1] = out_word[15: 8];
        bmp_mem[idx + 2] = out_word[23:16];
        bmp_mem[idx + 3] = out_word[31:24];
        idx += 4;
      end
    end
    read_highlight_output_fifo = (idx - start_index);
    $display("TB: Read %0d bytes from highlight output FIFO", idx - start_index);
  endfunction

  //-------------------------------------------------------------------------
  // TASK: compare_files
  // Optional: Compare the new output file with a "golden" reference.
  //-------------------------------------------------------------------------
  task compare_files(input string new_file, input string ref_file);
    integer fd_new, fd_ref, size_new, size_ref;
    byte new_mem [0:5_000_000];
    byte ref_mem [0:5_000_000];

    if (ref_file == "") begin
      $display("No golden file specified, skipping compare.");
      return;
    end

    fd_new = $fopen(new_file, "rb");
    if (fd_new == 0) begin
      $display("Cannot open %0s for compare.", new_file);
      return;
    end
    size_new = $fread(new_mem, fd_new);
    $fclose(fd_new);

    fd_ref = $fopen(ref_file, "rb");
    if (fd_ref == 0) begin
      $display("Cannot open %0s (golden) for compare.", ref_file);
      return;
    end
    size_ref = $fread(ref_mem, fd_ref);
    $fclose(fd_ref);

    if (size_new != size_ref) begin
      $display("COMPARE: File sizes differ (new=%0d, ref=%0d)", size_new, size_ref);
      return;
    end

    for (int i = 0; i < size_new; i++) begin
      if (new_mem[i] != ref_mem[i]) begin
        $display("COMPARE ERROR at byte[%0d]: new=%02h, ref=%02h", i, new_mem[i], ref_mem[i]);
      end
    end
    $display("COMPARE DONE: %0s vs %0s (checked %0d bytes)", new_file, ref_file, size_new);
  endtask

endmodule