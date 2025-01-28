module background_subtract #(
    parameter int THRESHOLD = 50
)(
    input  logic         clk,
    input  logic         reset,

    // FIFO In (base image pixels)
    output logic         base_read_enable,
    input  logic [7:0]   base_din,
    input  logic         base_fifo_empty,

    // FIFO In (gray/current image pixels)
    output logic         gray_read_enable,
    input  logic [7:0]   gray_din,
    input  logic         gray_fifo_empty,

    // FIFO Out (foreground mask)
    output logic         write_enable,
    output logic [7:0]   data_out,
    input  logic         fifo_out_full
);

  typedef enum logic [1:0] {IDLE, READ, PROCESS, WRITE} state_t;
  state_t current_state, next_state;

  logic [7:0] base_pix, gray_pix, diff_pix, result_pix;

  // Sequential logic
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      current_state <= IDLE;
      base_pix      <= 8'd0;
      gray_pix      <= 8'd0;
      diff_pix      <= 8'd0;
      result_pix    <= 8'd0;
    end
    else begin
      current_state <= next_state;

      case (current_state)
        READ: begin
          if (!base_fifo_empty && !gray_fifo_empty) begin
            base_pix <= base_din;
            gray_pix <= gray_din;
          end
        end
        PROCESS: begin
          diff_pix   <= (base_pix >= gray_pix) ? (base_pix - gray_pix) : (gray_pix - base_pix);
          result_pix <= (diff_pix > THRESHOLD) ? 8'hFF : 8'h00;
        end
      endcase
    end
  end

  // Combinational next-state / output logic
  always_comb begin
    base_read_enable = 1'b0;
    gray_read_enable = 1'b0;
    write_enable     = 1'b0;
    data_out         = 8'd0;
    next_state       = current_state;

    case (current_state)
      IDLE: begin
        if (!base_fifo_empty && !gray_fifo_empty)
          next_state = READ;
      end

      READ: begin
        if (!base_fifo_empty && !gray_fifo_empty) begin
          base_read_enable = 1'b1;
          gray_read_enable = 1'b1;
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
          data_out     = result_pix;
          write_enable = 1'b1;
          next_state   = IDLE;
        end
        // If output FIFO is full, stay here until it’s not full
      end
    endcase
  end

endmodule