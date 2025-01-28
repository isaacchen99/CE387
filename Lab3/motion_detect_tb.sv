`timescale 1ns/1ps

module motion_detect_tb;

  parameter string BASE_BMP_FILE       = "base.bmp";
  parameter string PEDESTRIAN_BMP_FILE = "pedestrians.bmp";
  parameter string OUTPUT_BMP_FILE     = "output.bmp";
  parameter int    BMP_HEADER_SIZE     = 54;

  // Testbench clock/reset
  logic clk = 0;
  logic reset = 1;

  // Instance of the DUT
  motion_detect_top dut (
      .clk   (clk),
      .reset (reset)
      // Connect other necessary ports as per the actual module definition
  );

  // Testbench file I/O
  integer fd_base, fd_ped, fd_out, bytes_read, bytes_written;

  // Memory arrays for BMP data
  byte base_bmp_mem       [0 : 5_000_000]; // 5MB buffer
  byte pedestrian_bmp_mem [0 : 5_000_000];
  byte output_bmp_mem     [0 : 5_000_000];

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
    // Open and read BMP files
    fd_base = $fopen(BASE_BMP_FILE, "rb");
    if (fd_base == 0) begin
      $error("ERROR: Unable to open %0s!", BASE_BMP_FILE);
      $finish;
    end
    bytes_read = $fread(base_bmp_mem, fd_base);
    base_bmp_size = bytes_read;
    $display("Read %0d bytes from %0s", bytes_read, BASE_BMP_FILE);
    $fclose(fd_base);

    fd_ped = $fopen(PEDESTRIAN_BMP_FILE, "rb");
    if (fd_ped == 0) begin
      $error("ERROR: Unable to open %0s!", PEDESTRIAN_BMP_FILE);
      $finish;
    end
    bytes_read = $fread(pedestrian_bmp_mem, fd_ped);
    pedestrian_bmp_size = bytes_read;
    $display("Read %0d bytes from %0s", bytes_read, PEDESTRIAN_BMP_FILE);
    $fclose(fd_ped);

    // Wait a few cycles after reset is deasserted
    @(negedge reset);
    repeat (10) @(posedge clk);

    // Push BMP data into FIFOs
    push_bmp_to_fifo_bg(base_bmp_mem, base_bmp_size);
    push_bmp_to_fifo_fr(pedestrian_bmp_mem, pedestrian_bmp_size);
    push_bmp_to_fifo_for_highlight(pedestrian_bmp_mem, pedestrian_bmp_size);

    // Wait for pipeline to process data
    repeat (10000) @(posedge clk);

    // Read the output data
    output_bmp_size = BMP_HEADER_SIZE + read_output_fifo(output_bmp_mem, BMP_HEADER_SIZE);

    // Write the final BMP file to disk
    for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
      output_bmp_mem[i] = pedestrian_bmp_mem[i];  // Copy header from one of the input BMPs
    end
    fd_out = $fopen(OUTPUT_BMP_FILE, "wb");
    if (fd_out == 0) begin
      $error("ERROR: Unable to open output file %0s", OUTPUT_BMP_FILE);
      $finish;
    end
    bytes_written = $fwrite(fd_out, output_bmp_mem, output_bmp_size);
    $display("Wrote %0d bytes to %0s", bytes_written, OUTPUT_BMP_FILE);
    $fclose(fd_out);

    // Optionally compare the output file to a known reference
    compare_results(OUTPUT_BMP_FILE, "golden_output.bmp");

    $finish;
  end

  // Task definitions (as detailed in earlier message)
  task push_bmp_to_fifo_bg(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx = BMP_HEADER_SIZE; // Start index after BMP header
    while (idx < bmp_size) begin
        logic [31:0] word;
        word = {bmp_mem[idx+3], bmp_mem[idx+2], bmp_mem[idx+1], bmp_mem[idx]};
        idx += 4;

        @(posedge clk);
        while (dut.bg_fifo_full) @(posedge clk); // Wait if FIFO is full

        dut.bg_fifo_wr_en = 1'b1;
        dut.bg_fifo_din = word;
        @(posedge clk);
        dut.bg_fifo_wr_en = 1'b0;
    end
  endtask

  task push_bmp_to_fifo_fr(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx = BMP_HEADER_SIZE;
    while (idx < bmp_size) begin
        logic [31:0] word;
        word = {bmp_mem[idx+3], bmp_mem[idx+2], bmp_mem[idx+1], bmp_mem[idx]};
        idx += 4;

        @(posedge clk);
        while (dut.fr_fifo_full) @(posedge clk); // Wait if FIFO is full

        dut.fr_fifo_wr_en = 1'b1;
        dut.fr_fifo_din = word;
        @(posedge clk);
        dut.fr_fifo_wr_en = 1'b0;
    end
  endtask

  task push_bmp_to_fifo_for_highlight(
      input byte bmp_mem[],
      input int  bmp_size
  );
    int idx = BMP_HEADER_SIZE;
    while (idx < bmp_size) begin
        logic [31:0] word;
        word = {bmp_mem[idx+3], bmp_mem[idx+2], bmp_mem[idx+1], bmp_mem[idx]};
        idx += 4;

        @(posedge clk);
        while (dut.highlight_fifo_full) @(posedge clk); // Wait if FIFO is full

        dut.highlight_fifo_wr_en = 1'b1;
        dut.highlight_fifo_din = word;
        @(posedge clk);
        dut.highlight_fifo_wr_en = 1'b0;
    end
  endtask

  function int read_output_fifo(
      output byte bmp_mem[],
      input  int  start_index
  );
    int idx = start_index;
    while (!dut.highlight_fifo_empty) begin
        @(posedge clk);
        if (!dut.highlight_fifo_empty) begin
            dut.highlight_fifo_rd_en = 1'b1;
            @(posedge clk); // consume 1 cycle
            dut.highlight_fifo_rd_en = 1'b0;

            @(posedge clk);
            logic [31:0] out_word = dut.highlight_fifo_dout;

            bmp_mem[idx+0] = out_word[7:0];
            bmp_mem[idx+1] = out_word[15:8];
            bmp_mem[idx+2] = out_word[23:16];
            bmp_mem[idx+3] = out_word[31:24];
            idx += 4;
        end
    end
    return (idx - start_index);
  endfunction

  task compare_results(
      input string new_file,
      input string ref_file
  );
    integer fd_new, fd_ref;
    byte mem_new[0:5000000];
    byte mem_ref[0:5000000];
    integer size_new, size_ref, i;
    boolean mismatch_found = 0;

    fd_new = $fopen(new_file, "rb");
    if (fd_new == 0) begin
        $display("Error opening new file %s for comparison", new_file);
        $finish;
    end
    size_new = $fread(mem_new, fd_new);
    $fclose(fd_new);

    fd_ref = $fopen(ref_file, "rb");
    if (fd_ref == 0) begin
        $display("Error opening reference file %s for comparison", ref_file);
        $finish;
    end
    size_ref = $fread(mem_ref, fd_ref);
    $fclose(fd_ref);

    if (size_new != size_ref) begin
        $display("File size mismatch: new=%d bytes, ref=%d bytes", size_new, size_ref);
        mismatch_found = 1;
    end else begin
        for (i = 0; i < size_new; i++) begin
            if (mem_new[i] != mem_ref[i]) begin
                $display("Mismatch at byte %d: new=0x%02h, ref=0x%02h", i, mem_new[i], mem_ref[i]);
                mismatch_found = 1;
            end
    end

    if (!mismatch_found)
        $display("Files %s and %s are identical.", new_file, ref_file);
    else
        $display("Mismatch found in files.");
  endtask

endmodule