module sobel_top #(
  parameter WIDTH  = 720,
  parameter HEIGHT = 540
) (
  input  logic        clock,
  input  logic        reset,
  output logic        in_full,
  input  logic        in_wr_en,
  input  logic [23:0] in_din,
  output logic        out_empty,
  input  logic        out_rd_en,
  output logic [7:0]  out_dout
);

  logic [23:0] fifo_in_dout;
  logic        fifo_in_empty;
  logic        fifo_in_rd_en;
  logic [7:0]  gray_out_din;
  logic        gray_out_wr_en;
  logic        fifo_gray2sobel_full;
  logic [7:0]  fifo_gray2sobel_dout;
  logic        fifo_gray2sobel_empty;
  logic        fifo_gray2sobel_rd_en;
  logic [7:0]  sobel_out_din;
  logic        sobel_out_wr_en;
  logic        fifo_out_full;

  fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(24)
  ) fifo_in_inst (
    .reset   (reset),
    .wr_clk  (clock),
    .wr_en   (in_wr_en),
    .din     (in_din),
    .full    (in_full),
    .rd_clk  (clock),
    .rd_en   (fifo_in_rd_en),
    .dout    (fifo_in_dout),
    .empty   (fifo_in_empty)
  );

  grayscale grayscale_inst (
    .clock    (clock),
    .reset    (reset),
    .in_rd_en (fifo_in_rd_en),
    .in_empty (fifo_in_empty),
    .in_dout  (fifo_in_dout),
    .out_wr_en(gray_out_wr_en),
    .out_full (fifo_gray2sobel_full),
    .out_din  (gray_out_din)
  );

  fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(8)
  ) fifo_gray2sobel_inst (
    .reset   (reset),
    .wr_clk  (clock),
    .wr_en   (gray_out_wr_en),
    .din     (gray_out_din),
    .full    (fifo_gray2sobel_full),
    .rd_clk  (clock),
    .rd_en   (fifo_gray2sobel_rd_en),
    .dout    (fifo_gray2sobel_dout),
    .empty   (fifo_gray2sobel_empty)
  );

  sobel #(
    .IMG_WIDTH (WIDTH),
    .IMG_HEIGHT(HEIGHT)
  ) sobel_inst (
    .clock    (clock),
    .reset    (reset),
    .in_rd_en (fifo_gray2sobel_rd_en),
    .in_empty (fifo_gray2sobel_empty),
    .in_dout  (fifo_gray2sobel_dout),
    .out_wr_en(sobel_out_wr_en),
    .out_full (fifo_out_full),
    .out_din  (sobel_out_din)
  );

  fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(8)
  ) fifo_out_inst (
    .reset   (reset),
    .wr_clk  (clock),
    .wr_en   (sobel_out_wr_en),
    .din     (sobel_out_din),
    .full    (fifo_out_full),
    .rd_clk  (clock),
    .rd_en   (out_rd_en),
    .dout    (out_dout),
    .empty   (out_empty)
  );

endmodule
