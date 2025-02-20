module udp_parser (
    input  logic        clk,
    input  logic        reset,
    // Input FIFO interface (one byte at a time)
    input  logic [7:0]  in_data,
    input  logic        in_empty,
    output logic        in_rd_en,
    // Output FIFO interface (one byte at a time)
    output logic [7:0]  out_data,
    output logic        out_wr_en,
    input  logic        out_full
);

  // FSM state definitions
  typedef enum logic [1:0] {
    IDLE,    // waiting for new packet data
    HEADER,  // reading header bytes 0 to 41 (capture length at bytes 38-39)
    PAYLOAD, // transferring payload bytes into the output FIFO
    DONE     // packet complete; return to IDLE
  } state_t;
  
  state_t state, next_state;
  
  // Counters and registers:
  // header_cnt counts the header bytes (0–41)
  // payload_cnt counts the number of payload bytes transferred
  logic [7:0]  header_cnt;
  logic [15:0] payload_cnt;
  // The packet length is captured from header bytes 38 and 39.
  logic [15:0] packet_length;
  
  //----------------------------------------------------------------------------
  // Sequential process: update state and counters
  //----------------------------------------------------------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state         <= IDLE;
      header_cnt    <= 8'd0;
      payload_cnt   <= 16'd0;
      packet_length <= 16'd0;
    end
    else begin
      state <= next_state;
      
      // When a read is performed (and the FIFO isn’t empty) update counters:
      if (in_rd_en && !in_empty) begin
        case (state)
          HEADER: begin
            header_cnt <= header_cnt + 1;
            // Capture packet length from header bytes 38 and 39.
            if (header_cnt == 8'd38)
              packet_length[15:8] <= in_data; // high byte
            else if (header_cnt == 8'd39)
              packet_length[7:0] <= in_data;  // low byte
          end
          PAYLOAD: begin
            payload_cnt <= payload_cnt + 1;
          end
          default: ; // do nothing in other states
        endcase
      end
      
      // Once the packet is done, reset counters for the next packet.
      if (state == DONE) begin
        header_cnt    <= 8'd0;
        payload_cnt   <= 16'd0;
        packet_length <= 16'd0;
      end
    end
  end
  
  //----------------------------------------------------------------------------
  // Combinational process: determine next state and control signals
  //----------------------------------------------------------------------------
  always_comb begin
    // Default assignments
    next_state = state;
    in_rd_en   = 1'b0;
    out_wr_en  = 1'b0;
    out_data   = 8'd0;
    
    case (state)
      IDLE: begin
        // Wait until the input FIFO has data.
        if (!in_empty) begin
          next_state = HEADER;
          in_rd_en   = 1'b1; // start reading header bytes
        end
      end
      
      HEADER: begin
        // Read header bytes continuously (even though we ignore most).
        if (!in_empty) begin
          in_rd_en = 1'b1;
          // After reading byte index 41 (i.e. 42 header bytes in total),
          // move to the PAYLOAD state.
          if (header_cnt == 8'd41)
            next_state = PAYLOAD;
        end
      end
      
      PAYLOAD: begin
        // Compute the payload length as (packet_length - 8)
        if (payload_cnt < (packet_length - 16'd8)) begin
          // Only transfer data if the input FIFO is not empty and the output FIFO
          // is not full.
          if (!in_empty && !out_full) begin
            in_rd_en  = 1'b1;
            out_wr_en = 1'b1;
            out_data  = in_data;
          end
        end
        else begin
          // Once the required number of payload bytes have been transferred,
          // go to the DONE state.
          next_state = DONE;
        end
      end
      
      DONE: begin
        // Packet complete; return to IDLE to be ready for a new packet.
        next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end

endmodule