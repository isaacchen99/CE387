import uvm_pkg::*;

class my_uvm_monitor extends uvm_monitor;
  `uvm_component_utils(my_uvm_monitor)

  // Analysis port for sending captured transactions
  uvm_analysis_port#(my_uvm_transaction) mon_ap;

  // Virtual interface handle
  virtual my_uvm_if vif;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    mon_ap = new("mon_ap", this);
  endfunction: new

  // Build phase: retrieve the virtual interface pointer from the configuration DB
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_uvm_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s", get_full_name()))
  endfunction: build_phase

  // Run phase: monitor DUT output events and capture transactions
  virtual task run_phase(uvm_phase phase);
    my_uvm_transaction mon_tx;
    // Wait for the system to come out of reset
    @(negedge vif.reset);
    forever begin
      // Wait for a rising edge of clock to check for events
      @(posedge vif.clock);
      // Check for cosine read event (cos_rd_en pulse)
      if (vif.cos_rd_en) begin
        mon_tx = my_uvm_transaction::type_id::create(.name("mon_tx"), .contxt(get_full_name()));
        // Capture the cosine data when the read is active
        mon_tx.cos_data = vif.cos_data_out;
        // Now wait for the sine read enable pulse to capture sine data
        wait(vif.sin_rd_en == 1);
        // A short delay to allow data to stabilize
        @(posedge vif.clock);
        mon_tx.sin_data = vif.sin_data_out;
        // Send the transaction via the analysis port
        mon_ap.write(mon_tx);
      end
    end
  endtask: run_phase

endclass: my_uvm_monitor