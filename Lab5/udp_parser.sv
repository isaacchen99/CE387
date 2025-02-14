module udp_parser (
  input  logic         clk,
  input  logic         rst_n,
  
  // Input interface from the read side of the ctrl_fifo.
  // These signals are assumed to be “framed” (with SOF/EOF) coming from the FIFO.
  input  logic [7:0]   in_data,
  input  logic         in_valid,
  input  logic         in_sof,
  input  logic         in_eof,
  input  logic         in_fifo_empty,  // indicates no data available in input FIFO
  output logic         in_ready,       // tells FIFO that we can accept data
  
  // Output interface to the write side of the ctrl_fifo.
  // The UDP payload is forwarded out with a new set of SOF/EOF markers.
  output logic [7:0]   out_data,
  output logic         out_valid,
  output logic         out_sof,
  output logic         out_eof,
  input  logic         out_ready,
  input  logic         out_fifo_full,  // indicates that downstream FIFO is full
  
  output logic         error_flag
);

  //-------------------------------------------------------------------------
  // FSM state definitions
  //-------------------------------------------------------------------------
  typedef enum logic [2:0] {
    IDLE,           // wait for SOF on input
    READ_ETH,       // read 14-byte Ethernet header
    READ_IP,        // read 20-byte IP header
    READ_UDP_HDR,   // read 8-byte UDP header
    READ_UDP_DATA,  // read UDP payload (length determined from header)
    ERROR_STATE     // error: flush input until end-of-frame
  } state_t;
  
  state_t state;

  //-------------------------------------------------------------------------
  // Header byte counters and registers
  //-------------------------------------------------------------------------
  logic [3:0]  eth_cnt;       // count 0 to 13 for Ethernet header
  logic [4:0]  ip_cnt;        // count 0 to 19 for IP header
  logic [2:0]  udp_hdr_cnt;   // count 0 to 7 for UDP header
  logic [15:0] udp_data_cnt;  // counts UDP payload bytes
  
  // Header fields needed for validation/extraction
  logic [15:0] eth_type;         // Ethernet type (expect 0x0800 for IPv4)
  logic [7:0]  ip_ver_ihl;       // IP version and header length (upper nibble must equal 4)
  logic [7:0]  ip_protocol;      // IP protocol field (expect 0x11 for UDP)
  logic [15:0] udp_length;       // UDP length field (includes header)
  logic [15:0] udp_data_length;  // computed UDP payload length = udp_length - 8

  // Registered outputs for the streaming interface
  logic [7:0] out_data_reg;
  logic       out_valid_reg;
  logic       out_sof_reg;
  logic       out_eof_reg;
  
  assign out_data  = out_data_reg;
  assign out_valid = out_valid_reg;
  assign out_sof   = out_sof_reg;
  assign out_eof   = out_eof_reg;
  
  // We drive in_ready to the input FIFO only when the output FIFO is not full.
  // (If the downstream FIFO is full, we must stall.)
  assign in_ready = !out_fifo_full;
  
  //-------------------------------------------------------------------------
  // FSM: Sequential Process
  //-------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      eth_cnt         <= 0;
      ip_cnt          <= 0;
      udp_hdr_cnt     <= 0;
      udp_data_cnt    <= 0;
      eth_type        <= 16'h0;
      ip_ver_ihl      <= 8'h0;
      ip_protocol     <= 8'h0;
      udp_length      <= 16'h0;
      udp_data_length <= 16'h0;
      out_data_reg    <= 8'h0;
      out_valid_reg   <= 1'b0;
      out_sof_reg     <= 1'b0;
      out_eof_reg     <= 1'b0;
      error_flag      <= 1'b0;
    end
    else begin
      // Default outputs: no valid output unless explicitly driven
      out_valid_reg <= 1'b0;
      out_sof_reg   <= 1'b0;
      out_eof_reg   <= 1'b0;
      
      case (state)
        //============================================================
        IDLE: begin
          error_flag <= 1'b0;
          // Only start a new frame if we see SOF and data is available.
          if (in_valid && in_sof && !in_fifo_empty) begin
            state   <= READ_ETH;
            eth_cnt <= 0;
          end
        end
        
        //============================================================
        READ_ETH: begin
          // Ensure we only process when input data is available.
          if (in_valid && !in_fifo_empty) begin
            // Capture Ethernet header bytes.
            // Bytes 0-5: Destination MAC; 6-11: Source MAC (ignored here).
            // Bytes 12-13: Ethertype.
            if (eth_cnt == 12) begin
              eth_type[15:8] <= in_data;
            end
            else if (eth_cnt == 13) begin
              eth_type[7:0] <= in_data;
              // Validate: must be IPv4 (0x0800).
              if ({eth_type[15:8], in_data} != 16'h0800) begin
                state      <= ERROR_STATE;
                error_flag <= 1'b1;
              end
              else begin
                state   <= READ_IP;
                ip_cnt  <= 0;
              end
            end
            eth_cnt <= eth_cnt + 1;
          end
        end

        //============================================================
        READ_IP: begin
          if (in_valid && !in_fifo_empty) begin
            // Process 20-byte IP header.
            if (ip_cnt == 0) begin
              ip_ver_ihl <= in_data;
              // Validate IP version: upper nibble must equal 4.
              if (in_data[7:4] != 4) begin
                state      <= ERROR_STATE;
                error_flag <= 1'b1;
              end
            end
            // Byte 9: Protocol field must be UDP (0x11).
            else if (ip_cnt == 9) begin
              ip_protocol <= in_data;
              if (in_data != 8'h11) begin
                state      <= ERROR_STATE;
                error_flag <= 1'b1;
              end
            end
            ip_cnt <= ip_cnt + 1;
            if (ip_cnt == 19) begin
              state       <= READ_UDP_HDR;
              udp_hdr_cnt <= 0;
            end
          end
        end

        //============================================================
        READ_UDP_HDR: begin
          if (in_valid && !in_fifo_empty) begin
            // Process the 8-byte UDP header.
            // Bytes 0-1: Destination port (ignored).
            // Bytes 2-3: Source port (ignored).
            // Bytes 4-5: UDP length (header + payload).
            // Bytes 6-7: UDP checksum (ignored here).
            case (udp_hdr_cnt)
              0,1,2,3: ;  // ports ignored.
              4: begin
                   udp_length[15:8] <= in_data;
                 end
              5: begin
                   udp_length[7:0] <= in_data;
                   // Calculate UDP payload length = UDP length - 8 (header bytes)
                   udp_data_length <= {udp_length[15:8], in_data} - 16'd8;
                 end
              6,7: ;  // checksum bytes (ignored)
            endcase
            udp_hdr_cnt <= udp_hdr_cnt + 1;
            if (udp_hdr_cnt == 7) begin
              state        <= READ_UDP_DATA;
              udp_data_cnt <= 0;
            end
          end
        end

        //============================================================
        READ_UDP_DATA: begin
          // In the UDP data state, we must check that we are allowed to
          // write to the output FIFO before streaming a byte.
          if (in_valid && !in_fifo_empty && out_ready && !out_fifo_full) begin
            // Drive the output with the UDP payload byte.
            out_data_reg  <= in_data;
            out_valid_reg <= 1'b1;
            if (udp_data_cnt == 0)
              out_sof_reg <= 1'b1;
            if (udp_data_cnt == udp_data_length - 1)
              out_eof_reg <= 1'b1;
  
            udp_data_cnt <= udp_data_cnt + 1;
            // When the final UDP data byte is sent, return to IDLE.
            if (udp_data_cnt == udp_data_length - 1)
              state <= IDLE;
          end
          // Otherwise, if out_fifo is full or data is not available,
          // the FSM simply stalls.
        end

        //============================================================
        ERROR_STATE: begin
          // In an error state, flush the current frame.
          if (in_valid && in_eof && !in_fifo_empty) begin
            state <= IDLE;
          end
        end

        //============================================================
        default: state <= IDLE;
      endcase
    end
  end

endmodule