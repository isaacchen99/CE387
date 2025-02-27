import uvm_pkg::*;

class my_uvm_transaction extends uvm_sequence_item;
  rand logic [15:0] angle;

  logic [15:0] cos_data;
  logic [15:0] sin_data;

  function new(string name = "my_uvm_transaction");
    super.new(name);
  endfunction: new

  `uvm_object_utils_begin(my_uvm_transaction)
    `uvm_field_int(angle,   UVM_ALL_ON)
    `uvm_field_int(cos_data, UVM_ALL_ON)
    `uvm_field_int(sin_data, UVM_ALL_ON)
  `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
  `uvm_object_utils(my_uvm_sequence)

  function new(string name = "my_uvm_sequence");
    super.new(name);
  endfunction: new

  task body();
    my_uvm_transaction tx;
    
    // Test 1: Angle = 16'h3243 (original test)
    tx = my_uvm_transaction::type_id::create(.name("tx1"), .contxt(get_full_name()));
    tx.angle = 16'h3243;
    start_item(tx);
    finish_item(tx);
    
    // Wait period (driver already provides a processing delay)
    #50;
    
    // Test 2: Angle = 16'h0000 (zero angle)
    tx = my_uvm_transaction::type_id::create(.name("tx2"), .contxt(get_full_name()));
    tx.angle = 16'h0000;
    start_item(tx);
    finish_item(tx);
    
    #50;
    
    // Test 3: Angle = 16'hDE7D (-30° in fixed point)
    tx = my_uvm_transaction::type_id::create(.name("tx3"), .contxt(get_full_name()));
    tx.angle = 16'hDE7D;
    start_item(tx);
    finish_item(tx);
  endtask: body

endclass: my_uvm_sequence


typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
