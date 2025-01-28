module grayscale (
  input  logic         clk,
  input  logic         reset,

  // FIFO In (input pixels)
  output logic         read_enable,
  input  logic [31:0]  data_in,
  input  logic         fifo_in_empty,

  // FIFO Out (grayscale pixels)
  output logic         write_enable,
  output logic [7:0]   data_out,
  input  logic         fifo_out_full
);

  // Internal state definitions
  typedef enum logic [1:0] {
    IDLE,
    READ,
    PROCESS,
    WRITE
  } state_t;

  state_t current_state, next_state;

  // Internal registers for color channels and grayscale
  logic [7:0] red, green, blue, grayscale;

  // Sequential (clocked) logic
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      current_state <= IDLE;
      // Optional: reset color registers here if needed
      red       <= 8'b0;
      green     <= 8'b0;
      blue      <= 8'b0;
      grayscale <= 8'b0;
    end
    else begin
      current_state <= next_state;

      case (current_state)
        READ: begin
          // Latch B, G, R on next rising edge, if FIFO is not empty
          if (!fifo_in_empty) begin
            // BMP / BGR format: data_in[31:24] = B, [23:16] = G, [15:8] = R
            blue  <= data_in[31:24];
            green <= data_in[23:16];
            red   <= data_in[15:8];
          end
        end

        PROCESS: begin
          // Simple average formula for grayscale
          grayscale <= (red + green + blue) / 3;
        end

        default: ; // IDLE, WRITE do nothing special here
      endcase
    end
  end

  // Combinational next-state and output logic
  always_comb begin
    // Default outputs
    read_enable  = 1'b0;
    write_enable = 1'b0;
    data_out     = 8'b0;
    next_state   = current_state;

    case (current_state)

      // Wait for FIFO In to have valid data
      IDLE: begin
        if (!fifo_in_empty) begin
          next_state = READ;
        end
      end

      // Read (pop) from the FIFO
      READ: begin
        if (!fifo_in_empty) begin
          // Drive read_enable high to pop the next 32-bit word from FIFO
          read_enable = 1'b1;
          next_state  = PROCESS;
        end
        else begin
          // If FIFO suddenly becomes empty, go back to IDLE
          next_state = IDLE;
        end
      end

      // Compute grayscale
      PROCESS: begin
        // Next cycle, grayscale is ready
        next_state = WRITE;
      end

      // Write (push) the grayscale to the output FIFO
      WRITE: begin
        // Only write if FIFO out is not full
        if (!fifo_out_full) begin
          data_out     = grayscale;
          write_enable = 1'b1;
          next_state   = IDLE;
        end
        // If fifo_out is full, remain in WRITE until it becomes not full
      end

    endcase
  end

endmodule