`timescale 1ns/1ps

module udp_parser_tb;

  //--------------------------------------------------------------------------
  // Clock & Reset
  //--------------------------------------------------------------------------

  logic clk;
  logic reset;

  // Generate a 10ns period clock.
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset active for a short period.
  initial begin
    reset = 1;
    #20;
    reset = 0;
  end

  //--------------------------------------------------------------------------
  // Interface Signals for top_udp_parser Instance
  //--------------------------------------------------------------------------

  // Input FIFO side (from testbench into top module)
  logic [7:0]  tb_in_data;
  logic        tb_in_valid;
  logic        tb_in_sof;
  logic        tb_in_eof;
  logic        tb_in_ready;

  // Output FIFO side (from top module to testbench)
  logic [7:0]  tb_out_data;
  logic        tb_out_valid;
  logic        tb_out_sof;
  logic        tb_out_eof;
  // Always accept output data.
  assign tb_out_ready = 1;

  //--------------------------------------------------------------------------
  // Instantiate the top-level UDP parser module
  //--------------------------------------------------------------------------

  top_udp_parser uut (
    .clk         (clk),
    .reset       (reset),
    .tb_in_data  (tb_in_data),
    .tb_in_valid (tb_in_valid),
    .tb_in_sof   (tb_in_sof),
    .tb_in_eof   (tb_in_eof),
    .tb_in_ready (tb_in_ready),
    .tb_out_data (tb_out_data),
    .tb_out_valid(tb_out_valid),
    .tb_out_sof (tb_out_sof),
    .tb_out_eof (tb_out_eof),
    .tb_out_ready(tb_out_ready)
  );

  //--------------------------------------------------------------------------
  // Testbench: Drive the Input FIFO from a PCAP File
  //--------------------------------------------------------------------------

  // File handles
  integer pcap_f, sim_out_f, ref_f;
  integer r;
  integer i;
  integer incl_len;
  integer global_hdr_size   = 24;
  integer packet_hdr_size   = 16;

  // A temporary register to hold a byte read from file.
  reg [7:0] file_byte;

  // This task sends one packet’s bytes into the input FIFO.
  task send_packet(input integer num_bytes);
    begin
      for (i = 0; i < num_bytes; i = i + 1) begin
        // Wait until the input FIFO is ready.
        @(posedge clk);
        while (!tb_in_ready)
          @(posedge clk);
        // Read one byte from the PCAP file.
        r = $fgetc(pcap_f);
        // r returns an integer; mask to 8 bits.
        file_byte = r[7:0];
        // Drive the signals:
        tb_in_data  = file_byte;
        tb_in_valid = 1;
        tb_in_sof   = (i == 0) ? 1 : 0;
        tb_in_eof   = (i == num_bytes - 1) ? 1 : 0;
        @(posedge clk);
        tb_in_valid = 0;
        tb_in_sof   = 0;
        tb_in_eof   = 0;
      end
    end
  endtask

  // Main stimulus: open PCAP file, skip global header, then stream each packet.
  initial begin
    // Open the PCAP file for binary reading.
    pcap_f = $fopen("input.pcap", "rb");
    if (pcap_f == 0) begin
      $display("ERROR: Could not open input.pcap");
      $finish;
    end

    // Open simulation output file (to write UDP payload bytes).
    sim_out_f = $fopen("sim_out.txt", "w");
    if (sim_out_f == 0) begin
      $display("ERROR: Could not open sim_out.txt for writing");
      $finish;
    end

    // Open reference output file (for comparison).
    ref_f = $fopen("test_output.txt", "r");
    if (ref_f == 0) begin
      $display("ERROR: Could not open test_output.txt for reading");
      $finish;
    end

    // Skip the 24-byte global header.
    for (i = 0; i < global_hdr_size; i = i + 1)
      r = $fgetc(pcap_f);

    // Now, for each packet in the PCAP file, read its 16-byte header and then the packet data.
    while (!$feof(pcap_f)) begin
      // Skip the first 8 bytes of the per-packet header (timestamp fields).
      for (i = 0; i < 8; i = i + 1)
        r = $fgetc(pcap_f);

      // Read incl_len from the next 4 bytes.
      incl_len = 0;
      incl_len = incl_len | ($fgetc(pcap_f) & 8'hFF);
      incl_len = incl_len | (( $fgetc(pcap_f) & 8'hFF) << 8);
      incl_len = incl_len | (( $fgetc(pcap_f) & 8'hFF) << 16);
      incl_len = incl_len | (( $fgetc(pcap_f) & 8'hFF) << 24);

      // Skip the last 4 bytes of the packet header (orig_len).
      for (i = 0; i < 4; i = i + 1)
        r = $fgetc(pcap_f);

      // Send this packet (incl_len bytes) into the input FIFO.
      send_packet(incl_len);

      // Wait a few cycles before sending the next packet.
      repeat (10) @(posedge clk);
    end

    $fclose(pcap_f);
    $display("Finished sending packets from input.pcap");
  end

  //--------------------------------------------------------------------------
  // Testbench: Capture Output from the UDP Parser
  //--------------------------------------------------------------------------

  // Collect output bytes from the output FIFO and write them to sim_out.txt.
  initial begin
    // Wait for reset to deassert.
    @(negedge reset);
    // Let the simulation run for a while.
    #100;
    forever begin
      @(posedge clk);
      if (tb_out_valid) begin
        // Write the received output byte as a character.
        $fwrite(sim_out_f, "%c", tb_out_data);
      end
    end
  end

  //--------------------------------------------------------------------------
  // Testbench: Compare sim_out.txt against test_output.txt
  //--------------------------------------------------------------------------

  // This task opens both files and compares them line-by-line.
  task compare_output;
    integer sim_line_fh, ref_line_fh;
    string sim_line, ref_line;
    begin
      sim_line_fh = $fopen("sim_out.txt", "r");
      ref_line_fh = $fopen("test_output.txt", "r");
      if (sim_line_fh == 0 || ref_line_fh == 0) begin
        $display("ERROR: Could not open one of the files for comparison.");
        disable compare_output;
      end

      // Compare files until end-of-file is reached.
      while (!$feof(sim_line_fh) && !$feof(ref_line_fh)) begin
        sim_line = "";
        ref_line = "";
        void'($fgets(sim_line, sim_line_fh));
        void'($fgets(ref_line, ref_line_fh));
        if (sim_line != ref_line) begin
          $display("ERROR: Mismatch detected: sim_out: %s  test_output: %s", sim_line, ref_line);
        end
      end
      $fclose(sim_line_fh);
      $fclose(ref_line_fh);
    end
  endtask

  // Invoke comparison after a delay (for example, after 1ms simulation time).
  initial begin
    #1000; // wait for outputs to accumulate
    compare_output();
  end

  //--------------------------------------------------------------------------
  // End-of-Simulation: Optionally stop simulation after a fixed time.
  //--------------------------------------------------------------------------

  initial begin
    #2000;
    $display("Simulation complete.");
    $finish;
  end

endmodule