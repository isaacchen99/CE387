`timescale 1ns/1ps

module motion_detect_tb;

  //-----------------------------------------------------------------------------
  // Parameters and file names
  //-----------------------------------------------------------------------------
  localparam int BMP_HEADER_SIZE = 54;

  string base_bmp_file       = "base.bmp";
  string pedestrian_bmp_file = "pedestrians.bmp";
  string output_bmp_file     = "output_detect.bmp";
  string golden_bmp_file     = "img_out.bmp";

  //-----------------------------------------------------------------------------
  // DUT signals
  //-----------------------------------------------------------------------------
  logic clk;
  logic reset;

  // Instantiate DUT
  motion_detect_top dut (
    .clk   (clk),
    .reset (reset)
  );

  //-----------------------------------------------------------------------------
  // Clock Generation
  //-----------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //-----------------------------------------------------------------------------
  // Reset Generation
  //-----------------------------------------------------------------------------
  initial begin
    reset = 1;
    #100;
    reset = 0;
  end

  //-----------------------------------------------------------------------------
  // Main Test
  //-----------------------------------------------------------------------------
  initial begin
    byte base_hdr    [BMP_HEADER_SIZE];
    byte ped_hdr     [BMP_HEADER_SIZE];
    byte base_data   [];
    byte ped_data    [];
    byte highlight_data[];

    wait (reset == 0);
    #10;

    read_bmp_file(base_bmp_file, base_hdr, base_data);
    read_bmp_file(pedestrian_bmp_file, ped_hdr, ped_data);

    push_image_data_to_fifo(
      base_data,
      dut.background_fifo_inst.full,
      dut.background_fifo_inst.empty,
      dut.bg_fifo_wr_en,
      dut.bg_fifo_din
    );

    push_image_data_to_fifo(
      ped_data,
      dut.frame_fifo_inst.full,
      dut.frame_fifo_inst.empty,
      dut.fr_fifo_wr_en,
      dut.fr_fifo_din
    );

    wait_for_pipeline_flush();

    highlight_data = new[ped_data.size()];
    pull_image_data_from_fifo(
      highlight_data,
      dut.highlight_fifo_inst.empty,
      dut.highlight_fifo_rd_en,
      dut.highlight_fifo_dout
    );

    write_bmp_file(output_bmp_file, base_hdr, highlight_data);
    compare_against_golden(output_bmp_file, golden_bmp_file);

    $display("Done.");
    $finish;
  end

  //-----------------------------------------------------------------------------
  // Task: Read BMP File
  //-----------------------------------------------------------------------------
  task read_bmp_file(
    input  string filename,
    output byte   header[],
    output byte   image_data[]
  );
    int   fd;
    int   i;
    int   c;
    image_data = new[0];

    fd = $fopen(filename, "rb");
    if (fd == 0) begin
      $display("Cannot open %s", filename);
      $finish;
    end

    for (i = 0; i < BMP_HEADER_SIZE; i++) begin
      if (!$feof(fd)) header[i] = $fgetc(fd);
    end

    while (!$feof(fd)) begin
      c = $fgetc(fd);
      if (c < 0) break;
      image_data.push_back(byte'(c));
    end

    $fclose(fd);
  endtask

  //-----------------------------------------------------------------------------
  // Task: Push image data into FIFO (32-bit wide)
  //-----------------------------------------------------------------------------
  task push_image_data_to_fifo(
    input  byte    in_data[],
    input  wire    fifo_full,
    input  wire    fifo_empty,
    output logic   wr_en,
    output logic [31:0] data_out
  );
    int   idx;
    int   words;
    int   w;
    int   b;
    logic [31:0] tmp;

    idx   = 0;
    words = (in_data.size() + 3) / 4;
    wr_en = 0;
    @(posedge clk);

    for (w = 0; w < words; w++) begin
      while (fifo_full) @(posedge clk);

      tmp = 32'h0;
      for (b = 0; b < 4; b++) begin
        if (idx < in_data.size()) begin
          tmp[8*b +: 8] = in_data[idx];
          idx++;
        end
      end

      data_out = tmp;
      wr_en    = 1;
      @(posedge clk);
      wr_en    = 0;
    end
  endtask

  //-----------------------------------------------------------------------------
  // Task: Wait for pipeline flush (placeholder)
  //-----------------------------------------------------------------------------
  task wait_for_pipeline_flush();
    int i;
    for (i = 0; i < 10000; i++) @(posedge clk);
  endtask

  //-----------------------------------------------------------------------------
  // Task: Pull image data from FIFO (32-bit wide)
  //-----------------------------------------------------------------------------
  task pull_image_data_from_fifo(
    output byte    out_data[],
    input  wire    fifo_empty,
    output logic   rd_en,
    input  wire [31:0] data_in
  );
    int total;
    int words;
    int w;
    int b;
    int idx;

    total = out_data.size();
    words = (total + 3) / 4;
    idx   = 0;

    rd_en = 0;
    @(posedge clk);

    for (w = 0; w < words; w++) begin
      while (fifo_empty) @(posedge clk);
      rd_en = 1;
      @(posedge clk);
      rd_en = 0;

      for (b = 0; b < 4; b++) begin
        if (idx < total) begin
          out_data[idx] = data_in[8*b +: 8];
          idx++;
        end
      end
    end
  endtask

  //-----------------------------------------------------------------------------
  // Task: Write BMP File
  //-----------------------------------------------------------------------------
  task write_bmp_file(
    input string filename,
    input byte   header[],
    input byte   image_data[]
  );
    int fd;
    int i;

    fd = $fopen(filename, "wb");
    if (fd == 0) begin
      $display("Cannot write %s", filename);
      return;
    end

    for (i = 0; i < BMP_HEADER_SIZE; i++) $fwrite(fd, "%c", header[i]);
    for (i = 0; i < image_data.size(); i++) $fwrite(fd, "%c", image_data[i]);
    $fclose(fd);
  endtask

  //-----------------------------------------------------------------------------
  // Task: Compare output with golden
  //-----------------------------------------------------------------------------
  task compare_against_golden(
    input string test_file,
    input string golden_file
  );
    int fd;
    byte thdr[BMP_HEADER_SIZE];
    byte ghdr[BMP_HEADER_SIZE];
    byte tdata[];
    byte gdata[];
    int mismatches;
    int i;

    fd = $fopen(golden_file, "rb");
    if (fd == 0) begin
      $display("No golden file '%s'", golden_file);
      return;
    end
    $fclose(fd);

    read_bmp_file(test_file,  thdr, tdata);
    read_bmp_file(golden_file, ghdr, gdata);

    if (tdata.size() != gdata.size()) begin
      $display("Size mismatch: %0d vs %0d", tdata.size(), gdata.size());
      return;
    end

    mismatches = 0;
    for (i = 0; i < tdata.size(); i++) begin
      if (tdata[i] != gdata[i]) mismatches++;
    end

    if (mismatches == 0)
      $display("PASS: Matches golden file!");
    else
      $display("FAIL: %0d mismatches.", mismatches);
  endtask

endmodule