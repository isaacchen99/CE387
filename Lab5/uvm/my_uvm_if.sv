import uvm_pkg::*;

interface my_uvm_if;
    logic        clk;
    logic        reset;

    logic        in_fifo_wr_en;
    logic  [7:0] in_fifo_din;
    logic        in_fifo_full;

    logic        out_fifo_rd_en;
    logic  [7:0] out_fifo_dout;
    logic        out_fifo_empty;
    logic        out_fifo_full;
endinterface