module cordic_top #(
  parameter FIFO_DATA_WIDTH = 16,
  parameter FIFO_BUFFER_SIZE = 1024,
  parameter NUM_STAGES = 16
) (
  input logic clock,
  input logic reset,

  // fifo write
  input logic wr_en,
  input logic [FIFO_DATA_WIDTH-1 : 0] data_in,
  output logic full,

  // cos fifo read
  input logic cos_rd_en,
  output logic cos_data_out,
  output logic cos_empty,

  // sin fifo read
  input logic sin_rd_en,
  output logic sin_data_out,
  output logic sin_empty
);

// internal signals
logic input_fifo_rd_en;
logic [FIFO_DATA_WIDTH-1 : 0] input_fifo_data_out;
logic input_fifo_empty;

logic sin_fifo_wr_en;
logic [FIFO_DATA_WIDTH-1 : 0] sin_fifo_data_in;
logic sin_fifo_full;

logic cos_fifo_wr_en;
logic [FIFO_DATA_WIDTH-1 : 0] cos_fifo_data_in;
logic cos_fifo_full;

fifo #(
  .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
  .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH)
) input_fifo (
  .reset(reset),
  .wr_clk(clock),
  .rd_clk(clock),
  
  .wr_en(wr_en),
  .din(data_in),
  .full(full),

  .rd_en(input_fifo_rd_en),
  .dout(input_fifo_data_out),
  .empty(input_fifo_empty)
);

cordic #(
  .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
  .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
  .NUM_STAGES(NUM_STAGES)
) cordic_inst (
  .clock(clock),
  .reset(reset),

  .rd_en(input_fifo_rd_en),
  .data_in(input_fifo_data_out),
  .empty(input_fifo_empty),

  .cos_wr_en(cos_fifo_wr_en),
  .cos_data_out(cos_fifo_data_in),
  .cos_full(cos_fifo_full),

  .sin_wr_en(sin_fifo_wr_en),
  .sin_data_out(sin_fifo_data_in),
  .sin_full(sin_fifo_full)
);

fifo #(
  .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
  .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH)
) cos_fifo (
  .reset(reset),
  .wr_clk(clock),
  .rd_clk(clock),
  
  .wr_en(cos_fifo_wr_en),
  .din(cos_fifo_data_in),
  .full(cos_fifo_full),

  .rd_en(cos_rd_en),
  .dout(cos_data_out),
  .empty(cos_empty)
);

fifo #(
  .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
  .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH)
) sin_fifo (
  .reset(reset),
  .wr_clk(clock),
  .rd_clk(clock),
  
  .wr_en(sin_fifo_wr_en),
  .din(sin_fifo_data_in),
  .full(sin_fifo_full),

  .rd_en(sin_rd_en),
  .dout(sin_data_out),
  .empty(sin_empty)
);

endmodule