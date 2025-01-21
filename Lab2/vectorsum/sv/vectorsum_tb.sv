
`timescale 1 ns / 1 ns

module vectorsum_tb ();

    localparam string X_NAME = "x.txt";
    localparam string Y_NAME = "y.txt";
    localparam string Z_NAME = "z.txt";
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 10;
    localparam VECTOR_SIZE = 64;
    localparam CLOCK_PERIOD = 10;

    logic clock = 1'b0;
    logic reset = 1'b0;
    logic start = 1'b0;
    logic done;

    logic [DATA_WIDTH-1:0] x_din;
    logic [ADDR_WIDTH-1:0] x_wr_addr;
    logic x_wr_en;
    logic [DATA_WIDTH-1:0] y_din;
    logic [ADDR_WIDTH-1:0] y_wr_addr;
    logic y_wr_en;
    logic [DATA_WIDTH-1:0] z_dout;
    logic [ADDR_WIDTH-1:0] z_rd_addr;

    logic   x_write_done = '0;
    logic   y_write_done = '0;
    logic   z_read_done  = '0;
    integer z_errors     = '0;

    vectorsum_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .VECTOR_SIZE(VECTOR_SIZE)
    ) vectorsum_top_inst (
        .clock(clock),
        .reset(reset),
        .start(start),
        .done(done),
        .x_wr_addr(x_wr_addr),
        .x_wr_en(x_wr_en),
        .x_din(x_din),
        .y_wr_addr(y_wr_addr),
        .y_wr_en(y_wr_en),
        .y_din(y_din),
        .z_rd_addr(z_rd_addr),
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
        wait(x_write_done && y_write_done);
        @(posedge clock);
        start_time = $time;
        $display("@ %0t: Beginning simulation...", start_time);

        @(posedge clock);
        #(CLOCK_PERIOD) start = 1'b1;
        #(CLOCK_PERIOD) start = 1'b0;
        wait(done);

        end_time = $time;
        $display("@ %0t: Simulation completed.", end_time);
        wait(z_read_done);
        $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
        $display("Total error count: %0d", z_errors);

        $stop;
    end

    initial begin : x_write
        integer fd, x, count;
        x_wr_addr = '0;
        x_wr_en = 1'b0;

        @(negedge reset);
        $display("@ %0t: Loading file %s...", $time, X_NAME);
        
        fd = $fopen(X_NAME, "r");

        for (x = 0; x < VECTOR_SIZE; x++) begin
            @(posedge clock);
            count = $fscanf(fd, "%h", x_din);
            x_wr_addr = x;
            x_wr_en = 1'b1;
        end

        @(posedge clock);
        x_wr_en = 1'b0;
        $fclose(fd);
        x_write_done = 1'b1;
    end

    initial begin : y_write
        integer fd, y, count;
        y_wr_addr = '0;
        y_wr_en = 1'b0;
        
        @(negedge reset);
        $display("@ %0t: Loading file %s...", $time, Y_NAME);
        
        fd = $fopen(Y_NAME, "r");

        for (y = 0; y < VECTOR_SIZE; y++) begin
            @(posedge clock);
            count = $fscanf(fd, "%h", y_din);
            y_wr_addr = y;
            y_wr_en = 1'b1;
        end

        @(posedge clock);
        y_wr_en = 1'b0;
        $fclose(fd);
        y_write_done = 1'b1;
    end

    initial begin : z_write
        integer fd, z, count;
        logic [DATA_WIDTH-1:0] z_data_cmp, z_data_read;
        z_rd_addr = '0;

        @(negedge reset);
        wait(done);
        @(negedge clock);

        $display("@ %0t: Comparing file %s...", $time, Z_NAME);
        
        fd = $fopen(Z_NAME, "r");

        for (z = 0; z < VECTOR_SIZE; z++) begin
            @(negedge clock);
            z_rd_addr = z;
            @(negedge clock);
            count = $fscanf(fd, "%h", z_data_cmp);
            z_data_read = z_dout;
            if (z_data_read != z_data_cmp) begin
                z_errors++;
                $display("@ %0t: %s(%0d): ERROR: %h != %h at address 0x%h.", $time, Z_NAME, z+1, z_data_read, z_data_cmp, z);
            end
            @(posedge clock);
        end
        $fclose(fd);
        z_read_done = 1'b1;
    end

endmodule
