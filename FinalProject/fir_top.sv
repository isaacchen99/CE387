module fir_top #(
  parameter DECIMATION       = 1,
  parameter FIFO_DATA_WIDTH  = 32,
  parameter NUM_TAPS         = 32,
  parameter logic signed [31:0] COEFFS [NUM_TAPS] = '{default:32'd0}
) (
  input  logic clk,
  input  logic rst,

  input  logic [FIFO_DATA_WIDTH-1:0] in_data,
  input  logic                       in_wr_en,      // Write enable to input FIFO
  output logic                       in_fifo_full,  // '1' => input FIFO is full

  output logic [FIFO_DATA_WIDTH-1:0] out_data,
  input  logic                       out_rd_en,     // Read enable from output FIFO
  output logic                       out_fifo_empty // '1' => output FIFO is empty
);

  // ------------------------------------------------------
  // Signals to connect FIFO <-> FIR <-> FIFO
  // ------------------------------------------------------
  // Input FIFO -> FIR
  logic [FIFO_DATA_WIDTH-1:0] fifo_in2fir_data;
  logic                       fifo_in2fir_empty;
  logic                       fifo_in2fir_rd_en;

  // FIR -> Output FIFO
  logic [FIFO_DATA_WIDTH-1:0] fir2fifo_out_data;
  logic                       fifo_out2fir_full;
  logic                       fifo_out2fir_wr_en;

  // ------------------------------------------------------
  // INPUT FIFO instantiation
  // ------------------------------------------------------
  fifo #(
    .FIFO_DATA_WIDTH   (FIFO_DATA_WIDTH),
    .FIFO_BUFFER_SIZE  (1024)
  ) input_fifo (
    .reset   (rst),

    // Write side (same clk domain)
    .wr_clk  (clk),
    .wr_en   (in_wr_en),
    .din     (in_data),
    .full    (in_fifo_full),

    // Read side (same clk domain)
    .rd_clk  (clk),
    .rd_en   (fifo_in2fir_rd_en),
    .dout    (fifo_in2fir_data),
    .empty   (fifo_in2fir_empty)
  );

  // ------------------------------------------------------
  // FIR Filter instantiation
  // ------------------------------------------------------
  fir #(
    .DECIMATION        (DECIMATION),
    .FIFO_DATA_WIDTH   (FIFO_DATA_WIDTH),
    .NUM_TAPS          (NUM_TAPS),
    .COEFFS            (COEFFS)
  ) fir_inst (
    .clk                 (clk),
    .rst                 (rst),

    // Connect to input FIFO
    .rd_fifo_empty       (fifo_in2fir_empty),
    .rd_fifo_rd_en       (fifo_in2fir_rd_en),
    .rd_fifo_data_in     (fifo_in2fir_data),

    // Connect to output FIFO
    .wr_fifo_full        (fifo_out2fir_full),
    .wr_fifo_wr_en       (fifo_out2fir_wr_en),
    .wr_fifo_data_out    (fir2fifo_out_data)
  );

  // ------------------------------------------------------
  // OUTPUT FIFO instantiation
  // ------------------------------------------------------
  fifo #(
    .FIFO_DATA_WIDTH   (FIFO_DATA_WIDTH),
    .FIFO_BUFFER_SIZE  (1024)
  ) output_fifo (
    .reset   (rst),

    // Write side
    .wr_clk  (clk),
    .wr_en   (fifo_out2fir_wr_en),
    .din     (fir2fifo_out_data),
    .full    (fifo_out2fir_full),

    // Read side
    .rd_clk  (clk),
    .rd_en   (out_rd_en),
    .dout    (out_data),
    .empty   (out_fifo_empty)
  );

endmodule