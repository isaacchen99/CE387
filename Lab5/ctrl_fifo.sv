module ctrl_fifo (
  input  logic         clk,
  input  logic         reset,
  // Write interface (from source, e.g. testbench or UDP parser)
  input  logic [7:0]   wdata,
  input  logic         w_valid,
  input  logic         w_sof,
  input  logic         w_eof,
  output logic         w_ready,
  // Read interface (to destination, e.g. UDP parser or further processing)
  output logic [7:0]   rdata,
  output logic         r_valid,
  output logic         r_sof,
  output logic         r_eof,
  input  logic         r_ready
);

  // Internal signals for the two FIFOs.
  logic data_full, data_empty;
  logic ctrl_full, ctrl_empty;
  logic [7:0] data_rdata;
  logic [1:0] ctrl_rdata;

  // Write enable is common to both FIFOs.
  // Accept input only when neither FIFO is full.
  assign w_ready = !(data_full || ctrl_full);

  // Read valid is asserted when both FIFOs are not empty.
  assign r_valid = !(data_empty || ctrl_empty);

  //-------------------------------------------------------------------------
  // Data FIFO instance: 8-bit wide.
  //-------------------------------------------------------------------------
  fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(1024)
  ) data_fifo (
    .reset   (reset),
    .wr_clk  (clk),
    .wr_en   (w_valid && w_ready),
    .din     (wdata),
    .full    (data_full),
    .rd_clk  (clk),
    .rd_en   (r_ready && r_valid),
    .dout    (data_rdata),
    .empty   (data_empty)
  );

  //-------------------------------------------------------------------------
  // Control FIFO instance: 2-bit wide (packed as {SOF, EOF}).
  //-------------------------------------------------------------------------
  fifo #(
    .FIFO_DATA_WIDTH(2),
    .FIFO_BUFFER_SIZE(1024)
  ) ctrl_fifo_inst (
    .reset   (reset),
    .wr_clk  (clk),
    .wr_en   (w_valid && w_ready),
    .din     ({w_sof, w_eof}),
    .full    (ctrl_full),
    .rd_clk  (clk),
    .rd_en   (r_ready && r_valid),
    .dout    (ctrl_rdata),
    .empty   (ctrl_empty)
  );

  // Connect outputs.
  assign rdata = data_rdata;
  assign {r_sof, r_eof} = ctrl_rdata;

endmodule