import uvm_pkg::*;

interface my_uvm_if #(parameter FIFO_DATA_WIDTH = 16);
    // Clock and reset
    logic clock;
    logic reset;
    
    // Input port signals
    logic        wr_en;
    logic [FIFO_DATA_WIDTH-1:0] data_in;
    logic        full;
    
    // Cosine FIFO signals
    logic        cos_rd_en;
    logic [FIFO_DATA_WIDTH-1:0] cos_data_out;
    logic        cos_empty;
    
    // Sine FIFO signals
    logic        sin_rd_en;
    logic [FIFO_DATA_WIDTH-1:0] sin_data_out;
    logic        sin_empty;
    
endinterface