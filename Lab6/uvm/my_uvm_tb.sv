import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

  // Instantiate the virtual interface
  my_uvm_if vif();

  // Instantiate the DUT using cordic_top (matching our interface signal names)
  cordic_top #(
      .FIFO_DATA_WIDTH(16),
      .FIFO_BUFFER_SIZE(16),
      .NUM_STAGES(16)
  ) dut (
      .clock       (vif.clock),
      .reset       (vif.reset),
      
      .wr_en       (vif.wr_en),
      .data_in     (vif.data_in),
      .full        (vif.full),
      
      .cos_rd_en   (vif.cos_rd_en),
      .cos_data_out(vif.cos_data_out),
      .cos_empty   (vif.cos_empty),
      
      .sin_rd_en   (vif.sin_rd_en),
      .sin_data_out(vif.sin_data_out),
      .sin_empty   (vif.sin_empty)
  );

  // Ensure initial signal values are known
  initial begin
    // Set the control signals to a safe initial state
    vif.wr_en    = 1'b0;
    vif.data_in  = '0;
    vif.cos_rd_en = 1'b0;
    vif.sin_rd_en = 1'b0;
  end

  initial begin
    // Set the virtual interface in the configuration DB so that UVM components can retrieve it.
    uvm_config_db#(virtual my_uvm_if)::set(null, "*", "vif", vif);
    
    // Start the UVM test
    run_test("my_uvm_test");
  end

  // Reset sequence: hold reset high for 5 clock cycles
  initial begin
    vif.clock = 1'b1;
    vif.reset = 1'b1;       // Assert reset initially
    repeat (5) @(posedge vif.clock);
    vif.reset = 1'b0;       // Deassert reset after 5 cycles
  end

  // Clock generation: 10 ns clock period (assumes CLOCK_PERIOD is defined externally)
  always begin
    #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;
  end

endmodule