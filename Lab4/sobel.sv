module sobel #(
  parameter IMG_WIDTH  = 720,
  parameter IMG_HEIGHT = 540
) (
  input  logic         clock,
  input  logic         reset,
  // FIFO IN interface
  output logic         in_rd_en,    // assert to read from input FIFO
  input  logic         in_empty,    // high when input FIFO is empty
  input  logic [7:0]   in_dout,     // pixel from input FIFO
  // FIFO OUT interface
  output logic         out_wr_en,   // assert to write to output FIFO
  input  logic         out_full,    // high when output FIFO is full
  output logic [7:0]   out_din      // pixel to output FIFO
);

  //--------------------------------------------------------------------------
  // State machine states.
  // States:
  //  - READ_BOT:   Read the first (bottom border) row into bot_row.
  //  - READ_MID:   Read the second row into mid_row.
  //  - OUTPUT_BOT: Output bottom border row (all zeros).
  //  - READ_TOP:   Read next row into top_row.
  //  - PROCESS_ROW: Process mid_row using the 3x3 window:
  //                 top_row (displayed above), mid_row, bot_row (displayed below).
  //  - SHIFT:      Shift buffers: bot_row <= mid_row, mid_row <= top_row.
  //  - OUTPUT_TOP: Output top border row (all zeros).
  //  - DONE:       Finished processing.
  //--------------------------------------------------------------------------
  typedef enum logic [3:0] {
    IDLE,
    READ_BOT,    // Read first (bottom) row from FIFO
    READ_MID,    // Read second row from FIFO
    OUTPUT_BOT,  // Output bottom border row as 0
    READ_TOP,    // Read next row into top_row
    PROCESS_ROW, // Process mid_row (interior) using 3x3 window
    SHIFT,       // Shift buffers: bot_row <= mid_row; mid_row <= top_row
    OUTPUT_TOP,  // Output top border row as 0
    DONE         // Finished processing
  } state_t;
  
  state_t curr_state, next_state;

  //--------------------------------------------------------------------------
  // Counters and indices.
  // col_counter: counts pixel positions during FIFO read.
  // proc_index:  counts pixel positions during row output.
  // row_count:   number of rows read from the FIFO.
  //--------------------------------------------------------------------------
  localparam COL_WIDTH = $clog2(IMG_WIDTH);
  localparam ROW_WIDTH = $clog2(IMG_HEIGHT+1);
  
  logic [COL_WIDTH-1:0] col_counter;
  logic [COL_WIDTH-1:0] proc_index;
  logic [ROW_WIDTH-1:0] row_count;
  
  //--------------------------------------------------------------------------
  // Line buffers.
  // bot_row: holds the first row read (display bottom border).
  // mid_row: holds the next row.
  // top_row: holds the newly read row.
  //--------------------------------------------------------------------------
  logic [7:0] bot_row [0:IMG_WIDTH-1];
  logic [7:0] mid_row [0:IMG_WIDTH-1];
  logic [7:0] top_row [0:IMG_WIDTH-1];

  //--------------------------------------------------------------------------
  // sobel_pixel:
  // Computes the Sobel filter output for a 3x3 window.
  // Window pixels (each 8-bit) are arranged as:
  //   p_top_left   p_top   p_top_right
  //   p_mid_left   p_mid   p_mid_right
  //   p_bot_left   p_bot   p_bot_right
  // Returns: (|Gx| + |Gy|) >> 1, clamped to 255.
  // Note: Since BMP images are read bottom-to-top, our buffers hold:
  //   top_row = display row above mid_row,
  //   mid_row = the row to process,
  //   bot_row = display row below mid_row.
  //--------------------------------------------------------------------------
  function automatic [7:0] sobel_pixel(
    input logic [7:0] p_top_left,   input logic [7:0] p_top,   input logic [7:0] p_top_right,
    input logic [7:0] p_mid_left,   input logic [7:0] p_mid,   input logic [7:0] p_mid_right,
    input logic [7:0] p_bot_left,   input logic [7:0] p_bot,   input logic [7:0] p_bot_right
  );
    logic signed [10:0] gx;
    logic signed [10:0] gy;
    logic [7:0] result;
  begin
    // Horizontal gradient: -p_top_left + p_top_right - 2*p_mid_left + 2*p_mid_right - p_bot_left + p_bot_right
    gx = -$signed({2'b0, p_top_left}) + $signed({2'b0, p_top_right})
         - 2*$signed({2'b0, p_mid_left}) + 2*$signed({2'b0, p_mid_right})
         - $signed({2'b0, p_bot_left}) + $signed({2'b0, p_bot_right});
    // Vertical gradient: -p_top_left - 2*p_top - p_top_right + p_bot_left + 2*p_bot + p_bot_right
    gy = -$signed({2'b0, p_top_left}) - 2*$signed({2'b0, p_top}) - $signed({2'b0, p_top_right})
         + $signed({2'b0, p_bot_left}) + 2*$signed({2'b0, p_bot}) + $signed({2'b0, p_bot_right});
    result = ((gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy)) >> 1;
    if(result > 8'd255)
      result = 8'd255;
    sobel_pixel = result;
  end
  endfunction

  //--------------------------------------------------------------------------
  // NEXT-STATE AND OUTPUT (combinational process)
  //--------------------------------------------------------------------------
  always_comb begin
    // Default assignments
    next_state = curr_state;
    in_rd_en   = 1'b0;
    out_wr_en  = 1'b0;
    out_din    = 8'd0;
    
    case (curr_state)
      IDLE: begin
        next_state = READ_BOT;
      end
      
      // Read the first (bottom border) row from FIFO.
      READ_BOT: begin
        if (!in_empty) begin
          in_rd_en = 1'b1;
          if (col_counter == IMG_WIDTH-1)
            next_state = READ_MID;
          else
            next_state = READ_BOT;
        end
      end
      
      // Read the second row into mid_row.
      READ_MID: begin
        if (!in_empty) begin
          in_rd_en = 1'b1;
          if (col_counter == IMG_WIDTH-1)
            next_state = OUTPUT_BOT;  // bottom border row will be output as 0
          else
            next_state = READ_MID;
        end
      end
      
      // Output the bottom border row (all zeros).
      OUTPUT_BOT: begin
        if (!out_full) begin
          out_wr_en = 1'b1;
          out_din   = 8'd0;
          if (proc_index == IMG_WIDTH-1)
            next_state = READ_TOP;
          else
            next_state = OUTPUT_BOT;
        end
      end
      
      // Read the next row from FIFO into top_row.
      READ_TOP: begin
        if (!in_empty) begin
          in_rd_en = 1'b1;
          if (col_counter == IMG_WIDTH-1)
            next_state = PROCESS_ROW; // once top_row is complete, process mid_row
          else
            next_state = READ_TOP;
        end
      end
      
      // Process mid_row using the 3x3 window.
      PROCESS_ROW: begin
        if (!out_full) begin
          out_wr_en = 1'b1;
          // For left/right border pixels, force output to 0.
          if ((proc_index == 0) || (proc_index == IMG_WIDTH-1))
            out_din = 8'd0;
          else begin
            // Note: In our buffers the display order is:
            // top_row (above mid_row), mid_row, bot_row (below mid_row).
            out_din = sobel_pixel( 
                        top_row[proc_index-1],   top_row[proc_index],   top_row[proc_index+1],
                        mid_row[proc_index-1],   mid_row[proc_index],   mid_row[proc_index+1],
                        bot_row[proc_index-1],   bot_row[proc_index],   bot_row[proc_index+1]
                      );
          end
          if (proc_index == IMG_WIDTH-1)
            next_state = SHIFT;
          else
            next_state = PROCESS_ROW;
        end
      end
      
      // Shift buffers: bot_row <= mid_row; mid_row <= top_row.
      // Then, if more rows remain, go back to READ_TOP; otherwise, output top border.
      SHIFT: begin
        if (row_count < IMG_HEIGHT)
          next_state = READ_TOP;
        else
          next_state = OUTPUT_TOP;
      end
      
      // Output the top border row (all zeros).
      OUTPUT_TOP: begin
        if (!out_full) begin
          out_wr_en = 1'b1;
          out_din   = 8'd0;
          if (proc_index == IMG_WIDTH-1)
            next_state = DONE;
          else
            next_state = OUTPUT_TOP;
        end
      end
      
      DONE: begin
        next_state = DONE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  //--------------------------------------------------------------------------
  // STATE, COUNTER, AND BUFFER UPDATE (sequential process)
  //--------------------------------------------------------------------------
  integer i;
  always_ff @(posedge clock) begin
    if (reset) begin
      curr_state  <= IDLE;
      col_counter <= 0;
      proc_index  <= 0;
      row_count   <= 0;
      // Clear buffers
      for (i = 0; i < IMG_WIDTH; i = i + 1) begin
        bot_row[i] <= 8'd0;
        mid_row[i] <= 8'd0;
        top_row[i] <= 8'd0;
      end
    end else begin
      curr_state <= next_state;
      
      case (curr_state)
        IDLE: begin
          col_counter <= 0;
          proc_index  <= 0;
          row_count   <= 0;
        end
        
        // READ_BOT: store first row (bottom border) into bot_row.
        READ_BOT: begin
          if (!in_empty && in_rd_en) begin
            bot_row[col_counter] <= in_dout;
            if (col_counter == IMG_WIDTH-1) begin
              col_counter <= 0;
              row_count   <= row_count + 1;  // row_count becomes 1
            end else begin
              col_counter <= col_counter + 1;
            end
          end
        end
        
        // READ_MID: store second row into mid_row.
        READ_MID: begin
          if (!in_empty && in_rd_en) begin
            mid_row[col_counter] <= in_dout;
            if (col_counter == IMG_WIDTH-1) begin
              col_counter <= 0;
              row_count   <= row_count + 1;  // row_count becomes 2
            end else begin
              col_counter <= col_counter + 1;
            end
          end
        end
        
        // OUTPUT_BOT: output bottom border (0) pixel-by-pixel.
        OUTPUT_BOT: begin
          if (!out_full && out_wr_en) begin
            if (proc_index == IMG_WIDTH-1)
              proc_index <= 0;
            else
              proc_index <= proc_index + 1;
          end
        end
        
        // READ_TOP: store new row into top_row.
        READ_TOP: begin
          if (!in_empty && in_rd_en) begin
            top_row[col_counter] <= in_dout;
            if (col_counter == IMG_WIDTH-1) begin
              col_counter <= 0;
              row_count   <= row_count + 1;
            end else begin
              col_counter <= col_counter + 1;
            end
          end
        end
        
        // PROCESS_ROW: output computed pixel for mid_row.
        PROCESS_ROW: begin
          if (!out_full && out_wr_en) begin
            if (proc_index == IMG_WIDTH-1)
              proc_index <= 0;
            else
              proc_index <= proc_index + 1;
          end
        end
        
        // SHIFT: shift buffers for next window.
        SHIFT: begin
          for (i = 0; i < IMG_WIDTH; i = i + 1) begin
            bot_row[i] <= mid_row[i];
            mid_row[i] <= top_row[i];
          end
          proc_index <= 0;
        end
        
        // OUTPUT_TOP: output top border (0) pixel-by-pixel.
        OUTPUT_TOP: begin
          if (!out_full && out_wr_en) begin
            if (proc_index == IMG_WIDTH-1)
              proc_index <= 0;
            else
              proc_index <= proc_index + 1;
          end
        end
        
        DONE: begin
          // Remain in DONE state.
        end
        
        default: ;
      endcase
    end
  end

endmodule