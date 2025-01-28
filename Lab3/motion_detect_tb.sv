`timescale 1 ns / 1 ns

module motion_detect_tb;

localparam string BG_IMG_IN_NAME  = "base.bmp";
localparam string FR_IMG_IN_NAME  = "pedestrians.bmp";
localparam string IMG_OUT_NAME    = "output_hw.bmp";
localparam string IMG_CMP_NAME    = "img_out.bmp";
localparam CLOCK_PERIOD           = 10;
localparam WIDTH                  = 720;
localparam HEIGHT                 = 540;
localparam BYTES_PER_PIXEL        = 3;
localparam BMP_HEADER_SIZE        = 54;
localparam BMP_DATA_SIZE          = WIDTH * HEIGHT * BYTES_PER_PIXEL;

logic clock = 1'b0;
logic reset = 1'b0;
logic start = 1'b0;
logic done  = 1'b0;

integer out_errors = 0;
logic out_read_done = 0;

// DUT
motion_detect_top motion_detect_top_inst (
  .clk(clock),
  .reset(reset)
);

// Clock
always begin
  #(CLOCK_PERIOD/2) clock = ~clock;
end

// Reset
initial begin
  reset = 1'b1;
  #(5*CLOCK_PERIOD);
  reset = 1'b0;
end

// Main control
initial begin : tb_process
  longint unsigned start_time, end_time;
  @(negedge reset);
  @(posedge clock);
  start_time = $time;
  $display("@ %0t: Starting simulation...", start_time);
  start = 1'b1;
  @(posedge clock);
  start = 1'b0;
  wait(out_read_done);
  end_time = $time;
  $display("@ %0t: Simulation done.", end_time);
  $display("Cycles: %0d", (end_time - start_time) / CLOCK_PERIOD);
  $display("Errors: %0d", out_errors);
  $finish;
end

// Read base image
initial begin : bg_read_process
  int file, r, i;
  logic [7:0] tmp [0:BMP_HEADER_SIZE-1];
  logic [7:0] b1, b2, b3;
  @(negedge reset);
  file = $fopen(BG_IMG_IN_NAME, "rb");
  r = $fread(tmp, file, 0, BMP_HEADER_SIZE);
  i = 0;
  while (i < BMP_DATA_SIZE) begin
    @(negedge clock);
    if (!motion_detect_top_inst.bg_fifo_full) begin
      r = $fread(b1, file);
      r = $fread(b2, file);
      r = $fread(b3, file);
      motion_detect_top_inst.bg_fifo_din = {8'h00, b3, b2, b1};
      motion_detect_top_inst.bg_fifo_wr_en = 1'b1;
      i += 3;
    end else begin
      motion_detect_top_inst.bg_fifo_wr_en = 1'b0;
    end
  end
  @(negedge clock);
  motion_detect_top_inst.bg_fifo_wr_en = 1'b0;
  $fclose(file);
end

// Read pedestrian image
initial begin : fr_read_process
  int file, r, i;
  logic [7:0] tmp [0:BMP_HEADER_SIZE-1];
  logic [7:0] b1, b2, b3;
  @(negedge reset);
  file = $fopen(FR_IMG_IN_NAME, "rb");
  r = $fread(tmp, file, 0, BMP_HEADER_SIZE);
  i = 0;
  while (i < BMP_DATA_SIZE) begin
    @(negedge clock);
    if (!motion_detect_top_inst.fr_fifo_full) begin
      r = $fread(b1, file);
      r = $fread(b2, file);
      r = $fread(b3, file);
      motion_detect_top_inst.fr_fifo_din = {8'h00, b3, b2, b1};
      motion_detect_top_inst.fr_fifo_wr_en = 1'b1;
      i += 3;
    end else begin
      motion_detect_top_inst.fr_fifo_wr_en = 1'b0;
    end
  end
  @(negedge clock);
  motion_detect_top_inst.fr_fifo_wr_en = 1'b0;
  $fclose(file);
end

// Write output and compare
initial begin : img_write_process
  int out_file, cmp_file, r, i;
  logic [7:0] tmp [0:BMP_HEADER_SIZE-1];
  logic [31:0] pix32;
  logic [23:0] pix24;
  logic [7:0] cb1, cb2, cb3;

  @(negedge reset);
  @(negedge clock);

  out_file = $fopen(IMG_OUT_NAME, "wb");
  cmp_file = $fopen(IMG_CMP_NAME, "rb");
  r = $fread(tmp, cmp_file, 0, BMP_HEADER_SIZE);
  for (i = 0; i < BMP_HEADER_SIZE; i++)
    $fwrite(out_file, "%c", tmp[i]);

  i = 0;
  while (i < BMP_DATA_SIZE) begin
    @(negedge clock);
    if (!motion_detect_top_inst.highlight_fifo_empty) begin
      r = $fread(cb1, cmp_file);
      r = $fread(cb2, cmp_file);
      r = $fread(cb3, cmp_file);
      pix32 = motion_detect_top_inst.highlight_fifo_dout;
      motion_detect_top_inst.highlight_fifo_rd_en = 1'b1;
      pix24 = pix32[23:0];
      $fwrite(out_file, "%c%c%c", pix24[7:0], pix24[15:8], pix24[23:16]);
      if ((pix24[7:0]   !== cb1) ||
          (pix24[15:8]  !== cb2) ||
          (pix24[23:16] !== cb3)) begin
        out_errors++;
        $display("ERROR @ %0d: got=%02h%02h%02h ref=%02h%02h%02h",
                 i/3,
                 pix24[23:16], pix24[15:8], pix24[7:0],
                 cb3, cb2, cb1);
      end
      i += 3;
    end else begin
      motion_detect_top_inst.highlight_fifo_rd_en = 1'b0;
    end
  end
  @(negedge clock);
  motion_detect_top_inst.highlight_fifo_rd_en = 1'b0;
  $fclose(out_file);
  $fclose(cmp_file);
  out_read_done = 1'b1;
end

endmodule