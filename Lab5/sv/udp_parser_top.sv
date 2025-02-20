module udp_parser_top (
  input  logic clk,
  input  logic reset,

  //-------------------------------------------------------------------------
  // Input FIFO interface signals (visible to the testbench)
  // These are used to drive the input FIFO.
  //-------------------------------------------------------------------------
  input  logic        in_fifo_wr_en,  // testbench drives write enable
  input  logic [7:0]  in_fifo_din,    // testbench drives data in
  output logic        in_fifo_full,   // FIFO full indicator (monitored by TB)

  //-------------------------------------------------------------------------
  // Output FIFO interface signals (visible to the testbench)
  // These are used by the testbench to read the UDP parser output.
  //-------------------------------------------------------------------------
  input  logic        out_fifo_rd_en, // testbench drives read enable
  output logic [7:0]  out_fifo_dout,  // data read from the output FIFO
  output logic        out_fifo_empty, // FIFO empty indicator (monitored by TB)
  output logic        out_fifo_full   // FIFO full indicator (monitored by TB)
);

  // Internal wires connecting FIFOs and UDP parser.
  wire [7:0] in_fifo_dout_int;
  wire       in_fifo_empty_int;
  wire       in_fifo_rd_en_int;  // driven by UDP parser

  wire [7:0] out_fifo_din_int;
  wire       out_fifo_wr_en_int; // driven by UDP parser

  //-------------------------------------------------------------------------
  // Instantiate the Input FIFO.
  //-------------------------------------------------------------------------
  fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(1024)
  ) input_fifo (
    .reset   (reset),
    .wr_clk  (clk),
    .wr_en   (in_fifo_wr_en),  // driven by testbench
    .din     (in_fifo_din),    // driven by testbench
    .full    (in_fifo_full),   // visible to testbench
    .rd_clk  (clk),
    .rd_en   (in_fifo_rd_en_int), // driven by UDP parser
    .dout    (in_fifo_dout_int),
    .empty   (in_fifo_empty_int)
  );
  
  //-------------------------------------------------------------------------
  // Instantiate the Output FIFO.
  //-------------------------------------------------------------------------
  fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(1024)
  ) output_fifo (
    .reset   (reset),
    .wr_clk  (clk),
    .wr_en   (out_fifo_wr_en_int),  // driven by UDP parser
    .din     (out_fifo_din_int),     // driven by UDP parser
    .full    (out_fifo_full),        // visible to testbench
    .rd_clk  (clk),
    .rd_en   (out_fifo_rd_en),       // driven by testbench
    .dout    (out_fifo_dout),        // visible to testbench
    .empty   (out_fifo_empty)        // visible to testbench
  );
  
  //-------------------------------------------------------------------------
  // Instantiate the UDP Parser.
  // The UDP parser reads data from the input FIFO and writes UDP payload data
  // to the output FIFO.
  //-------------------------------------------------------------------------
  udp_parser udp_parser_inst (
    .clk      (clk),
    .reset    (reset),
    .in_data  (in_fifo_dout_int),
    .in_empty (in_fifo_empty_int),
    .in_rd_en (in_fifo_rd_en_int),
    .out_data (out_fifo_din_int),
    .out_wr_en(out_fifo_wr_en_int),
    .out_full (out_fifo_full)
  );
  
endmodule