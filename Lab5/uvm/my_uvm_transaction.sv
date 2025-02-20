import uvm_pkg::*;

//---------------------------------------------------------------------
// Transaction: Holds an 8-bit data value from the PCAP file and the 
// expected ASCII character (from text_output.txt)
//---------------------------------------------------------------------
class my_uvm_transaction extends uvm_sequence_item;
    // Data to be written into the input FIFO
    logic [7:0] data_byte;
    // Expected output (ASCII character) from the DUT
    byte expected_char;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(data_byte, UVM_ALL_ON)
        `uvm_field_int(expected_char, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction