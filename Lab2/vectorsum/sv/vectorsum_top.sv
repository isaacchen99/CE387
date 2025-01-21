
module vectorsum_top 
#(  parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter VECTOR_SIZE = 1024)
(
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  start,
    output logic                  done,
    input  logic [DATA_WIDTH-1:0] x_din,
    input  logic [ADDR_WIDTH-1:0] x_wr_addr,
    input  logic                  x_wr_en,
    input  logic [DATA_WIDTH-1:0] y_din,
    input  logic [ADDR_WIDTH-1:0] y_wr_addr,
    input  logic                  y_wr_en,
    output logic [DATA_WIDTH-1:0] z_dout,
    input  logic [ADDR_WIDTH-1:0] z_rd_addr
);

logic [DATA_WIDTH-1:0] x_dout;
logic [ADDR_WIDTH-1:0] x_rd_addr;
logic [DATA_WIDTH-1:0] y_dout;
logic [ADDR_WIDTH-1:0] y_rd_addr;
logic [DATA_WIDTH-1:0] z_din;
logic [ADDR_WIDTH-1:0] z_wr_addr;
logic z_wr_en;

vectorsum #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .VECTOR_SIZE(VECTOR_SIZE)
) vectorsum_inst (
    .clock(clock),
    .reset(reset),
    .start(start),
    .done(done),
    .x_dout(x_dout),
    .x_addr(x_rd_addr),
    .y_dout(y_dout),
    .y_addr(y_rd_addr),
    .z_din(z_din),
    .z_addr(z_wr_addr),
    .z_wr_en(z_wr_en)
);

bram #(
    .BRAM_DATA_WIDTH(DATA_WIDTH),
    .BRAM_ADDR_WIDTH(ADDR_WIDTH)
) x_inst (
    .clock(clock),
    .rd_addr(x_rd_addr),
    .wr_addr(x_wr_addr),
    .wr_en(x_wr_en),
    .dout(x_dout),
    .din(x_din)
);

bram #(
    .BRAM_DATA_WIDTH(DATA_WIDTH),
    .BRAM_ADDR_WIDTH(ADDR_WIDTH)
) y_inst (
    .clock(clock),
    .rd_addr(y_rd_addr),
    .wr_addr(y_wr_addr),
    .wr_en(y_wr_en),
    .dout(y_dout),
    .din(y_din)
);

bram #(
    .BRAM_DATA_WIDTH(DATA_WIDTH),
    .BRAM_ADDR_WIDTH(ADDR_WIDTH)
) z_inst (
    .clock(clock),
    .rd_addr(z_rd_addr),
    .wr_addr(z_wr_addr),
    .wr_en(z_wr_en),
    .dout(z_dout),
    .din(z_din)
);

endmodule
