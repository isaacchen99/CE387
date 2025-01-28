`timescale 1ns/1ps

module motion_detect_tb;

  localparam int BMP_HEADER_SIZE = 54;
  string base_bmp_file       = "base.bmp";
  string pedestrian_bmp_file = "pedestrians.bmp";
  string output_bmp_file     = "output_detect.bmp";
  string golden_bmp_file     = "img_out.bmp";

  logic clk = 0;
  logic reset;

  // Instantiate DUT
  motion_detect_top dut(.clk(clk), .reset(reset));

  // Clock
  always #5 clk = ~clk;

  // Reset
  initial begin
    reset = 1; 
    #100;
    reset = 0;
  end

  // Main stimulus
  initial begin
    wait(reset == 0);
    #10;

    byte base_hdr[BMP_HEADER_SIZE];
    byte ped_hdr[BMP_HEADER_SIZE];
    byte base_data[];
    byte ped_data[];

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

    byte highlight_data[];
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

  // Read BMP File
  task read_bmp_file(
    input  string filename,
    output byte header[],
    output byte image_data[]
  );
    int fd = $fopen(filename, "rb");
    if (!fd) $fatal("Cannot open %s", filename);

    for (int i = 0; i < BMP_HEADER_SIZE; i++)
      if (!$feof(fd)) header[i] = $fgetc(fd);

    image_data = new[0];
    while (!$feof(fd)) begin
      int c = $fgetc(fd);
      if (c < 0) break;
      image_data.push_back(byte'(c));
    end
    $fclose(fd);
  endtask

  // Push to FIFO (32-bit wide)
  task push_image_data_to_fifo(
    input byte in_data[],
    input wire fifo_full,
    input wire fifo_empty,
    output logic wr_en,
    output logic [31:0] data_out
  );
    int idx = 0;
    int words = (in_data.size() + 3) / 4;
    wr_en = 0;
    @(posedge clk);

    for (int w = 0; w < words; w++) begin
      while (fifo_full) @(posedge clk);
      logic [31:0] tmp = 0;
      for (int b = 0; b < 4; b++) begin
        if (idx < in_data.size()) tmp[8*b +: 8] = in_data[idx++];
      end
      data_out = tmp;
      wr_en = 1;
      @(posedge clk);
      wr_en = 0;
    end
  endtask

  // Wait for pipeline flush (placeholder)
  task wait_for_pipeline_flush();
    repeat (10000) @(posedge clk);
  endtask

  // Pull from FIFO (32-bit wide)
  task pull_image_data_from_fifo(
    output byte out_data[],
    input wire fifo_empty,
    output logic rd_en,
    input wire [31:0] data_in
  );
    int total = out_data.size();
    int words = (total + 3) / 4;
    int idx = 0;
    rd_en = 0;
    @(posedge clk);

    for (int w = 0; w < words; w++) begin
      while (fifo_empty) @(posedge clk);
      rd_en = 1;
      @(posedge clk);
      rd_en = 0;
      for (int b = 0; b < 4; b++) begin
        if (idx < total) out_data[idx++] = data_in[8*b +: 8];
      end
    end
  endtask

  // Write BMP File
  task write_bmp_file(
    input string filename,
    input byte header[],
    input byte image_data[]
  );
    int fd = $fopen(filename, "wb");
    if (!fd) $fatal("Cannot write %s", filename);
    for (int i = 0; i < BMP_HEADER_SIZE; i++) $fwrite(fd, "%c", header[i]);
    for (int i = 0; i < image_data.size(); i++) $fwrite(fd, "%c", image_data[i]);
    $fclose(fd);
  endtask

  // Compare against golden
  task compare_against_golden(
    input string test_file,
    input string golden_file
  );
    byte thdr[BMP_HEADER_SIZE], ghdr[BMP_HEADER_SIZE];
    byte tdata[], gdata[];
    int fd = $fopen(golden_file, "rb");
    if (!fd) begin
      $display("No golden file '%s'.", golden_file);
      return;
    end
    $fclose(fd);

    read_bmp_file(test_file, thdr, tdata);
    read_bmp_file(golden_file, ghdr, gdata);

    if (tdata.size() != gdata.size()) begin
      $display("Size mismatch: %0d vs %0d", tdata.size(), gdata.size());
      return;
    end

    int mismatches = 0;
    for (int i = 0; i < tdata.size(); i++)
      if (tdata[i] != gdata[i]) mismatches++;

    if (mismatches)
      $display("FAIL: %0d mismatches.", mismatches);
    else
      $display("PASS: Matches golden file!");
  endtask

endmodule