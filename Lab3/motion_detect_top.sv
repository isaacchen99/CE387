module motion_detect_top (
  input logic clk,
  input logic reset
);

  // Base (background) image FIFO
  logic bg_fifo_full, bg_fifo_empty;
  logic bg_fifo_wr_en;
  logic [31:0] bg_fifo_din;
  logic [31:0] bg_fifo_dout;
  logic bg_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(32),
    .FIFO_BUFFER_SIZE(32)
  ) background_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(bg_fifo_wr_en),
    .din(bg_fifo_din),
    .full(bg_fifo_full),
    .rd_clk(clk),
    .rd_en(bg_fifo_rd_en),
    .dout(bg_fifo_dout),
    .empty(bg_fifo_empty)
  );

  // Grayscale pipeline for base image
  logic gray_bg_read_en, gray_bg_write_en;
  logic [7:0] gray_bg_data_out;
  logic bg_gray_fifo_full;

  grayscale grayscale_bg_inst (
    .clk(clk),
    .reset(reset),
    .read_enable(gray_bg_read_en),
    .data_in(bg_fifo_dout),
    .fifo_in_empty(bg_fifo_empty),
    .write_enable(gray_bg_write_en),
    .data_out(gray_bg_data_out),
    .fifo_out_full(bg_gray_fifo_full)
  );

  logic [7:0] bg_gray_fifo_dout;
  logic bg_gray_fifo_empty, bg_gray_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(32)
  ) bg_gray_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(gray_bg_write_en),
    .din(gray_bg_data_out),
    .full(bg_gray_fifo_full),
    .rd_clk(clk),
    .rd_en(bg_gray_fifo_rd_en),
    .dout(bg_gray_fifo_dout),
    .empty(bg_gray_fifo_empty)
  );

  assign bg_fifo_rd_en = gray_bg_read_en;

  // Frame (pedestrian) image FIFO
  logic fr_fifo_full, fr_fifo_empty;
  logic fr_fifo_wr_en;
  logic [31:0] fr_fifo_din;
  logic [31:0] fr_fifo_dout;
  logic fr_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(32),
    .FIFO_BUFFER_SIZE(32)
  ) frame_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(fr_fifo_wr_en),
    .din(fr_fifo_din),
    .full(fr_fifo_full),
    .rd_clk(clk),
    .rd_en(fr_fifo_rd_en),
    .dout(fr_fifo_dout),
    .empty(fr_fifo_empty)
  );

  // Grayscale pipeline for frame image
  logic gray_fr_read_en, gray_fr_write_en;
  logic [7:0] gray_fr_data_out;
  logic fr_gray_fifo_full;

  grayscale grayscale_fr_inst (
    .clk(clk),
    .reset(reset),
    .read_enable(gray_fr_read_en),
    .data_in(fr_fifo_dout),
    .fifo_in_empty(fr_fifo_empty),
    .write_enable(gray_fr_write_en),
    .data_out(gray_fr_data_out),
    .fifo_out_full(fr_gray_fifo_full)
  );

  logic [7:0] fr_gray_fifo_dout;
  logic fr_gray_fifo_empty, fr_gray_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(32)
  ) fr_gray_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(gray_fr_write_en),
    .din(gray_fr_data_out),
    .full(fr_gray_fifo_full),
    .rd_clk(clk),
    .rd_en(fr_gray_fifo_rd_en),
    .dout(fr_gray_fifo_dout),
    .empty(fr_gray_fifo_empty)
  );

  assign fr_fifo_rd_en = gray_fr_read_en;

  // Background subtract
  logic subtract_wr_en;
  logic [7:0] subtract_data_out;
  logic subtract_fifo_full;

  background_subtract #(.THRESHOLD(50)) subtract_inst (
    .clk(clk),
    .reset(reset),
    .base_read_enable(bg_gray_fifo_rd_en),
    .base_din(bg_gray_fifo_dout),
    .base_fifo_empty(bg_gray_fifo_empty),
    .gray_read_enable(fr_gray_fifo_rd_en),
    .gray_din(fr_gray_fifo_dout),
    .gray_fifo_empty(fr_gray_fifo_empty),
    .write_enable(subtract_wr_en),
    .data_out(subtract_data_out),
    .fifo_out_full(subtract_fifo_full)
  );

  logic [7:0] sub_fifo_dout;
  logic sub_fifo_empty, sub_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(32)
  ) sub_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(subtract_wr_en),
    .din(subtract_data_out),
    .full(subtract_fifo_full),
    .rd_clk(clk),
    .rd_en(sub_fifo_rd_en),
    .dout(sub_fifo_dout),
    .empty(sub_fifo_empty)
  );

  // Additional FIFO for highlight (original color)
  logic fr_hl_fifo_full, fr_hl_fifo_empty;
  logic fr_hl_fifo_wr_en;
  logic [31:0] fr_hl_fifo_din;
  logic [31:0] fr_hl_fifo_dout;
  logic fr_hl_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(32),
    .FIFO_BUFFER_SIZE(32)
  ) frame_fifo_for_highlight_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(fr_hl_fifo_wr_en),
    .din(fr_hl_fifo_din),
    .full(fr_hl_fifo_full),
    .rd_clk(clk),
    .rd_en(fr_hl_fifo_rd_en),
    .dout(fr_hl_fifo_dout),
    .empty(fr_hl_fifo_empty)
  );

  // Feed the same "pedestrians" data (fr_fifo_din) to the highlight FIFO
  assign fr_hl_fifo_wr_en = fr_fifo_wr_en;
  assign fr_hl_fifo_din    = fr_fifo_din;

  // Highlight module
  logic highlight_wr_en;
  logic [31:0] highlight_data_out;
  logic highlight_fifo_full;

  highlight highlight_inst (
    .clk(clk),
    .reset(reset),
    .base_read_enable(fr_hl_fifo_rd_en),
    .base_din(fr_hl_fifo_dout),
    .base_fifo_empty(fr_hl_fifo_empty),
    .subt_read_enable(sub_fifo_rd_en),
    .subt_din(sub_fifo_dout),
    .subt_fifo_empty(sub_fifo_empty),
    .write_enable(highlight_wr_en),
    .data_out(highlight_data_out),
    .fifo_out_full(highlight_fifo_full)
  );

  logic [31:0] highlight_fifo_dout;
  logic highlight_fifo_empty, highlight_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(32),
    .FIFO_BUFFER_SIZE(32)
  ) highlight_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(highlight_wr_en),
    .din(highlight_data_out),
    .full(highlight_fifo_full),
    .rd_clk(clk),
    .rd_en(highlight_fifo_rd_en),
    .dout(highlight_fifo_dout),
    .empty(highlight_fifo_empty)
  );

endmodule