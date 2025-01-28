`timescale 1ns/1ps

module motion_detect_tb;

  parameter string BASE_BMP_FILE       = "base.bmp";
  parameter string PEDESTRIAN_BMP_FILE = "pedestrians.bmp";
  parameter string OUTPUT_BMP_FILE     = "output.bmp";
  parameter int    BMP_HEADER_SIZE     = 54;

  // Testbench clock/reset
  logic clk = 0;
  logic reset = 1;

  // Wires to/from motion_detect_top
  // (You may need to expose more signals depending on your design)
  // For simplicity, let's assume we tie all wr_en/din signals from the TB,
  // and the top module automatically reads/writes them.
  // We'll drive them from the TB to push data into the FIFOs.

  motion_detect_top dut (
      .clk   (clk),
      .reset (reset)
      // All other ports internally connected in the top
  );

  // Testbench file I/O
  integer fd_base, fd_ped, fd_out, bytes_read, bytes_written;

  // Simple memory arrays for BMP data (byte‑oriented).
  // In practice, you'll want to dynamically size them based on file size, or use large enough arrays.
  byte base_bmp_mem       [0 : 5_000_000]; // 5MB buffer for example
  byte pedestrian_bmp_mem [0 : 5_000_000];
  byte output_bmp_mem     [0 : 5_000_000];

  // Keep track of actual image sizes
  integer base_bmp_size;
  integer pedestrian_bmp_size;
  integer output_bmp_size;

  // Clock generation
  always #5 clk = ~clk;

  // Simple reset release
  initial begin
    #100 reset = 0;
  end

  // Main stimulus
  initial begin
    // 1) Open and read the base.bmp file
    fd_base = $fopen(BASE_BMP_FILE, "rb");
    if (fd_base == 0) begin
      $error("ERROR: Unable to open %0s!", BASE_BMP_FILE);
      $finish;
    end
    bytes_read = $fread(base_bmp_mem, fd_base);
    base_bmp_size = bytes_read;
    $display("Read %0d bytes from %0s", bytes_read, BASE_BMP_FILE);
    $fclose(fd_base);

    // 2) Open and read the pedestrians.bmp file
    fd_ped = $fopen(PEDESTRIAN_BMP_FILE, "rb");
    if (fd_ped == 0) begin
      $error("ERROR: Unable to open %0s!", PEDESTRIAN_BMP_FILE);
      $finish;
    end
    bytes_read = $fread(pedestrian_bmp_mem, fd_ped);
    pedestrian_bmp_size = bytes_read;
    $display("Read %0d bytes from %0s", bytes_read, PEDESTRIAN_BMP_FILE);
    $fclose(fd_ped);

    // 3) Push the BMP headers of both images into "header storage" or hold them in TB
    //    We'll push the pixel data beyond the 54‑byte header into the DUT FIFOs.
    //    The first 54 bytes is the BMP header; we store that for the final output file.

    // Wait a few cycles after reset is deasserted
    @(negedge reset);
    repeat (10) @(posedge clk);

    // 4) Push background pixel data into the background FIFO
    push_bmp_to_fifo_bg(base_bmp_mem, base_bmp_size);

    // 5) Push pedestrian pixel data into the frame FIFO (for subtract)
    push_bmp_to_fifo_fr(pedestrian_bmp_mem, pedestrian_bmp_size);

    // 6) Also push the same pedestrian data into the highlight frame FIFO
    //    (the design has a separate path for highlight).
    push_bmp_to_fifo_for_highlight(pedestrian_bmp_mem, pedestrian_bmp_size);

    // 7) Wait for pipeline to process data
    //    In a real test, you'd monitor the final output FIFO's empty signal
    //    and read the data out. We'll do a fixed wait for simplicity.
    repeat (10000) @(posedge clk);

    // 8) Read the output data from the highlight output FIFO.
    //    We'll store the result into output_bmp_mem (starting at offset 54).
    output_bmp_size = BMP_HEADER_SIZE + read_output_fifo(output_bmp_mem, BMP_HEADER_SIZE);

    // 9) Write the final BMP file to disk
    //    First copy the 54‑byte header from the pedestrian or base image
    //    (whichever header you want in the final image, usually you match the same dimension).
    for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
      output_bmp_mem[i] = pedestrian_bmp_mem[i];  // or base_bmp_mem[i]
    end

    fd_out = $fopen(OUTPUT_BMP_FILE, "wb");
    if (fd_out == 0) begin
      $error("ERROR: Unable to open output file %0s", OUTPUT_BMP_FILE);
      $finish;
    end
    bytes_written = $fwrite(fd_out, output_bmp_mem, output_bmp_size);
    $display("Wrote %0d bytes to %0s", bytes_written, OUTPUT_BMP_FILE);
    $fclose(fd_out);

    // 10) Optional: Compare the output file to a known "golden" reference
    //     or re‑read the file in software to compare pixel by pixel.
    compare_results(OUTPUT_BMP_FILE, "golden_output.bmp");

    $finish;
  end

  //--------------------------------------------------------------------------
  // Task: push_bmp_to_fifo_bg
  // Reads from a BMP memory (beyond the 54‑byte header) and pushes pixel data
  // into the DUT's "background" FIFO interface.
  // For a 32‑bit pixel pipeline: we group every 4 bytes from the BMP into a word.
  //--------------------------------------------------------------------------
  task push_bmp_to_fifo_bg(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx;
    int pixel_data_size = (bmp_size - BMP_HEADER_SIZE);
    // We assume the design expects 32‑bit words, so 4 bytes per pixel or so.
    // Real BMPs are BGR, possibly padded, etc. For simplicity, we just pack 4 bytes = 1 word.
    idx = BMP_HEADER_SIZE;

    while (idx < bmp_size) begin
      logic [31:0] word;
      word[7:0]    = bmp_mem[idx+0];
      word[15:8]   = bmp_mem[idx+1];
      word[23:16]  = bmp_mem[idx+2];
      word[31:24]  = bmp_mem[idx+3];
      idx += 4;

      // Drive the signals to the background FIFO
      // In your real design, you might do:
      //   dut.bg_fifo_wr_en = 1;
      //   dut.bg_fifo_din   = word;
      //   wait until !dut.bg_fifo_full, etc.
      // For this skeleton, just model a single cycle write:
      @(posedge clk);
      if (dut.bg_fifo_full) begin
        $display("WARNING: bg_fifo is full, stalling writes");
      end
      dut.bg_fifo_wr_en <= 1'b1;
      dut.bg_fifo_din   <= word;
      @(posedge clk);
      dut.bg_fifo_wr_en <= 1'b0;
    end
  endtask

  // Similarly for push_bmp_to_fifo_fr and push_bmp_to_fifo_for_highlight:
  task push_bmp_to_fifo_fr(
      input byte bmp_mem[],
      input int  bmp_size
  );
    // same structure as above
    // writes to dut.fr_fifo_wr_en and dut.fr_fifo_din
    // ...
  endtask

  task push_bmp_to_fifo_for_highlight(
      input byte bmp_mem[],
      input int  bmp_size
  );
    // same structure, for the highlight path
    // ...
  endtask

  //--------------------------------------------------------------------------
  // Task: read_output_fifo
  // Reads from the highlight output FIFO into our local memory array.
  // Returns the number of bytes read.
  // For a 32‑bit pixel pipeline, we read words and store them as 4 bytes each.
  //--------------------------------------------------------------------------
  function int read_output_fifo(
      output byte bmp_mem[],
      input  int  start_index
  );
    int idx = start_index;
    // We'll just do a naive loop for demonstration.
    while (!dut.highlight_fifo_empty) begin
      // wait for not empty
      @(posedge clk);
      if (!dut.highlight_fifo_empty) begin
        dut.highlight_fifo_rd_en <= 1'b1;
        @(posedge clk); // consume 1 cycle
        dut.highlight_fifo_rd_en <= 1'b0;

        // We assume dut.highlight_fifo_dout has valid data after the read.
        // But in some FIFOs, data is available same cycle or next cycle.
        // We'll read it next cycle for simplicity.
        @(posedge clk);
        logic [31:0] out_word = dut.highlight_fifo_dout;

        // pack into bmp_mem
        bmp_mem[idx+0] = out_word[7:0];
        bmp_mem[idx+1] = out_word[15:8];
        bmp_mem[idx+2] = out_word[23:16];
        bmp_mem[idx+3] = out_word[31:24];
        idx += 4;
      end
    end
    return (idx - start_index);
  endfunction

  //--------------------------------------------------------------------------
  // Task: compare_results
  // Optionally read another BMP (e.g. "golden_output.bmp") and compare
  // with the newly created "OUTPUT_BMP_FILE".
  //--------------------------------------------------------------------------
  task compare_results(
      input string new_file,
      input string ref_file
  );
    // For a full compare, you'd open both files, read them into arrays,
    // and do a byte‑by‑byte check, reporting mismatches.
    // We'll do a skeleton approach:
    integer fd_new, fd_ref;
    byte    mem_new [0:5_000_000];
    byte    mem_ref [0:5_000_000];
    int     size_new, size_ref, br;

    fd_new = $fopen(new_file, "rb");
    if (fd_new != 0) begin
      size_new = $fread(mem_new, fd_new);
      $fclose(fd_new);
    end

    fd_ref = $fopen(ref_file, "rb");
    if (fd_ref != 0) begin
      size_ref = $fread(mem_ref, fd_ref);
      $fclose(fd_ref);
    end

    if (size_new != size_ref) begin
      $display("COMPARE: File sizes differ: new=%0d, ref=%0d", size_new, size_ref);
      return;
    end

    for (int i = 0; i < size_new; i++) begin
      if (mem_new[i] != mem_ref[i]) begin
        $display("COMPARE ERROR: byte[%0d]: new=%02h, ref=%02h", i, mem_new[i], mem_ref[i]);
      end
    end
    $display("COMPARE DONE: %0s vs %0s", new_file, ref_file);
  endtask

endmodule