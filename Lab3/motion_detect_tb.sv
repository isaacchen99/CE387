`timescale 1 ns / 1 ns

module motion_detect_tb;
    // ------------------------------------------------------------------------
    // File names for input and output
    // ------------------------------------------------------------------------
    localparam string BASE_IMG   = "base.bmp";         // Background image
    localparam string FRAME_IMG  = "pedestrians.bmp";  // Frame image
    localparam string REF_IMG    = "img_out.bmp";      // Reference (golden) image
    localparam string OUT_IMG    = "pipeline_out.bmp"; // DUT output image

    // ------------------------------------------------------------------------
    // Image parameters
    // ------------------------------------------------------------------------
    localparam int WIDTH  = 720;
    localparam int HEIGHT = 540;

    localparam int BMP_HEADER_SIZE  = 54;   // Standard BMP header
    localparam int BYTES_PER_PIXEL  = 3;    // 24‐bit BMP
    localparam int BMP_DATA_SIZE    = WIDTH * HEIGHT * BYTES_PER_PIXEL;

    // ------------------------------------------------------------------------
    // Clock / Reset signals
    // ------------------------------------------------------------------------
    localparam CLOCK_PERIOD = 10;
    logic clk   = 1'b0;
    logic reset = 1'b1;  // start in reset

    // ------------------------------------------------------------------------
    // DUT I/O signals
    // ------------------------------------------------------------------------
    logic         bg_wr_en;
    logic [31:0]  bg_din;
    logic         bg_full;

    logic         frame_wr_en;
    logic [31:0]  frame_din;
    logic         frame_full;

    logic         frame_wr_en2;
    logic [31:0]  frame_din2;
    logic         frame_full2;

    logic         final_rd_en;
    logic [31:0]  final_dout;
    logic         final_empty;

    // ------------------------------------------------------------------------
    // Control signals for main test processes
    // ------------------------------------------------------------------------
    logic base_write_done   = 1'b0;
    logic frame_write_done  = 1'b0;
    logic output_read_done  = 1'b0;
    integer error_count     = 0;

    // ------------------------------------------------------------------------
    // Store BMP header from the base image
    // ------------------------------------------------------------------------
    logic [7:0] base_header_mem [0:BMP_HEADER_SIZE-1];

    // ------------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------------
    motion_detect_top dut (
        .clk           (clk),
        .reset         (reset),

        // Background input
        .bg_wr_en      (bg_wr_en),
        .bg_din        (bg_din),
        .bg_full       (bg_full),

        // Frame input
        .frame_wr_en   (frame_wr_en),
        .frame_din     (frame_din),
        .frame_full    (frame_full),

        // Frame input 2
        .frame_wr_en2  (frame_wr_en2),
        .frame_din2    (frame_din2),
        .frame_full2   (frame_full2),

        // Final output
        .final_rd_en   (final_rd_en),
        .final_dout    (final_dout),
        .final_empty   (final_empty)
    );

    // ------------------------------------------------------------------------
    // Generate clock
    // ------------------------------------------------------------------------
    always begin
        #(CLOCK_PERIOD/2) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // De‐assert reset after a few clock cycles
    // ------------------------------------------------------------------------
    initial begin
        # (5 * CLOCK_PERIOD);
        reset = 1'b0;
    end

    // ------------------------------------------------------------------------
    // Main control: wait for tasks to finish, then end simulation
    // ------------------------------------------------------------------------
    initial begin : main_control
        integer start_time, end_time;

        wait (!reset);       // wait until reset is de‐asserted
        @(posedge clk);
        start_time = $time;
        $display("[TB] @%0t: Starting simulation...", start_time);

        // Wait until background push, frame push, and output reading are all done
        wait (base_write_done && frame_write_done && output_read_done);

        end_time = $time;
        $display("[TB] @%0t: Simulation complete.", end_time);
        $display("Simulation cycle count: %0d", (end_time - start_time)/CLOCK_PERIOD);
        $display("Total pixel errors: %0d", error_count);

        $finish;
    end

    // ------------------------------------------------------------------------
    // Helper task: read 3 bytes from a file as {B,G,R}, pack into 32 bits
    //   32-bit output is {8'bblue, 8'bgreen, 8'bred, 8'h00}
    // ------------------------------------------------------------------------
    task automatic read_bgr_32(
        input  integer      fd,
        output logic [31:0] pix_32,
        output integer      status
    );
        logic [7:0] blue, green, red;
        status = $fread(blue,  fd);
        status = $fread(green, fd);
        status = $fread(red,   fd);
        pix_32 = {blue, green, red, 8'h00};
    endtask

    // ------------------------------------------------------------------------
    // Process #1: Read background image (base.bmp)
    //             - Store its header
    //             - Push pixel data into DUT
    // ------------------------------------------------------------------------
    initial begin : base_image_process
        integer base_fd;
        integer i, r;
        logic [31:0] pixel_32;

        // Default
        bg_wr_en  = 1'b0;
        bg_din    = 32'h0;

        // Wait for reset to finish
        wait (!reset);
        @(negedge clk);

        // Open base.bmp
        base_fd = $fopen(BASE_IMG, "rb");
        if (base_fd == 0) begin
            $display("[TB] ERROR: Could not open file %s", BASE_IMG);
            $finish;
        end
        $display("[TB] @%0t: Reading background file: %s", $time, BASE_IMG);

        // Read the 54-byte BMP header into base_header_mem
        r = $fread(base_header_mem, base_fd, 0, BMP_HEADER_SIZE);

        // Now read each 3-byte pixel, push into the DUT
        for (i = 0; i < BMP_DATA_SIZE; i += BYTES_PER_PIXEL) begin
            @(negedge clk);
            bg_wr_en = 1'b0;

            // Only write if the FIFO isn't full
            if (!bg_full) begin
                read_bgr_32(base_fd, pixel_32, r);
                bg_din   = pixel_32;
                bg_wr_en = 1'b1;
            end
        end

        @(negedge clk);
        bg_wr_en        = 1'b0;
        base_write_done = 1'b1;

        $fclose(base_fd);
    end

    // ------------------------------------------------------------------------
    // Process #2: Read frame image (pedestrians.bmp)
    //             - Skip its header
    //             - Push pixel data into 'frame' FIFO
    //             - Then push the **same** pixel data again for 'frame2' FIFO
    //
    //  Explanation:
    //   "frame_wr_en2" uses the same data as "frame_wr_en" but is processed
    //   later in the pipeline. We'll feed it again from the same file.
    // ------------------------------------------------------------------------
    initial begin : frame_image_process
        integer frame_fd;
        integer i, r;
        logic [7:0] discard_header [0:BMP_HEADER_SIZE-1];
        logic [31:0] pixel_32;

        // Default
        frame_wr_en  = 1'b0;
        frame_wr_en2 = 1'b0;
        frame_din    = 32'h0;
        frame_din2   = 32'h0;

        // Wait for reset
        wait (!reset);
        @(negedge clk);

        // Open pedestrians.bmp
        frame_fd = $fopen(FRAME_IMG, "rb");
        if (frame_fd == 0) begin
            $display("[TB] ERROR: Could not open file %s", FRAME_IMG);
            $finish;
        end
        $display("[TB] @%0t: Reading frame file: %s", $time, FRAME_IMG);

        // Skip its 54-byte header
        r = $fread(discard_header, frame_fd, 0, BMP_HEADER_SIZE);

        // First pass: read all pixels, feed frame_wr_en
        for (i = 0; i < BMP_DATA_SIZE; i += BYTES_PER_PIXEL) begin
            @(negedge clk);
            frame_wr_en = 1'b0;
            if (!frame_full) begin
                read_bgr_32(frame_fd, pixel_32, r);
                frame_din   = pixel_32;
                frame_wr_en = 1'b1;
            end
        end

        // We reached the end of the file. If you truly want the *same* data
        // for frame_wr_en2, you can either re-wind the file or close/open it
        // again. For simplicity, let's close and reopen:
        @(negedge clk);
        frame_wr_en      = 1'b0;
        frame_write_done  = 1'b1;
        $fclose(frame_fd);

        // Re-open the same file to feed the same data to frame2
        frame_fd = $fopen(FRAME_IMG, "rb");
        r = $fread(discard_header, frame_fd, 0, BMP_HEADER_SIZE);

        // Second pass: feed frame_wr_en2
        for (i = 0; i < BMP_DATA_SIZE; i += BYTES_PER_PIXEL) begin
            @(negedge clk);
            frame_wr_en2 = 1'b0;
            if (!frame_full2) begin
                read_bgr_32(frame_fd, pixel_32, r);
                frame_din2   = pixel_32;
                frame_wr_en2 = 1'b1;
            end
        end

        @(negedge clk);
        frame_wr_en2      = 1'b0;
        $fclose(frame_fd);
    end

    // ------------------------------------------------------------------------
    // Process #3: Read DUT output and compare to reference
    //   - Open reference image (img_out.bmp)
    //   - Skip reference header
    //   - Write stored base header to pipeline_out.bmp
    //   - Compare each pixel with reference, log errors
    // ------------------------------------------------------------------------
    initial begin : output_compare_process
        integer ref_fd, out_fd;
        integer i, r;
        logic [7:0] ref_blue, ref_green, ref_red;
        logic [31:0] dut_word;
        logic [23:0] ref_word;
        logic [7:0] ref_header [0:BMP_HEADER_SIZE-1];

        // Defaults
        final_rd_en = 1'b0;

        // Wait for reset
        wait(!reset);
        @(negedge clk);

        // Open reference
        ref_fd = $fopen(REF_IMG, "rb");
        if (ref_fd == 0) begin
            $display("[TB] ERROR: Cannot open reference image %s", REF_IMG);
            $finish;
        end

        // Create output file
        out_fd = $fopen(OUT_IMG, "wb");
        if (out_fd == 0) begin
            $display("[TB] ERROR: Cannot create output file %s", OUT_IMG);
            $finish;
        end

        // Write the base (background) header to pipeline_out.bmp
        for (i = 0; i < BMP_HEADER_SIZE; i++) begin
            $fwrite(out_fd, "%c", base_header_mem[i]);
        end

        // Skip the reference header so we can compare pixel data
        // You can do this by reading 54 bytes or calling $fseek:
        //   r = $fseek(ref_fd, BMP_HEADER_SIZE, 0);
        // or equivalently:
        r = $fread(ref_header, ref_fd, 0, BMP_HEADER_SIZE);

        $display("[TB] @%0t: Comparing DUT output to reference: %s", $time, REF_IMG);

        i = 0;
        while (i < BMP_DATA_SIZE) begin
            @(negedge clk);
            final_rd_en = 1'b0;

            if (!final_empty) begin
                final_rd_en = 1'b1;
                dut_word    = final_dout;  // {B, G, R, 8'h00}

                // Read 3 bytes from reference
                r = $fread(ref_blue,  ref_fd);
                r = $fread(ref_green, ref_fd);
                r = $fread(ref_red,   ref_fd);
                ref_word = {ref_blue, ref_green, ref_red}; // 24 bits

                // Write DUT output pixel to file
                // DUT pixel is {Blue, Green, Red, 8'h00}
                // So we do:
                $fwrite(out_fd, "%c%c%c",
                        dut_word[31:24],
                        dut_word[23:16],
                        dut_word[15: 8] );

                // Compare
                if (ref_word !== {dut_word[31:24], dut_word[23:16], dut_word[15:8]}) begin
                    error_count++;
                    $display("[TB] @%0t: Pixel %0d mismatch. Reference=%x, DUT=%x",
                             $time, i/BYTES_PER_PIXEL,
                             ref_word,
                             {dut_word[31:24], dut_word[23:16], dut_word[15:8]});
                end

                i += BYTES_PER_PIXEL;
            end
        end

        @(negedge clk);
        final_rd_en     = 1'b0;
        $fclose(ref_fd);
        $fclose(out_fd);

        output_read_done = 1'b1;
    end

endmodule