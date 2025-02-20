import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

    // Instantiate the updated UVM interface
    my_uvm_if vif();

    // Instantiate the UDP Parser top-level module with matching port names
    udp_parser_top udp_parser_top_inst (
        .clk           (vif.clk),
        .reset         (vif.reset),
        .in_fifo_wr_en (vif.in_fifo_wr_en),
        .in_fifo_din   (vif.in_fifo_din),
        .in_fifo_full  (vif.in_fifo_full),
        .out_fifo_rd_en(vif.out_fifo_rd_en),
        .out_fifo_dout (vif.out_fifo_dout),
        .out_fifo_empty(vif.out_fifo_empty),
        .out_fifo_full (vif.out_fifo_full)
    );

    // Provide the interface to the UVM components and run the test
    initial begin
        // Store the virtual interface so it can be retrieved by drivers & monitors
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));
        // Run the test
        run_test("my_uvm_test");        
    end

    // Reset sequence
    initial begin
        vif.clk   <= 1'b1;
        vif.reset <= 1'b0;
        @(posedge vif.clk);
        vif.reset <= 1'b1;
        @(posedge vif.clk);
        vif.reset <= 1'b0;
    end

    // Clock generation (Assuming a 10 ns clock period)
    localparam CLOCK_PERIOD = 10;
    always begin
        #(CLOCK_PERIOD/2) vif.clk = ~vif.clk;
    end

endmodule