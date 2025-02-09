
module grayscale_top #(
    parameter WIDTH = 720,
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

logic [23:0] in_dout;
logic        in_empty;
logic        in_rd_en;
logic  [7:0] out_din;
logic        out_full;
logic        out_wr_en;


grayscale #(
) grayscale_inst (
    .clock(clock),
    .reset(reset),
    .in_dout(in_dout),
    .in_rd_en(in_rd_en),
    .in_empty(in_empty),
    .out_din(out_din),
    .out_full(out_full),
    .out_wr_en(out_wr_en)
);

fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(24)
) fifo_in_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(in_din),
    .full(in_full),
    .rd_clk(clock),
    .rd_en(in_rd_en),
    .dout(in_dout),
    .empty(in_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(256),
    .FIFO_DATA_WIDTH(8)
) fifo_out_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(out_wr_en),
    .din(out_din),
    .full(out_full),
    .rd_clk(clock),
    .rd_en(out_rd_en),
    .dout(out_dout),
    .empty(out_empty)
);

endmodule
