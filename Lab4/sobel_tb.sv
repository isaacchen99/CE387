`timescale 1 ns / 1 ns

module sobel_tb;

  //-------------------------------------------------------------------------
  // Parameters
  //-------------------------------------------------------------------------
  localparam string IMG_IN_NAME  = "image.bmp";
  localparam string IMG_OUT_NAME = "output.bmp";
  localparam string IMG_CMP_NAME = "sobel.bmp";  // Golden output file
  localparam CLOCK_PERIOD    = 10;

  localparam WIDTH             = 720;
  localparam HEIGHT            = 540;
  localparam BMP_HEADER_SIZE   = 54;
  localparam BYTES_PER_PIXEL   = 3;
  localparam BMP_DATA_SIZE     = WIDTH * HEIGHT * BYTES_PER_PIXEL;

  //-------------------------------------------------------------------------
  // DUT Interface Signals
  //-------------------------------------------------------------------------
  logic         clock = 1'b1;
  logic         reset = 1'b0;
  logic         start = 1'b0;
  
  // Input side (24-bit BMP pixels)
  logic         in_full;
  logic         in_wr_en = 1'b0;
  logic [23:0]  in_din   = 24'd0;
  
  // Output side (8-bit Sobel output)
  logic         out_rd_en;
  logic         out_empty;
  logic  [7:0]  out_dout;

  // Testbench control signals
  logic         in_write_done  = 1'b0;
  logic         out_read_done  = 1'b0;
  integer       out_errors     = 0;

  //-------------------------------------------------------------------------
  // Instantiate the Top Module (sobel_top)
  //-------------------------------------------------------------------------
  sobel_top #(
      .WIDTH(WIDTH),
      .HEIGHT(HEIGHT)
  ) sobel_top_inst (
      .clock    (clock),
      .reset    (reset),
      .in_full  (in_full),
      .in_wr_en (in_wr_en),
      .in_din   (in_din),
      .out_empty(out_empty),
      .out_rd_en(out_rd_en),
      .out_dout (out_dout)
  );

  //-------------------------------------------------------------------------
  // Clock Generation
  //-------------------------------------------------------------------------
  always begin
      clock = 1'b1;
      #(CLOCK_PERIOD/2);
      clock = 1'b0;
      #(CLOCK_PERIOD/2);
  end

  //-------------------------------------------------------------------------
  // Reset Generation
  //-------------------------------------------------------------------------
  initial begin
      @(posedge clock);
      reset = 1'b1;
      @(posedge clock);
      reset = 1'b0;
  end

  //-------------------------------------------------------------------------
  // Simulation Control Process
  // Wait for the output file read process to finish, then report
  // simulation metrics and finish.
  //-------------------------------------------------------------------------
  initial begin : tb_process
      longint unsigned start_time, end_time;
      
      @(negedge reset);
      @(posedge clock);
      start_time = $time;
      $display("@ %0t: Beginning simulation...", start_time);
      
      start = 1'b1;
      @(posedge clock);
      start = 1'b0;
      
      // Wait until the image write (and compare) process is complete
      wait(out_read_done);
      end_time = $time;
      
      $display("@ %0t: Simulation completed.", end_time);
      $display("Total simulation cycle count: %0d", (end_time - start_time) / CLOCK_PERIOD);
      $display("Total error count: %0d", out_errors);
      
      $finish;
  end

  //-------------------------------------------------------------------------
  // Image Read Process
  // Reads the BMP input file, skips the header, and streams the pixel data
  // into the DUT via the in_din/in_wr_en interface.
  //-------------------------------------------------------------------------
  initial begin : img_read_process
      int i, r;
      int in_file;
      // Array to hold the BMP header
      logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

      @(negedge reset);
      $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);

      in_file = $fopen(IMG_IN_NAME, "rb");
      in_wr_en = 1'b0;

      // Skip BMP header
      r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

      // Read and stream pixel data (24-bit, 3 bytes per pixel)
      i = 0;
      while (i < BMP_DATA_SIZE) begin
          @(negedge clock);
          in_wr_en = 1'b0;
          if (in_full == 1'b0) begin
              // Read 3 bytes (BYTES_PER_PIXEL) from the file into in_din
              r = $fread(in_din, in_file, BMP_HEADER_SIZE + i, BYTES_PER_PIXEL);
              in_wr_en = 1'b1;
              i += BYTES_PER_PIXEL;
          end
      end

      @(negedge clock);
      in_wr_en = 1'b0;
      $fclose(in_file);
      in_write_done = 1'b1;
  end

  //-------------------------------------------------------------------------
  // Image Write Process
  // Reads the DUT output from out_dout, writes to an output BMP file,
  // and compares each pixel to the golden file.
  //-------------------------------------------------------------------------
  initial begin : img_write_process
      int i, r;
      int out_file;
      int cmp_file;
      logic [23:0] cmp_dout;  // Read golden pixel data (3 copies of the 8-bit output)
      logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

      @(negedge reset);
      @(negedge clock);

      $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
      
      out_file = $fopen(IMG_OUT_NAME, "wb");
      cmp_file = $fopen(IMG_CMP_NAME, "rb");
      out_rd_en = 1'b0;
      
      // Copy the BMP header from the golden file to the output file
      r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
      for (i = 0; i < BMP_HEADER_SIZE; i++) begin
          $fwrite(out_file, "%c", bmp_header[i]);
      end

      i = 0;
      while (i < BMP_DATA_SIZE) begin
          @(negedge clock);
          out_rd_en = 1'b0;
          if (out_empty == 1'b0) begin
              // Read golden pixel data (3 bytes per pixel)
              r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE + i, BYTES_PER_PIXEL);
              // Write the same output pixel three times (to form 24-bit data)
              $fwrite(out_file, "%c%c%c", out_dout, out_dout, out_dout);

              // Compare the output pixel (replicated 3 times) with the golden data
              if (cmp_dout != {3{out_dout}}) begin
                  out_errors += 1;
                  $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n",
                          $time, IMG_OUT_NAME, i+1, {3{out_dout}}, cmp_dout, i);
              end
              out_rd_en = 1'b1;
              i += BYTES_PER_PIXEL;
          end
      end

      @(negedge clock);
      out_rd_en = 1'b0;
      $fclose(out_file);
      $fclose(cmp_file);
      out_read_done = 1'b1;
  end

endmodule