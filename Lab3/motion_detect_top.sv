module motion_detect_top (
    input  logic        clk,
    input  logic        reset,

    input  logic        bg_wr_en,
    input  logic [31:0] bg_din,
    output logic        bg_full,

    input  logic        frame_wr_en,
    input  logic [31:0] frame_din,
    output logic        frame_full,

    input  logic        frame_wr_en2,
    input  logic [31:0] frame_din2,
    output logic        frame_full2,

    input  logic        final_rd_en,
    output logic [31:0] final_dout,
    output logic        final_empty
);

    logic [31:0] bg_fifo_dout;
    logic        bg_fifo_empty;
    logic        bg_fifo_rd_en;

    fifo #(
        .FIFO_DATA_WIDTH (32),
        .FIFO_BUFFER_SIZE(32)
    ) bg_in_fifo (
        .reset   (reset),
        .rd_clk  (clk),
        .wr_clk  (clk),

        .wr_en   (bg_wr_en),
        .din     (bg_din),
        .full    (bg_full),

        .rd_en   (bg_fifo_rd_en),
        .dout    (bg_fifo_dout),
        .empty   (bg_fifo_empty)
    );

    logic             bg_gray_wr_en;
    logic [7:0]       bg_gray_dout;
    logic             bg_gray_fifo_out_full;
    grayscale bg_grayscale (
        .clk           (clk),
        .reset         (reset),

        .read_enable   (bg_fifo_rd_en),
        .data_in       (bg_fifo_dout),
        .fifo_in_empty (bg_fifo_empty),

        .write_enable  (bg_gray_wr_en),
        .data_out      (bg_gray_dout),
        .fifo_out_full (bg_gray_fifo_out_full)
    );

    logic [7:0]  bg_gray_fifo_dout;
    logic        bg_gray_fifo_empty;
    logic        bg_gray_fifo_rd_en;
    fifo #(
        .FIFO_DATA_WIDTH (8),
        .FIFO_BUFFER_SIZE(32)
    ) bg_gray_out_fifo (
        .reset   (reset),
        .wr_clk  (clk),
        .rd_clk  (clk),

        .wr_en   (bg_gray_wr_en),
        .din     (bg_gray_dout),
        .full    (bg_gray_fifo_out_full),

        .rd_en   (bg_gray_fifo_rd_en),
        .dout    (bg_gray_fifo_dout),
        .empty   (bg_gray_fifo_empty)
    );

    // fifo for frame -> highlight
    logic [31:0] frame_color_fifo_dout;
    logic        frame_color_fifo_empty;
    logic        frame_color_fifo_rd_en;
    fifo #(
        .FIFO_DATA_WIDTH (32),
        .FIFO_BUFFER_SIZE(32)
    ) frame_color_fifo (
        .reset   (reset),
        .wr_clk  (clk),
        .rd_clk  (clk),

        .wr_en   (frame_wr_en2),
        .din     (frame_din2),
        .full    (frame_full2),
        
        .rd_en   (frame_color_fifo_rd_en),
        .dout    (frame_color_fifo_dout),
        .empty   (frame_color_fifo_empty)
    );

    // fifo for frame -> grayscale
    logic [31:0] frame_fifo_dout;
    logic        frame_fifo_empty;
    logic        frame_fifo_rd_en;
    fifo #(
        .FIFO_DATA_WIDTH (32),
        .FIFO_BUFFER_SIZE(32)
    ) frame_in_fifo (
        .reset   (reset),
        .wr_clk  (clk),
        .rd_clk  (clk),

        .wr_en   (frame_wr_en),
        .din     (frame_din),
        .full    (frame_full),

        .rd_en   (frame_fifo_rd_en),
        .dout    (frame_fifo_dout),
        .empty   (frame_fifo_empty)
    );

    // frame grayscale module
    logic             frame_gray_wr_en;
    logic [7:0]       frame_gray_dout;
    logic             frame_gray_fifo_out_full;
    grayscale frame_grayscale (
        .clk           (clk),
        .reset         (reset),

        .read_enable   (frame_fifo_rd_en),
        .data_in       (frame_fifo_dout),
        .fifo_in_empty (frame_fifo_empty),

        .write_enable  (frame_gray_wr_en),
        .data_out      (frame_gray_dout),
        .fifo_out_full (frame_gray_fifo_out_full)
    );

    // 4) FIFO: grayscale output of Frame (8 bits)
    logic [7:0] frame_gray_fifo_dout;
    logic       frame_gray_fifo_empty;
    logic       frame_gray_fifo_rd_en;
    fifo #(
        .FIFO_DATA_WIDTH (8),
        .FIFO_BUFFER_SIZE(32)
    ) frame_gray_out_fifo (
        .reset   (reset),
        .wr_clk  (clk),
        .rd_clk  (clk),

        .wr_en   (frame_gray_wr_en),
        .din     (frame_gray_dout),
        .full    (frame_gray_fifo_out_full),

        .rd_en   (frame_gray_fifo_rd_en),
        .dout    (frame_gray_fifo_dout),
        .empty   (frame_gray_fifo_empty)
    );

    // 5) Background Subtract
    logic             bg_sub_base_read_en, bg_sub_gray_read_en;
    logic [7:0]       bg_sub_base_din, bg_sub_gray_din, bg_sub_data_out;
    logic             bg_sub_base_fifo_empty, bg_sub_gray_fifo_empty;
    logic             bg_sub_wr_en;
    logic             bg_sub_out_full;
    background_subtract #(
        .THRESHOLD(50)
    ) bg_sub (
        .clk            (clk),
        .reset          (reset),
        // FIFO In (base image = background grayscale)
        .base_read_enable (bg_gray_fifo_rd_en),
        .base_din       (bg_gray_fifo_dout),
        .base_fifo_empty(bg_gray_fifo_empty),
        // FIFO In (gray/current image = frame grayscale)
        .gray_read_enable (frame_gray_fifo_rd_en),
        .gray_din       (frame_gray_fifo_dout),
        .gray_fifo_empty(frame_gray_fifo_empty),
        // FIFO Out (foreground mask)
        .write_enable   (bg_sub_wr_en),
        .data_out       (bg_sub_data_out),
        .fifo_out_full  (bg_sub_out_full)
    );

    // FIFO for the subtract output mask (8 bits)
    logic [7:0]  mask_fifo_dout;
    logic        mask_fifo_empty;
    logic        mask_fifo_rd_en;
    fifo #(
        .FIFO_DATA_WIDTH (8),
        .FIFO_BUFFER_SIZE(32)
    ) subtract_mask_fifo (
        .reset   (reset),
        .wr_clk  (clk),
        .rd_clk  (clk),

        .wr_en   (bg_sub_wr_en),
        .din     (bg_sub_data_out),
        .full    (bg_sub_out_full),

        .rd_en   (mask_fifo_rd_en),
        .dout    (mask_fifo_dout),
        .empty   (mask_fifo_empty)
    );

    // highlight module
    logic             hl_wr_en;
    logic [31:0]      hl_dout;
    logic             hl_out_full;
    highlight hl (
        .clk            (clk),
        .reset          (reset),

        .base_read_enable (frame_color_fifo_rd_en),
        .base_din       (frame_color_fifo_dout),
        .base_fifo_empty(frame_color_fifo_empty),

        .subt_read_enable (mask_fifo_rd_en),
        .subt_din       (mask_fifo_dout),
        .subt_fifo_empty(mask_fifo_empty),

        .write_enable   (hl_wr_en),
        .data_out       (hl_dout),
        .fifo_out_full  (hl_out_full)
    );

    // highlight output
    fifo #(
        .FIFO_DATA_WIDTH (32),
        .FIFO_BUFFER_SIZE(32)
    ) highlight_out_fifo (
        .reset   (reset),
        .wr_clk  (clk),
        .rd_clk  (clk),

        .wr_en   (hl_wr_en),
        .din     (hl_dout),
        .full    (hl_out_full),

        .rd_en   (final_rd_en),
        .dout    (final_dout),
        .empty   (final_empty)
    );

endmodule