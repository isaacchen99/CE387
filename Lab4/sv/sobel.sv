module sobel #(
  parameter IMG_WIDTH  = 720,
  parameter IMG_HEIGHT = 540
) (
  input  logic         clock,
  input  logic         reset,
  output logic         in_rd_en,
  input  logic         in_empty,    
  input  logic [7:0]   in_dout,     
  output logic         out_wr_en,  
  input  logic         out_full,   
  output logic [7:0]   out_din      
);

  typedef enum logic [3:0] {
    IDLE,
    READ_BOT,  
    READ_MID,    
    OUTPUT_BOT,  
    READ_TOP,    
    PROCESS_ROW, 
    SHIFT,       
    OUTPUT_TOP,  
    DONE         
  } state_t;
  
  state_t curr_state, next_state;

  localparam COL_WIDTH = $clog2(IMG_WIDTH);
  localparam ROW_WIDTH = $clog2(IMG_HEIGHT+1);
  
  logic [COL_WIDTH-1:0] col_counter;
  logic [COL_WIDTH-1:0] proc_index;
  logic [ROW_WIDTH-1:0] row_count;

  logic [7:0] bot_row [0:IMG_WIDTH-1];
  logic [7:0] mid_row [0:IMG_WIDTH-1];
  logic [7:0] top_row [0:IMG_WIDTH-1];

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

  always_comb begin
    next_state = curr_state;
    in_rd_en   = 1'b0;
    out_wr_en  = 1'b0;
    out_din    = 8'd0;
    
    case (curr_state)
      IDLE: begin
        next_state = READ_BOT;
      end
      
      READ_BOT: begin
        if (!in_empty) begin
          in_rd_en = 1'b1;
          if (col_counter == IMG_WIDTH-1)
            next_state = READ_MID;
          else
            next_state = READ_BOT;
        end
      end
      
      READ_MID: begin
        if (!in_empty) begin
          in_rd_en = 1'b1;
          if (col_counter == IMG_WIDTH-1)
            next_state = OUTPUT_BOT;
          else
            next_state = READ_MID;
        end
      end
      
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
      
      READ_TOP: begin
        if (!in_empty) begin
          in_rd_en = 1'b1;
          if (col_counter == IMG_WIDTH-1)
            next_state = PROCESS_ROW;
          else
            next_state = READ_TOP;
        end
      end
      
      PROCESS_ROW: begin
        if (!out_full) begin
          out_wr_en = 1'b1;
          if ((proc_index == 0) || (proc_index == IMG_WIDTH-1))
            out_din = 8'd0;
          else begin
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

      SHIFT: begin
        if (row_count < IMG_HEIGHT)
          next_state = READ_TOP;
        else
          next_state = OUTPUT_TOP;
      end
      
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
  
  integer i;
  always_ff @(posedge clock) begin
    if (reset) begin
      curr_state  <= IDLE;
      col_counter <= 0;
      proc_index  <= 0;
      row_count   <= 0;
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
        
        READ_BOT: begin
          if (!in_empty && in_rd_en) begin
            bot_row[col_counter] <= in_dout;
            if (col_counter == IMG_WIDTH-1) begin
              col_counter <= 0;
              row_count   <= row_count + 1;
            end else begin
              col_counter <= col_counter + 1;
            end
          end
        end
        
        READ_MID: begin
          if (!in_empty && in_rd_en) begin
            mid_row[col_counter] <= in_dout;
            if (col_counter == IMG_WIDTH-1) begin
              col_counter <= 0;
              row_count   <= row_count + 1;
            end else begin
              col_counter <= col_counter + 1;
            end
          end
        end
        
        OUTPUT_BOT: begin
          if (!out_full && out_wr_en) begin
            if (proc_index == IMG_WIDTH-1)
              proc_index <= 0;
            else
              proc_index <= proc_index + 1;
          end
        end
        
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
        
        PROCESS_ROW: begin
          if (!out_full && out_wr_en) begin
            if (proc_index == IMG_WIDTH-1)
              proc_index <= 0;
            else
              proc_index <= proc_index + 1;
          end
        end
        
        SHIFT: begin
          for (i = 0; i < IMG_WIDTH; i = i + 1) begin
            bot_row[i] <= mid_row[i];
            mid_row[i] <= top_row[i];
          end
          proc_index <= 0;
        end
        
        OUTPUT_TOP: begin
          if (!out_full && out_wr_en) begin
            if (proc_index == IMG_WIDTH-1)
              proc_index <= 0;
            else
              proc_index <= proc_index + 1;
          end
        end
        
        DONE: begin
        end
        
        default: ;
      endcase
    end
  end

endmodule