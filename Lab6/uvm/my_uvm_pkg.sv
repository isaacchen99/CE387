package my_uvm_package;

  import uvm_pkg::*;

  // UVM macros
  `include "uvm_macros.svh"

  // Global definitions
  `include "my_uvm_globals.sv"

  // Sequence, Monitor, Driver, Agent, Scoreboard, Config, Env, and Test
  `include "my_uvm_sequence.sv"
  `include "my_uvm_monitor.sv"
  `include "my_uvm_driver.sv"
  `include "my_uvm_agent.sv"
  `include "my_uvm_scoreboard.sv"
  `include "my_uvm_config.sv"
  `include "my_uvm_env.sv"
  `include "my_uvm_test.sv"

endpackage