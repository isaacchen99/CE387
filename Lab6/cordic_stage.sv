module cordic_stage #(
  parameter FIFO_DATA_WIDTH = 16,
  parameter FIFO_BUFFER_SIZE = 1024,
  parameter STAGE = 0
) (
  input  logic clock,
  input  logic reset,

  input  logic signed [FIFO_DATA_WIDTH-1:0] x_input,
  input  logic signed [FIFO_DATA_WIDTH-1:0] y_input,
  input  logic signed [FIFO_DATA_WIDTH-1:0] z_input,

  output logic signed [FIFO_DATA_WIDTH-1:0] x_output,
  output logic signed [FIFO_DATA_WIDTH-1:0] y_output,
  output logic signed [FIFO_DATA_WIDTH-1:0] z_output
);

localparam logic [15:0] CORDIC_TABLE [0:15] = '{
  16'h3243, 16'h1DAC, 16'h0FAD, 16'h07F5,
  16'h03FE, 16'h01FF, 16'h00FF, 16'h007F,
  16'h003F, 16'h001F, 16'h000F, 16'h0007,
  16'h0003, 16'h0001, 16'h0000, 16'h0000
};

logic signed [FIFO_DATA_WIDTH-1:0] theta;
logic signed [FIFO_DATA_WIDTH-1:0] d;

assign theta = CORDIC_TABLE[STAGE];
assign d = (z_input[FIFO_DATA_WIDTH-1] == 1) ? {FIFO_DATA_WIDTH{1'b1}} : {FIFO_DATA_WIDTH{1'b0}};

always_ff @(posedge clock) begin
  if (reset) begin
    x_output <= {FIFO_DATA_WIDTH{1'b0}};
    y_output <= {FIFO_DATA_WIDTH{1'b0}};
    z_output <= {FIFO_DATA_WIDTH{1'b0}};
  end else begin
    x_output <= x_input - (((y_input >>> STAGE) ^ d) - d);
    y_output <= y_input + (((x_input >>> STAGE) ^ d) - d);
    z_output <= z_input - ((theta ^ d) - d);
  end
end

endmodule