
module vectorsum_top #(  
    parameter DATA_WIDTH = 32,
    parameter FIFO_BUFFER_SIZE = 32)
(
    input  logic clock,
    input  logic reset,
    output logic x_full,
    input  logic x_wr_en,
    input  logic [DATA_WIDTH-1:0] x_din,
    output logic y_full,
    input  logic y_wr_en,
    input  logic [DATA_WIDTH-1:0] y_din,
    input  logic z_rd_en,
    output logic z_empty,
    output logic [DATA_WIDTH-1:0] z_dout
);

logic [DATA_WIDTH-1:0] x_dout, y_dout, z_din;
logic x_empty, y_empty, z_full;
logic x_rd_en, y_rd_en, z_wr_en;

vectorsum #(
  .DATA_WIDTH(DATA_WIDTH)
) vectorsum_inst (
    .clock(clock),
    .reset(reset),
    .x_dout(x_dout),
    .x_rd_en(x_rd_en),
    .x_empty(x_empty),
    .y_dout(y_dout),
    .y_rd_en(y_rd_en),
    .y_empty(y_empty),
    .z_din(z_din),
    .z_full(z_full),
    .z_wr_en(z_wr_en)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) x_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(x_wr_en),
    .din(x_din),
    .full(x_full),
    .rd_clk(clock),
    .rd_en(x_rd_en),
    .dout(x_dout),
    .empty(x_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) y_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(y_wr_en),
    .din(y_din),
    .full(y_full),
    .rd_clk(clock),
    .rd_en(y_rd_en),
    .dout(y_dout),
    .empty(y_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(DATA_WIDTH)
) z_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(z_wr_en),
    .din(z_din),
    .full(z_full),
    .rd_clk(clock),
    .rd_en(z_rd_en),
    .dout(z_dout),
    .empty(z_empty)
);

endmodule