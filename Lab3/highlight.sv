module highlight (
    input  logic         clk,
    input  logic         reset,

    // FIFO In for base image (32 bits)
    output logic         base_read_enable,
    input  logic [31:0]  base_din,
    input  logic         base_fifo_empty,

    // FIFO In for mask (8 bits)
    output logic         subt_read_enable,
    input  logic [7:0]   subt_din,
    input  logic         subt_fifo_empty,

    // FIFO Out (highlighted pixels, 32 bits)
    output logic         write_enable,
    output logic [31:0]  data_out,
    input  logic         fifo_out_full
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE,
    READ,
    PROCESS,
    WRITE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  logic [31:0] base_pixel;
  logic [7:0]  subt_mask;
  logic [31:0] out_pixel;

  // Sequential: state and data latching
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      current_state <= IDLE;
      base_pixel    <= 32'd0;
      subt_mask     <= 8'd0;
      out_pixel     <= 32'd0;
    end
    else begin
      current_state <= next_state;
      case (current_state)
        READ: begin
          if (!base_fifo_empty && !subt_fifo_empty) begin
            base_pixel <= base_din;
            subt_mask  <= subt_din;
          end
        end
        PROCESS: begin
          // Extract B, G, R for clarity
          logic [7:0] b = base_pixel[31:24];
          logic [7:0] g = base_pixel[23:16];
          logic [7:0] r = base_pixel[15:8];

          if (subt_mask == 8'hFF) begin
            // Highlight in red
            out_pixel <= {8'h00, 8'h00, 8'hFF, base_pixel[7:0]};
          end
          else begin
            // Keep the original base pixel
            out_pixel <= base_pixel;
          end
        end
      endcase
    end
  end

  // Combinational: next_state & output signals
  always_comb begin
    base_read_enable = 1'b0;
    subt_read_enable = 1'b0;
    write_enable     = 1'b0;
    data_out         = 32'd0;
    next_state       = current_state;

    case (current_state)
      IDLE: begin
        if (!base_fifo_empty && !subt_fifo_empty)
          next_state = READ;
      end

      READ: begin
        if (!base_fifo_empty && !subt_fifo_empty) begin
          base_read_enable = 1'b1;
          subt_read_enable = 1'b1;
          next_state       = PROCESS;
        end
        else
          next_state = IDLE;
      end

      PROCESS: begin
        next_state = WRITE;
      end

      WRITE: begin
        if (!fifo_out_full) begin
          data_out     = out_pixel;
          write_enable = 1'b1;
          next_state   = IDLE;
        end
        // If fifo_out is full, stay in WRITE until it's not full
      end

    endcase
  end

endmodule