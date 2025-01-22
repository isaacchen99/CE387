module matmul_top #(
  parameter N = 8,
  parameter LOG2_N = 3,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 6
) (
  input  logic clock,
  input  logic reset,
  input  logic start,
  output logic done,

  input logic a_wr_en,
  input logic [ADDR_WIDTH-1 : 0] a_wr_addr,
  input logic [DATA_WIDTH-1 : 0] a_din,

  input logic b_wr_en,
  input logic [ADDR_WIDTH-1 : 0] b_wr_addr,
  input logic [DATA_WIDTH-1 : 0] b_din,

  input logic [ADDR_WIDTH-1 : 0] c_rd_addr,
  output logic [DATA_WIDTH-1 : 0] c_dout
);

  // internal wires
  logic [DATA_WIDTH-1 : 0] a_dout;
  logic [ADDR_WIDTH-1 : 0] a_rd_addr;

  logic [DATA_WIDTH-1 : 0] b_dout;
  logic [ADDR_WIDTH-1 : 0] b_rd_addr;

  logic c_wr_en;
  logic [ADDR_WIDTH-1 : 0] c_wr_addr;
  logic [DATA_WIDTH-1 : 0] c_din;

  matmul #(
    .N(N),
    .LOG2_N(LOG2_N),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) matmul_inst (
    .clock(clock),
    .reset(reset),
    .start(start),
    .done(done),
    .a_dout(a_dout),
    .a_rd_addr(a_rd_addr),
    .b_dout(b_dout),
    .b_rd_addr(b_rd_addr),
    .c_din(c_din),
    .c_wr_addr(c_wr_addr),
    .c_wr_en(c_wr_en)
  );

  bram #(
    .BRAM_ADDR_WIDTH(ADDR_WIDTH),
    .BRAM_DATA_WIDTH(DATA_WIDTH)
  ) a_inst (
    .clock(clock),
    .rd_addr(a_rd_addr),
    .wr_en(a_wr_en),
    .wr_addr(a_wr_addr),
    .din(a_din),
    .dout(a_dout)
  );

  bram #(
    .BRAM_ADDR_WIDTH(ADDR_WIDTH),
    .BRAM_DATA_WIDTH(DATA_WIDTH)
  ) b_inst (
    .clock(clock),
    .rd_addr(b_rd_addr),
    .wr_en(b_wr_en),
    .wr_addr(b_wr_addr),
    .din(b_din),
    .dout(b_dout)
  );

  bram #(
    .BRAM_ADDR_WIDTH(ADDR_WIDTH),
    .BRAM_DATA_WIDTH(DATA_WIDTH)
  ) c_inst (
    .clock(clock),
    .rd_addr(c_rd_addr),
    .wr_en(c_wr_en),
    .wr_addr(c_wr_addr),
    .din(c_din),
    .dout(c_dout)
  );

endmodule