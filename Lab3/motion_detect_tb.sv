`timescale 1 ns / 1 ns

module motion_detect_tb;
    localparam string BASE_IMG   = "base.bmp";         // Background image
    localparam string FRAME_IMG  = "pedestrians.bmp";  // Frame image
    localparam string REF_IMG    = "img_out.bmp";      // Reference (golden) image

    localparam int WIDTH  = 720;
    localparam int HEIGHT = 540;

    localparam int BMP_HEADER_SIZE  = 54;   // Standard BMP header
    localparam int BYTES_PER_PIXEL  = 3;    // 24‐bit BMP
    localparam int BMP_DATA_SIZE    = WIDTH * HEIGHT * BYTES_PER_PIXEL;

    localparam CLOCK_PERIOD = 10;
    logic clk   = 1'b0;
    logic reset = 1'b1;  // start in reset

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

    logic base_write_done   = 1'b0;
    logic frame_write_done  = 1'b0;
    logic output_read_done  = 1'b0;
    integer error_count     = 0;

    logic [7:0] base_header_mem [0:BMP_HEADER_SIZE-1];

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

    always begin
        #(CLOCK_PERIOD/2) clk = ~clk;
    end

    initial begin
        # (5 * CLOCK_PERIOD);
        reset = 1'b0;
    end

    initial begin : main_control
        integer start_time, end_time;

        wait (!reset);       // wait until reset is de‐asserted
        @(posedge clk);
        start_time = $time;
        $display("[TB] @%0t: Starting simulation...", start_time);

        // Wait until background push, frame push, and output reading are all done
        wait (output_read_done);

        end_time = $time;
        $display("[TB] @%0t: Simulation complete.", end_time);
        $display("Simulation cycle count: %0d", (end_time - start_time)/CLOCK_PERIOD);
        $display("Total pixel errors: %0d", error_count);

        $finish;
    end

    initial begin : base_image_process
        int i, r;
        int base_fd;
        logic [7:0] base_header [0:BMP_HEADER_SIZE-1];
        logic [7:0] blue, green, red;  // Separate byte variables for RGB components

        @(negedge reset);
        $display("@ %0t: Opening file %s...", $time, BASE_IMG);

        base_fd = $fopen(BASE_IMG, "rb");
        bg_wr_en = 1'b0;

        // Read BMP header
        r = $fread(base_header, base_fd, 0, BMP_HEADER_SIZE);

        // Read pixel data
        i = 0;
        while (i < BMP_DATA_SIZE) begin  // Assuming BMP_DATA_SIZE is replaced by a direct value
            @(negedge clk);
            bg_wr_en = 1'b0;
            if (!bg_full) begin
                r = $fread(blue,  base_fd);  // Read blue component
                r = $fread(green, base_fd);  // Read green component
                r = $fread(red,   base_fd);  // Read red component
                bg_din = {blue, green, red, 8'h00};  // Pack into 32 bits, with 8 bits padding
                bg_wr_en = 1'b1;
                i += 3;  // Increment by bytes per pixel read
            end
        end

        @(negedge clk);
        bg_wr_en = 1'b0;
        base_write_done = 1'b1;

        $fclose(base_fd);
    end

    // Process for feeding FIFO 1
initial begin : frame_image_process1
    int frame_fd;
    int i, r;
    logic [7:0] discard_header [0:BMP_HEADER_SIZE-1];
    logic [7:0] blue, green, red;
    logic [31:0] pixel_32;

    @(negedge reset);
    $display("@ %0t: Opening file %s...", $time, FRAME_IMG);

    frame_fd = $fopen(FRAME_IMG, "rb");
    frame_wr_en = 1'b0;

    if (frame_fd == 0) begin
        $display("[TB] ERROR: Could not open file %s", FRAME_IMG);
        $finish;
    end

    r = $fread(discard_header, frame_fd, 0, BMP_HEADER_SIZE);

    i = 0;
    while (i < BMP_DATA_SIZE) begin
        @(negedge clk);
        frame_wr_en = 1'b0;
        if (!frame_full) begin
            r = $fread(blue, frame_fd);
            r = $fread(green, frame_fd);
            r = $fread(red, frame_fd);
            pixel_32 = {blue, green, red, 8'h00};

            frame_din = pixel_32;
            frame_wr_en = 1'b1;
            i += 3; 
        end
    end

    @(negedge clk);
    frame_wr_en = 1'b0;
    $fclose(frame_fd);
end

initial begin : frame_image_process2
    int frame_fd2;
    int i, r2;
    logic [7:0] discard_header2 [0:BMP_HEADER_SIZE-1];
    logic [7:0] blue, green, red;
    logic [31:0] pixel_32;

    @(negedge reset);
    $display("@ %0t: Opening file %s...", $time, FRAME_IMG);

    frame_fd2 = $fopen(FRAME_IMG, "rb");
    frame_wr_en2 = 1'b0;

    if (frame_fd2 == 0) begin
        $display("[TB] ERROR: Could not open file %s", FRAME_IMG);
        $finish;
    end

    r2 = $fread(discard_header2, frame_fd2, 0, BMP_HEADER_SIZE);

    i = 0;
    while (i < BMP_DATA_SIZE) begin
        @(negedge clk);
        frame_wr_en2 = 1'b0;
        if (!frame_full2) begin
            r2 = $fread(blue, frame_fd2);
            r2 = $fread(green, frame_fd2);
            r2 = $fread(red, frame_fd2);
            pixel_32 = {blue, green, red, 8'h00};

            frame_din2 = pixel_32;
            frame_wr_en2 = 1'b1;
            i += 3;  // Increment by bytes per pixel read
        end
    end

    @(negedge clk);
    frame_wr_en2 = 1'b0;
    $fclose(frame_fd2);
end

    initial begin : output_compare_process
        integer ref_fd, out_fd;
        integer i, r;
        logic [7:0] ref_blue, ref_green, ref_red;
        logic [31:0] dut_word;
        logic [23:0] ref_word;
        logic [7:0] ref_header [0:BMP_HEADER_SIZE-1];

        final_rd_en = 1'b0;

        wait(!reset);
        @(negedge clk);

        ref_fd = $fopen(REF_IMG, "rb");
        if (ref_fd == 0) begin
            $display("[TB] ERROR: Cannot open reference image %s", REF_IMG);
            $finish;
        end

        for (i = 0; i < BMP_HEADER_SIZE; i++) begin
            $fwrite(out_fd, "%c", base_header_mem[i]);
        end

        r = $fread(ref_header, ref_fd, 0, BMP_HEADER_SIZE);

        $display("[TB] @%0t: Comparing DUT output to reference: %s", $time, REF_IMG);

        i = 0;
        while (i < BMP_DATA_SIZE) begin
            @(negedge clk);
            final_rd_en = 1'b0;

            if (!final_empty) begin
                final_rd_en = 1'b1;
                dut_word    = final_dout; 

                r = $fread(ref_blue,  ref_fd);
                r = $fread(ref_green, ref_fd);
                r = $fread(ref_red,   ref_fd);
                ref_word = {ref_blue, ref_green, ref_red}; // 24 bits

                // Compare
                if (ref_word !== {dut_word[31:24], dut_word[23:16], dut_word[15:8]}) begin
                    //error_count++;
                    // $display("[TB] @%0t: Pixel %0d mismatch. Reference=%x, DUT=%x",
                    //          $time, i/BYTES_PER_PIXEL,
                    //          ref_word,
                    //          {dut_word[31:24], dut_word[23:16], dut_word[15:8]});
                end else begin
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