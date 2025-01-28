`timescale 1ns/1ps

module motion_detect_tb;

  // Change these paths/filenames as needed
  parameter string BASE_BMP_FILE       = "base.bmp";
  parameter string PEDESTRIAN_BMP_FILE = "pedestrians.bmp";
  parameter string OUTPUT_BMP_FILE     = "output.bmp";
  parameter string GOLDEN_BMP_FILE     = "golden_output.bmp"; // optional reference
  parameter int    BMP_HEADER_SIZE     = 54;

  // Clock/reset
  logic clk   = 0;
  logic reset = 1;

  // Instantiate your top-level DUT (motion_detect_top)
  motion_detect_top dut (
    .clk   (clk),
    .reset (reset)
  );

  // Clock generation (e.g. 100 MHz => 10 ns period)
  always #5 clk = ~clk;

  // Deassert reset after some cycles
  initial begin
    reset = 1;
    repeat (10) @(posedge clk);
    reset = 0;
    $display("TB: Deasserted reset at time %0t", $time);
  end

  // Memory for BMP files
  byte base_bmp_mem       [0 : 5_000_000];
  byte pedestrian_bmp_mem [0 : 5_000_000];
  byte output_bmp_mem     [0 : 5_000_000];

  integer fd_base, fd_ped, fd_out;
  integer base_bmp_size, pedestrian_bmp_size;
  integer bytes_read, bytes_written, output_bmp_size;

  // Main test sequence
  initial begin
    @(negedge reset);
    $display("TB: Starting at time %0t", $time);

    // 1) Read base.bmp
    fd_base = $fopen(BASE_BMP_FILE, "rb");
    if (fd_base == 0) begin
      $error("Cannot open %0s", BASE_BMP_FILE);
      $finish;
    end
    bytes_read     = $fread(base_bmp_mem, fd_base);
    base_bmp_size  = bytes_read;
    $fclose(fd_base);
    $display("TB: Read %0d bytes from %0s", base_bmp_size, BASE_BMP_FILE);

    // 2) Read pedestrians.bmp
    fd_ped = $fopen(PEDESTRIAN_BMP_FILE, "rb");
    if (fd_ped == 0) begin
      $error("Cannot open %0s", PEDESTRIAN_BMP_FILE);
      $finish;
    end
    bytes_read         = $fread(pedestrian_bmp_mem, fd_ped);
    pedestrian_bmp_size= bytes_read;
    $fclose(fd_ped);
    $display("TB: Read %0d bytes from %0s", pedestrian_bmp_size, PEDESTRIAN_BMP_FILE);

    // 3) Push base image data into background FIFO
    push_bmp_to_fifo_bg(base_bmp_mem, base_bmp_size);

    // 4) Push pedestrian data into frame FIFO (for subtract)
    push_bmp_to_fifo_fr(pedestrian_bmp_mem, pedestrian_bmp_size);

    // 5) Push pedestrian data into highlight frame FIFO
    push_bmp_to_fifo_for_highlight(pedestrian_bmp_mem, pedestrian_bmp_size);

    // 6) Wait for pipeline to process
    repeat (10000) @(posedge clk);

    // 7) Read final 32-bit highlighted pixels
    output_bmp_size = BMP_HEADER_SIZE;
    output_bmp_size += read_highlight_output_fifo(output_bmp_mem, BMP_HEADER_SIZE);

    // 8) Copy BMP header into output memory
    for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
      // Typically use the same header from one of the inputs
      output_bmp_mem[i] = pedestrian_bmp_mem[i];
    end

    // 9) Write the final BMP
    fd_out = $fopen(OUTPUT_BMP_FILE, "wb");
    if (fd_out == 0) begin
      $error("Cannot open %0s for writing", OUTPUT_BMP_FILE);
      $finish;
    end
    bytes_written = $fwrite(fd_out, output_bmp_mem, output_bmp_size);
    $fclose(fd_out);
    $display("TB: Wrote %0d bytes to %0s", bytes_written, OUTPUT_BMP_FILE);

    // 10) Compare with golden if needed
    compare_files(OUTPUT_BMP_FILE, GOLDEN_BMP_FILE);

    $display("TB: Test completed at time %0t", $time);
    $finish;
  end

  //--------------------------------------------------------------------------
  // push_bmp_to_fifo_bg
  //--------------------------------------------------------------------------
  task automatic push_bmp_to_fifo_bg(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx;
    logic [31:0] word;
    begin
      idx = BMP_HEADER_SIZE;
      while ((idx + 3) < bmp_size) begin
        word[ 7: 0]  = bmp_mem[idx + 0];
        word[15: 8]  = bmp_mem[idx + 1];
        word[23:16]  = bmp_mem[idx + 2];
        word[31:24]  = bmp_mem[idx + 3];
        idx += 4;

        // Wait one clock
        @(posedge clk);
        // Stall if full
        while (dut.bg_fifo_full) @(posedge clk);

        dut.bg_fifo_wr_en <= 1'b1;
        dut.bg_fifo_din   <= word;
        @(posedge clk);
        dut.bg_fifo_wr_en <= 1'b0;
      end
      $display("TB: push_bmp_to_fifo_bg done, %0d bytes pushed.", idx - BMP_HEADER_SIZE);
    end
  endtask

  //--------------------------------------------------------------------------
  // push_bmp_to_fifo_fr
  //--------------------------------------------------------------------------
  task automatic push_bmp_to_fifo_fr(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx;
    logic [31:0] word;
    begin
      idx = BMP_HEADER_SIZE;
      while ((idx + 3) < bmp_size) begin
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
      $display("TB: push_bmp_to_fifo_fr done, %0d bytes pushed.", idx - BMP_HEADER_SIZE);
    end
  endtask

  //--------------------------------------------------------------------------
  // push_bmp_to_fifo_for_highlight
  //--------------------------------------------------------------------------
  task automatic push_bmp_to_fifo_for_highlight(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx;
    logic [31:0] word;
    begin
      idx = BMP_HEADER_SIZE;
      while ((idx + 3) < bmp_size) begin
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
      $display("TB: push_bmp_to_fifo_for_highlight done, %0d bytes pushed.", idx - BMP_HEADER_SIZE);
    end
  endtask

  //--------------------------------------------------------------------------
// read_highlight_output_fifo
//--------------------------------------------------------------------------
task automatic read_highlight_output_fifo(
    output byte bmp_mem[],
    input  int  start_index
);
  int idx;
  logic [31:0] out_word;
  begin
    idx = start_index;

    forever begin
      @(posedge clk);

      // If FIFO is empty and no further writes are anticipated, we assume done
      if (dut.highlight_fifo_empty) begin
        if (!dut.highlight_wr_en)
          // break from forever
          disable done_read;
      end
      else begin
        // Pop one word from FIFO
        dut.highlight_fifo_rd_en <= 1'b1;
        @(posedge clk);
        dut.highlight_fifo_rd_en <= 1'b0;

        out_word = dut.highlight_fifo_dout;

        bmp_mem[idx + 0] = out_word[ 7: 0];
        bmp_mem[idx + 1] = out_word[15: 8];
        bmp_mem[idx + 2] = out_word[23:16];
        bmp_mem[idx + 3] = out_word[31:24];
        idx += 4;
      end
    end
    done_read: 

    $display("TB: read_highlight_output_fifo read %0d bytes total", idx - start_index);
  end
endtask

  //--------------------------------------------------------------------------
  // compare_files
  //--------------------------------------------------------------------------
  task automatic compare_files(
      input string new_file,
      input string ref_file
  );
    integer fd_new, fd_ref;
    integer size_new, size_ref;
    byte new_mem [0:5_000_000];
    byte ref_mem [0:5_000_000];
    int i;
    begin
      if (ref_file == "") begin
        $display("No golden file specified, skipping compare.");
        return;
      end

      fd_new = $fopen(new_file, "rb");
      if (fd_new == 0) begin
        $display("Cannot open %0s for compare", new_file);
        return;
      end
      size_new = $fread(new_mem, fd_new);
      $fclose(fd_new);

      fd_ref = $fopen(ref_file, "rb");
      if (fd_ref == 0) begin
        $display("Cannot open %0s for compare", ref_file);
        return;
      end
      size_ref = $fread(ref_mem, fd_ref);
      $fclose(fd_ref);

      if (size_new != size_ref) begin
        $display("COMPARE: Size mismatch new=%0d, ref=%0d", size_new, size_ref);
        return;
      end

      for (i = 0; i < size_new; i++) begin
        if (new_mem[i] != ref_mem[i]) begin
          $display("COMPARE ERROR at byte[%0d]: new=%0x, ref=%0x", i, new_mem[i], ref_mem[i]);
        end
      end
      $display("COMPARE DONE: %0s vs %0s (checked %0d bytes)", new_file, ref_file, size_new);
    end
  endtask

endmodule