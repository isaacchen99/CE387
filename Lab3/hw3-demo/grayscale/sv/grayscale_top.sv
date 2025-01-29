module motion_detect_top #(
  parameter WIDTH  = 720,
  parameter HEIGHT = 540
)(
  input  logic         clk,
  input  logic         reset,

  // 1) Background image input (32 bits per pixel)
  output logic         bg_in_full,
  input  logic         bg_in_wr_en,
  input  logic [31:0]  bg_in_din,

  // 2) Frame image input (32 bits per pixel)
  output logic         fr_in_full,
  input  logic         fr_in_wr_en,
  input  logic [31:0]  fr_in_din,

  // 3) Highlight color input (32 bits per pixel)
  //    Used as the “original color” for highlighting motion
  output logic         hl_in_full,
  input  logic         hl_in_wr_en,
  input  logic [31:0]  hl_in_din,

  // Single 32-bit output (highlighted image)
  output logic         out_empty,
  input  logic         out_rd_en,
  output logic [31:0]  out_dout
);

  //----------------------------------------------------------------
  // FIFO #1: Background image (32 bits) -> Grayscale
  //----------------------------------------------------------------
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

  // Drive the background FIFO from external signals
  assign bg_fifo_wr_en = bg_in_wr_en && !bg_in_full;
  assign bg_fifo_din   = bg_in_din;
  assign bg_in_full    = bg_fifo_full;

  // Grayscale stage for background
  logic          gray_bg_read_en, gray_bg_write_en;
  logic [7:0]    gray_bg_data_out;
  logic          bg_gray_fifo_full;

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

  // FIFO for the background grayscale
  logic [7:0] bg_gray_fifo_dout;
  logic       bg_gray_fifo_empty, bg_gray_fifo_rd_en;

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


  //----------------------------------------------------------------
  // FIFO #2: Frame image (32 bits) -> Grayscale
  //----------------------------------------------------------------
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

  assign fr_fifo_wr_en = fr_in_wr_en && !fr_in_full;
  assign fr_fifo_din   = fr_in_din;
  assign fr_in_full    = fr_fifo_full;

  // Grayscale stage for frame image
  logic          gray_fr_read_en, gray_fr_write_en;
  logic [7:0]    gray_fr_data_out;
  logic          fr_gray_fifo_full;

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

  // FIFO for the frame grayscale
  logic [7:0] fr_gray_fifo_dout;
  logic       fr_gray_fifo_empty, fr_gray_fifo_rd_en;

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


  //----------------------------------------------------------------
  // Background Subtract (8-bit in, 8-bit in) -> 8-bit mask
  //----------------------------------------------------------------
  logic          subtract_wr_en;
  logic [7:0]    subtract_data_out;
  logic          subtract_fifo_full;

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

  // FIFO for the subtraction mask
  logic [7:0] sub_fifo_dout;
  logic       sub_fifo_empty, sub_fifo_rd_en;

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


  //----------------------------------------------------------------
  // FIFO #3: Highlight color (32 bits)
  //----------------------------------------------------------------
  logic hl_fifo_full, hl_fifo_empty;
  logic hl_fifo_wr_en;
  logic [31:0] hl_fifo_din;
  logic [31:0] hl_fifo_dout;
  logic hl_fifo_rd_en;

  fifo #(
    .FIFO_DATA_WIDTH(32),
    .FIFO_BUFFER_SIZE(32)
  ) highlight_in_fifo_inst (
    .reset(reset),
    .wr_clk(clk),
    .wr_en(hl_fifo_wr_en),
    .din(hl_fifo_din),
    .full(hl_fifo_full),
    .rd_clk(clk),
    .rd_en(hl_fifo_rd_en),
    .dout(hl_fifo_dout),
    .empty(hl_fifo_empty)
  );

  assign hl_fifo_wr_en = hl_in_wr_en && !hl_in_full;
  assign hl_fifo_din   = hl_in_din;
  assign hl_in_full    = hl_fifo_full;


  //----------------------------------------------------------------
  // Highlight Module
  //----------------------------------------------------------------
  logic          highlight_wr_en;
  logic [31:0]   highlight_data_out;
  logic          highlight_fifo_full;

  highlight highlight_inst (
    .clk(clk),
    .reset(reset),
    .base_read_enable(hl_fifo_rd_en),
    .base_din(hl_fifo_dout),       // color pixel
    .base_fifo_empty(hl_fifo_empty),
    .subt_read_enable(sub_fifo_rd_en),
    .subt_din(sub_fifo_dout),      // 8-bit mask
    .subt_fifo_empty(sub_fifo_empty),
    .write_enable(highlight_wr_en),
    .data_out(highlight_data_out),
    .fifo_out_full(highlight_fifo_full)
  );

  // Final highlighted output FIFO (32 bits)
  logic [31:0] highlight_fifo_dout;
  logic        highlight_fifo_empty, highlight_fifo_rd_en;

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


  //----------------------------------------------------------------
  // Read Enables for submodules
  //----------------------------------------------------------------
  // background_subtract needs data from bg + fr grayscale FIFOs
  assign bg_fifo_rd_en      = subtract_inst.base_read_enable;
  assign fr_fifo_rd_en      = subtract_inst.gray_read_enable;

  // highlight needs data from highlight_in_fifo + sub_fifo
  assign hl_fifo_rd_en      = highlight_inst.base_read_enable;
  assign sub_fifo_rd_en     = highlight_inst.subt_read_enable;

  //----------------------------------------------------------------
  // Final output connections
  //----------------------------------------------------------------
  assign out_empty          = highlight_fifo_empty;
  assign highlight_fifo_rd_en = out_rd_en;
  assign out_dout           = highlight_fifo_dout;

endmodule