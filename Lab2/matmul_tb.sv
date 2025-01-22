module matmul_tb ();
  localparam CLOCK_PERIOD = 10;
  
  localparam string A_NAME = "a.txt";
  localparam string B_NAME = "b.txt";
  localparam string C_NAME = "c.txt";

  localparam DATA_WIDTH = 32;
  localparam ADDR_WIDTH = 6;
  localparam N = 8;
  localparam VECTOR_SIZE = N * N;
  localparam LOG2_N = 3;

  logic clock = 1'b0;
  logic reset = 1'b0;
  logic start = 1'b0;
  logic done;

  logic a_wr_en;
  logic [ADDR_WIDTH-1:0] a_wr_addr;
  logic [DATA_WIDTH-1:0] a_din;

  logic b_wr_en;
  logic [ADDR_WIDTH-1:0] b_wr_addr;
  logic [DATA_WIDTH-1:0] b_din;

  logic [ADDR_WIDTH-1:0] c_rd_addr;
  logic [DATA_WIDTH-1:0] c_dout;

  logic   a_write_done = '0;
  logic   b_write_done = '0;
  logic   c_read_done  = '0;
  integer c_errors     = '0;

  matmul_top #(
    .N(N),
    .LOG2_N(LOG2_N),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) matmul_top_uut (
    .clock(clock),
    .reset(reset),
    .start(start),
    .done(done),
    .a_wr_en(a_wr_en),
    .a_wr_addr(a_wr_addr),
    .a_din(a_din),
    .b_wr_en(b_wr_en),
    .b_wr_addr(b_wr_addr),
    .b_din(b_din),
    .c_rd_addr(c_rd_addr),
    .c_dout(c_dout)
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

  // initialize bram a process
  initial begin : a_write
    integer fd, a, count;
    a_wr_addr = '0;
    a_wr_en = 1'b0;

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, A_NAME);
    
    fd = $fopen(A_NAME, "r");

    for (a = 0; a < N * N; a++) begin
      @(posedge clock);
      count = $fscanf(fd, "%h", a_din);
      a_wr_addr = a;
      a_wr_en = 1'b1;
    end

    @(posedge clock);
    a_wr_en = 1'b0;
    $fclose(fd);
    a_write_done = 1'b1;
  end

  // initialize bram b process
  initial begin : b_write
    integer fd, b, count;
    b_wr_addr = '0;
    b_wr_en = 1'b0;

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, B_NAME);
    
    fd = $fopen(B_NAME, "r");

    for (b = 0; b < N * N; b++) begin
      @(posedge clock);
      count = $fscanf(fd, "%h", b_din);
      b_wr_addr = b;
      b_wr_en = 1'b1;
    end

    @(posedge clock);
    b_wr_en = 1'b0;
    $fclose(fd);
    b_write_done = 1'b1;
  end


  // initialize bram c and compare results once simulation done.
  initial begin : c_write_and_compare
    integer fd, c, count;
    logic [DATA_WIDTH-1:0] c_data_cmp, c_data_read;
    c_rd_addr = '0;

    @(negedge reset);
    wait(done);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, C_NAME);
    
    fd = $fopen(C_NAME, "r");

    for (c = 0; c < VECTOR_SIZE; c++) begin
        @(negedge clock);
        c_rd_addr = c;
        @(negedge clock);
        count = $fscanf(fd, "%h", c_data_cmp);
        c_data_read = c_dout;
        if (c_data_read != c_data_cmp) begin
            c_errors++;
            $display("@ %0t: %s(%0d): ERROR: %h != %h at address 0x%h.", $time, C_NAME, c+1, c_data_read, c_data_cmp, c);
        end
        @(posedge clock);
    end
    $fclose(fd);
    c_read_done = 1'b1;
  end

  // simulation process
  initial begin
    time start_time, end_time;

    @(negedge reset);
    wait(a_write_done && b_write_done);
    @(posedge clock);
    start_time = $time;
    $display("@ %0t: Beginning simulation...", start_time);

    @(posedge clock);
    #(CLOCK_PERIOD) start = 1'b1;
    #(CLOCK_PERIOD)
    #(CLOCK_PERIOD)
    #(CLOCK_PERIOD) start = 1'b0;
    wait(done);

    end_time = $time;
    $display("@ %0t: Simulation completed.", end_time);
    wait(c_read_done);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    $display("Total error count: %0d", c_errors);

    $stop;
  end

endmodule