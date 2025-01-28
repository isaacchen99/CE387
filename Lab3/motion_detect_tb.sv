`timescale 1ns/1ps

module motion_detect_tb;

  // -------------------------------------
  // Parameters
  // -------------------------------------
  localparam int BMP_HEADER_SIZE = 54;  // Standard BMP header size (in bytes)

  // Filenames for input and output
  string base_bmp_file       = "base.bmp";
  string pedestrian_bmp_file = "pedestrians.bmp";
  string output_bmp_file     = "output_detect.bmp";
  string golden_bmp_file     = "img_out.bmp";  // <-- GOLDEN FILE (renamed here)

  // -------------------------------------
  // DUT I/O
  // -------------------------------------
  logic clk;
  logic reset;

  // Wires to drive the background fifo
  wire bg_fifo_full;
  wire bg_fifo_empty;
  logic bg_fifo_wr_en;
  logic [31:0] bg_fifo_din;
  wire [31:0] bg_fifo_dout;
  wire bg_fifo_rd_en;

  // Wires to drive the frame fifo
  wire fr_fifo_full;
  wire fr_fifo_empty;
  logic fr_fifo_wr_en;
  logic [31:0] fr_fifo_din;
  wire [31:0] fr_fifo_dout;
  wire fr_fifo_rd_en;

  // Similarly, the highlight output FIFO
  wire highlight_fifo_full;
  wire highlight_fifo_empty;
  wire highlight_fifo_rd_en;
  wire [31:0] highlight_fifo_dout;

  // Instantiate the DUT
  motion_detect_top dut (
    .clk   (clk),
    .reset (reset)
    // All internal connections are done inside the DUT
  );

  // -------------------------------------
  // Clock generation
  // -------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz -> period 10ns
  end

  // -------------------------------------
  // Reset logic
  // -------------------------------------
  initial begin
    reset = 1;
    #100;
    reset = 0;
  end

  // -------------------------------------
  // Stimulus: read BMP files, push data
  // -------------------------------------
  initial begin
    // Wait for reset deassert
    wait(reset == 0);
    // small delay to ensure everything is stable
    #10;

    // We’ll store the header and pixel data in arrays
    byte   base_bmp_header    [0:BMP_HEADER_SIZE-1];
    byte   pedestrian_bmp_hdr [0:BMP_HEADER_SIZE-1];

    byte   base_image_data      [];
    byte   pedestrian_image_data[];

    // 1. Read the base.bmp file
    read_bmp_file(base_bmp_file, base_bmp_header, base_image_data);

    // 2. Read the pedestrians.bmp file
    read_bmp_file(pedestrian_bmp_file, pedestrian_bmp_hdr, pedestrian_image_data);

    // (Optional) You could check that the headers have consistent width/height 
    // if you want a strict check. We'll assume they're the same dimension.

    // 3. Push the base image data into the DUT’s background FIFO
    automatic int num_base_pixels = base_image_data.size();
    push_image_data_to_fifo(
      base_image_data,
      dut.background_fifo_inst.full,
      dut.background_fifo_inst.empty,
      bg_fifo_wr_en,
      bg_fifo_din
    );

    // 4. Push the pedestrian (frame) image data into the DUT’s frame FIFO
    automatic int num_fr_pixels = pedestrian_image_data.size();
    push_image_data_to_fifo(
      pedestrian_image_data,
      dut.frame_fifo_inst.full,
      dut.frame_fifo_inst.empty,
      fr_fifo_wr_en,
      fr_fifo_din
    );

    // 5. Wait long enough for pipeline to process everything
    wait_for_pipeline_flush();

    // 6. Now read the processed (highlighted) data from the highlight FIFO
    byte highlight_data[];
    highlight_data = new[ num_fr_pixels ]; // same size as input frames

    pull_image_data_from_fifo(
      highlight_data,
      dut.highlight_fifo_inst.empty,
      highlight_fifo_rd_en,
      highlight_fifo_dout
    );

    // 7. Write out the resulting image with the same header (or the base header)
    write_bmp_file(output_bmp_file, base_bmp_header, highlight_data);

    // 8. Compare against the golden file (renamed to "img_out.bmp")
    compare_against_golden(output_bmp_file, golden_bmp_file);

    // 9. Finish
    $display("Simulation complete");
    $finish;
  end

  // -------------------------------------
  // Task: Read BMP File
  // -------------------------------------
  task read_bmp_file(
    input  string filename,
    output byte   header   [ ],
    output byte   image_data[]
  );
    int fd;
    int ret;
    byte file_byte;

    // open the file in read-binary mode
    fd = $fopen(filename, "rb");
    if (fd == 0) begin
      $error("ERROR: Could not open file %0s", filename);
      $finish;
    end

    // Read header (54 bytes) 
    for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
      ret = $fread(file_byte, fd);
      header[i] = file_byte;
    end

    // Read remainder of file
    image_data = new[0]; // Clear existing data
    while (!$feof(fd)) begin
      ret = $fread(file_byte, fd);
      if (ret == 0) break;
      image_data.push_back(file_byte);
    end

    $fclose(fd);
    $display("Read BMP file %s, header + %0d bytes data", filename, image_data.size());
  endtask

  // -------------------------------------
  // Task: Push image data into a 32-bit wide FIFO
  // -------------------------------------
  task push_image_data_to_fifo(
    input byte image_data[],
    input wire fifo_full,
    input wire fifo_empty, // not necessarily used here
    output logic wr_en,
    output logic [31:0] data_out
  );
    int n_bytes = image_data.size();
    int words   = (n_bytes+3)/4; // round up
    int idx     = 0;

    // Reset the write enable
    wr_en = 0;
    @(posedge clk);

    for (int i = 0; i < words; i++) begin
      logic [31:0] word_val = 32'h0;

      for (int b = 0; b < 4; b++) begin
        if (idx < n_bytes) begin
          word_val[8*b +:8] = image_data[idx];
          idx++;
        end 
        else begin
          word_val[8*b +:8] = 8'h00; // pad if not enough bytes
        end
      end

      // Wait until FIFO is not full
      while (fifo_full) begin
        @(posedge clk);
      end

      data_out = word_val;
      wr_en    = 1;
      @(posedge clk);
      wr_en    = 0;
    end

    $display("Pushed %0d bytes (%0d words) into FIFO", n_bytes, words);
  endtask

  // -------------------------------------
  // Task: Wait for pipeline flush
  // -------------------------------------
  task wait_for_pipeline_flush();
    // This is just a placeholder. Adjust for your pipeline length.
    repeat (10000) @(posedge clk);
  endtask

  // -------------------------------------
  // Task: Pull image data from a 32-bit wide FIFO
  // -------------------------------------
  task pull_image_data_from_fifo(
    output byte highlight_data[],
    input  wire fifo_empty,
    output logic rd_en,
    input  wire [31:0] data_in
  );
    int total_bytes = highlight_data.size();
    int words   = (total_bytes+3)/4;
    int idx     = 0;

    rd_en = 0;
    @(posedge clk);

    for (int i = 0; i < words; i++) begin
      // Wait until FIFO is not empty
      while (fifo_empty) @(posedge clk);

      rd_en = 1;
      @(posedge clk);
      rd_en = 0;

      for (int b = 0; b < 4; b++) begin
        if (idx < total_bytes) begin
          highlight_data[idx] = data_in[8*b +:8];
          idx++;
        end
      end
    end

    $display("Pulled %0d bytes (%0d words) from highlight FIFO", total_bytes, words);
  endtask

  // -------------------------------------
  // Task: Write BMP File
  // -------------------------------------
  task write_bmp_file(
    input string filename,
    input byte   header[],
    input byte   image_data[]
  );
    int fd;
    fd = $fopen(filename, "wb");
    if (fd == 0) begin
      $error("ERROR: Could not open output file %0s", filename);
      return;
    end

    // Write header (54 bytes)
    for (int i = 0; i < BMP_HEADER_SIZE; i++) begin
      $fwrite(fd, "%c", header[i]);
    end

    // Write image data
    for (int i = 0; i < image_data.size(); i++) begin
      $fwrite(fd, "%c", image_data[i]);
    end

    $fclose(fd);
    $display("Wrote output BMP file %s", filename);
  endtask

  // -------------------------------------
  // Task: Compare against golden file
  // -------------------------------------
  task compare_against_golden(input string test_file, golden_file);
    byte test_header   [0:BMP_HEADER_SIZE-1];
    byte golden_header [0:BMP_HEADER_SIZE-1];
    byte test_data     [];
    byte golden_data   [];

    // First, check if golden file can be opened
    int check_fd = $fopen(golden_file, "rb");
    if (check_fd == 0) begin
      $display("No golden file '%s' found to compare, skipping...", golden_file);
      return;
    end
    else begin
      $fclose(check_fd);
    end

    read_bmp_file(test_file,    test_header,   test_data);
    read_bmp_file(golden_file,  golden_header, golden_data);

    if (test_data.size() != golden_data.size()) begin
      $display("ERROR: Output size %0d != Golden size %0d", 
               test_data.size(), golden_data.size());
      return;
    end

    // Compare pixel data
    int mismatches = 0;
    for (int i = 0; i < test_data.size(); i++) begin
      if (test_data[i] != golden_data[i]) begin
        mismatches++;
        if (mismatches < 10) begin
          $display("Mismatch at byte %0d: got 0x%02h, expected 0x%02h",
                   i, test_data[i], golden_data[i]);
        end
      end
    end

    if (mismatches == 0) begin
      $display("PASS: Output matches golden file '%s'!", golden_file);
    end else begin
      $display("FAIL: Found %0d mismatches vs golden file '%s'.", 
               mismatches, golden_file);
    end
  endtask

endmodule