
`timescale 1 ns / 1 ns

module vectorsum_tb ();

    localparam string X_NAME = "x.txt";
    localparam string Y_NAME = "y.txt";
    localparam string Z_NAME = "z.txt";
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 10;
    localparam VECTOR_SIZE = 64;
    localparam FIFO_BUFFER_SIZE = 8;
    localparam CLOCK_PERIOD = 10;

    logic clock = 1'b0;
    logic reset = 1'b0;

    logic [DATA_WIDTH-1:0] x_din;
    logic x_wr_en, x_full;
    logic [DATA_WIDTH-1:0] y_din;
    logic y_wr_en, y_full;
    logic [DATA_WIDTH-1:0] z_dout;
    logic z_rd_en, z_empty;

    logic   x_write_done = '0;
    logic   y_write_done = '0;
    logic   z_read_done  = '0;
    integer z_errors     = '0;

    vectorsum_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
    ) vectorsum_top_inst (
        .clock(clock),
        .reset(reset),
        .x_full(x_full),
        .x_wr_en(x_wr_en),
        .x_din(x_din),
        .y_full(y_full),
        .y_wr_en(y_wr_en),
        .y_din(y_din),
        .z_rd_en(z_rd_en),
        .z_empty(z_empty),
        .z_dout(z_dout)
    );

    // clock process
    always begin
        #(CLOCK_PERIOD/2) clock = 1'b1;
        #(CLOCK_PERIOD/2) clock = 1'b0;
    end

    // reset process
    initial begin
        #(CLOCK_PERIOD) reset = 1'b1;
        #(CLOCK_PERIOD) reset = 1'b0;
    end

    initial begin
        time start_time, end_time;

        @(negedge reset);
        @(posedge clock);
        start_time = $time;
        $display("@ %0t: Beginning simulation...", start_time);

        wait(z_read_done);

        end_time = $time;
        $display("@ %0t: Simulation completed.", end_time);
        $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
        $display("Total error count: %0d", z_errors);

        $stop;
    end

    initial begin : x_write
        integer fd, x, count;
        x_din = '0;
        x_wr_en = 1'b0;

        @(negedge reset);
        $display("@ %0t: Loading file %s...", $time, X_NAME);
        
        fd = $fopen(X_NAME, "r");

        x = 0;
        while ( x < VECTOR_SIZE ) begin
            @(negedge clock);
            x_wr_en = 1'b0;
            if (x_full == 1'b0) begin
                count = $fscanf(fd, "%h", x_din);
                x_wr_en = 1'b1;   
                x++;         
            end
        end

        @(posedge clock);
        x_wr_en = 1'b0;
        $fclose(fd);
        x_write_done = 1'b1;
    end

    initial begin : y_write
        integer fd, y, count;
        y_din = '0;
        y_wr_en = 1'b0;
        
        @(negedge reset);
        $display("@ %0t: Loading file %s...", $time, Y_NAME);
        
        fd = $fopen(Y_NAME, "r");

        y = 0;
        while ( y < VECTOR_SIZE ) begin
            @(negedge clock);
            y_wr_en = 1'b0;
            if (y_full == 1'b0) begin
                count = $fscanf(fd, "%h", y_din);
                y_wr_en = 1'b1; 
                y++;           
            end
        end

        @(posedge clock);
        y_wr_en = 1'b0;
        $fclose(fd);
        y_write_done = 1'b1;
    end

    initial begin : z_write
        integer fd, z, count;
        logic [DATA_WIDTH-1:0] z_data_cmp;
        z_rd_en = 1'b0;
        z_data_cmp = '0;

        @(negedge reset);
        @(negedge clock);

        $display("@ %0t: Comparing file %s...", $time, Z_NAME);
        fd = $fopen(Z_NAME, "r");

        z = 0;
        while ( z < VECTOR_SIZE ) begin
            @(negedge clock);            
            z_rd_en = 1'b0;
            if (z_empty == 1'b0) begin
                z_rd_en = 1'b1;
                count = $fscanf(fd, "%h", z_data_cmp);
                if (z_dout != z_data_cmp) begin
                    z_errors++;
                    $display("@ %0t: %s(%0d): ERROR: %h != %h at address 0x%h.", $time, Z_NAME, z+1, z_dout, z_data_cmp, z);
                end
                z++;
            end
        end
        z_rd_en = 1'b0;
        z_read_done = 1'b1;
        $fclose(fd);
    end

endmodule
