module cordic # (
  parameter FIFO_DATA_WIDTH = 16,
  parameter FIFO_BUFFER_SIZE = 1024,
  parameter NUM_STAGES = 16
)( 
  input logic clock,
  input logic reset, 

  // fifo read
  output logic rd_en,
  input logic [FIFO_DATA_WIDTH-1 : 0] data_in,
  input logic empty,

  // cos fifo write
  output logic cos_wr_en,
  input logic cos_full,
  output logic [FIFO_DATA_WIDTH-1 : 0] cos_data_out,

  // sin fifo write
  output logic sin_wr_en,
  input logic sin_full,
  output logic [FIFO_DATA_WIDTH-1 : 0] sin_data_out
);

logic signed [FIFO_DATA_WIDTH-1:0] x [0:NUM_STAGES];
logic signed [FIFO_DATA_WIDTH-1:0] y [0:NUM_STAGES];
logic signed [FIFO_DATA_WIDTH-1:0] z [0:NUM_STAGES];

logic [3:0] counter;

typedef enum logic [2:0] {IDLE, READ, PROC, WAIT, DONE} state_t;
state_t curr_state, next_state;

// next_state and output logic
always_comb begin
  // default signals
  next_state = curr_state;
  rd_en = 1'b0;
  cos_wr_en = 1'b0;
  sin_wr_en = 1'b0;
  cos_data_out = 16'b0;
  sin_data_out = 16'b0;

  case (curr_state)

    IDLE: begin
      if (!empty)
        next_state = READ;
    end

    READ: begin
      rd_en = 1'b1;
      next_state = PROC;
    end

    PROC: begin
      rd_en = 1'b0;
      if (counter == 4'hF) begin
        if (!sin_full && !cos_full)
          next_state = DONE;
        else
          next_state = WAIT;
      end
    end

    WAIT: begin
      if (!sin_full && !cos_full)
        next_state = DONE;
      else
        next_state = WAIT;
    end

    DONE: begin
      cos_wr_en = 1'b1;
      sin_wr_en = 1'b1;
      cos_data_out = x[NUM_STAGES];
      sin_data_out = y[NUM_STAGES];
      next_state = IDLE;
    end

  endcase

end

always_ff @(posedge clock) begin
  if (reset) begin
    x[0] <= 16'b0;
    y[0] <= 16'b0;
    z[0] <= 16'b0;
    curr_state <= IDLE;
  end else begin

    case (curr_state)

      IDLE: begin
        x[0] <= 16'h9B75;
        y[0] <= 16'h0000;
        z[0] <= 16'h0000;
        counter <= 4'b0;
      end

      READ: begin
      end

      PROC: begin
        z[0] <= data_in;
        counter <= counter + 1;
      end

      WAIT: begin
      end

      DONE: begin
      end

    endcase

    curr_state <= next_state;

  end
end

genvar i;
generate for (i = 0; i < NUM_STAGES; i++) begin
  cordic_stage #(
    .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
    .STAGE(i)
  ) cordic_stage_inst(
    .clock(clock),
    .reset(reset),
    .x_input(x[i]),
    .y_input(y[i]),
    .z_input(z[i]),
    .x_output(x[i+1]),
    .y_output(y[i+1]),
    .z_output(z[i+1])
  );
end endgenerate

endmodule