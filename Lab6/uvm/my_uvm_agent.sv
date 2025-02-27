import uvm_pkg::*;

class my_uvm_agent extends uvm_agent;
  `uvm_component_utils(my_uvm_agent)

  // Analysis port to forward monitored transactions to the environment
  uvm_analysis_port#(my_uvm_transaction) agent_ap;

  // Components in the agent
  my_uvm_sequencer seqr;
  my_uvm_driver    drvr;
  my_uvm_monitor   mon;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  // Build phase: instantiate sub-components and the agent's analysis port
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent_ap = new("agent_ap", this);

    // Instantiate sequencer, driver, and monitor
    seqr = my_uvm_sequencer::type_id::create("seqr", this);
    drvr = my_uvm_driver::type_id::create("drvr", this);
    mon  = my_uvm_monitor::type_id::create("mon", this);
  endfunction: build_phase

  // Connect phase: wire up the sequencer to the driver and connect the monitor analysis port
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect the sequencer's item export to the driver's item port.
    drvr.seq_item_port.connect(seqr.seq_item_export);
    // Forward monitor transactions to the agent's analysis port.
    mon.mon_ap.connect(agent_ap);
  endfunction: connect_phase

endclass: my_uvm_agent