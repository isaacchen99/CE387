module cordic # (
  parameter FIFO_DATA_WIDTH = 16,
  parameter FIFO_BUFFER_SIZE = 16,
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

logic signed [FIFO_DATA_WIDTH-1:0] x_pipe [0:NUM_STAGES];
logic signed [FIFO_DATA_WIDTH-1:0] y_pipe [0:NUM_STAGES];
logic signed [FIFO_DATA_WIDTH-1:0] z_pipe [0:NUM_STAGES];

logic [4:0] counter;
logic [FIFO_DATA_WIDTH-1:0] z_input;

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
      if (counter == 5'd16) begin
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
      cos_data_out = x_pipe[NUM_STAGES];
      sin_data_out = y_pipe[NUM_STAGES];
      next_state = IDLE;
    end

  endcase

end

always_ff @(posedge clock) begin
  if (reset) begin
    x_pipe[0] <= 16'h26F6;
    y_pipe[0] <= 16'b0;
    z_pipe[0] <= 16'b0;
    curr_state <= IDLE;
  end else begin

    case (curr_state)

      IDLE: begin
        x_pipe[0] <= 16'h26F6;
        y_pipe[0] <= 16'h0000;
        z_pipe[0] <= 16'h0000;
        counter <= 4'b0;
      end

      READ: begin
      end

      PROC: begin
        z_pipe[0] <= data_in;
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

// Generate NUM_STAGES instances of the cordic_stage.
genvar i;
generate
  for (i = 0; i < NUM_STAGES; i++) begin : cordic_stage_gen
    cordic_stage #(
      .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
      .STAGE(i)
    ) cordic_stage_inst (
      .clock    (clock),
      .reset    (reset),
      .x_input  (x_pipe[i]),
      .y_input  (y_pipe[i]),
      .z_input  (z_pipe[i]),
      .x_output (x_pipe[i+1]),
      .y_output (y_pipe[i+1]),
      .z_output (z_pipe[i+1])
    );
  end
endgenerate

endmodule