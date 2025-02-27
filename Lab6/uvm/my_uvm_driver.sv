import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(my_uvm_transaction);
  `uvm_component_utils(my_uvm_driver)

  // Virtual interface handle retrieved via the configuration database
  virtual my_uvm_if vif;

  // Constructor: calls the base class constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  // Build phase: fetch the virtual interface from the configuration DB
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_uvm_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s", get_full_name()));
    end
  endfunction: build_phase

  // Run phase: wait for reset deassertion before processing transactions
  task run_phase(uvm_phase phase);
    my_uvm_transaction tx;
    // Wait until reset is deasserted so that the DUT and FIFOs are properly initialized.
    wait(vif.reset == 0);
    repeat (10) @(posedge vif.clock);
    forever begin
      // Get the next transaction
      seq_item_port.get_next_item(tx);

      // Send the transaction to the DUT
      send_transaction(tx);
      
      // Wait for processing delay and capture output data
      capture_outputs(tx);

      // Mark the transaction as complete
      seq_item_port.item_done();
    end
  endtask: run_phase

  // Task to drive the input FIFO signals with the transaction angle
  task send_transaction(my_uvm_transaction tx);
    // Drive the angle into the DUT on the rising edge of the clock
    @(posedge vif.clock);
    vif.data_in = tx.angle;
    repeat (1) @(posedge vif.clock);
    vif.wr_en   = 1;
    @(posedge vif.clock);
    vif.wr_en   = 0;
  endtask: send_transaction

  // Task to capture cosine and sine data from the DUT after a processing delay
  task capture_outputs(my_uvm_transaction tx);
    // Wait for the DUT to process the transaction (35 clock cycles)
    repeat (35) @(posedge vif.clock);

    // Capture cosine data if available
    if (!vif.cos_empty) begin
      vif.cos_rd_en = 1;
      @(posedge vif.clock);
      tx.cos_data = vif.cos_data_out;
      vif.cos_rd_en = 0;
    end else begin
      tx.cos_data = 'x;
    end

    // Capture sine data if available
    if (!vif.sin_empty) begin
      vif.sin_rd_en = 1;
      @(posedge vif.clock);
      tx.sin_data = vif.sin_data_out;
      vif.sin_rd_en = 0;
    end else begin
      tx.sin_data = 'x;
    end
  endtask: capture_outputs

endclass: my_uvm_driver