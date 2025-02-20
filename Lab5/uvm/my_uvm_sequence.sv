import uvm_pkg::*;

//---------------------------------------------------------------------
// Sequence: Reads input.pcap and test_output.txt concurrently,
// creating one transaction per byte with both the input data and 
// its expected output (ASCII).
//---------------------------------------------------------------------
class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int in_file, exp_file;
        int data, exp;
        int byte_count = 0;

        //`uvm_info("SEQ", "Starting sequence: Loading files input.pcap and test_output.txt...", UVM_LOW);

        // Open the binary input file.
        in_file = $fopen("../sv/input.pcap", "rb");
        if (in_file == 0) begin
            `uvm_fatal("SEQ", "Failed to open file input.pcap.");
        end
        //`uvm_info("SEQ", "Loaded input.pcap.", UVM_LOW);

        // Open the expected output text file.
        exp_file = $fopen("../sv/test_output.txt", "r");
        if (exp_file == 0) begin
            `uvm_fatal("SEQ", "Failed to open file test_output.txt.");
        end
        //`uvm_info("SEQ", "Loaded reference file test_output.txt.", UVM_LOW);

        // Read each byte from the input file.
        while ((data = $fgetc(in_file)) != -1) begin
            tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
            tx.data_byte = data[7:0];

            //`uvm_info("SEQ", "Begun sequence.", UVM_LOW);

            // Read the corresponding expected ASCII character.
            exp = $fgetc(exp_file);
            if (exp == -1) begin
                //`uvm_info("SEQ", "Expected output file has no more data. Ending sequence gracefully.", UVM_LOW);
                break;
            end
            tx.expected_char = exp[7:0];

            //`uvm_info("SEQ", "Read in expected corresponding ASCII char.", UVM_LOW);

            start_item(tx);
            //`uvm_info("SEQ", "Started transaction.", UVM_LOW);
            finish_item(tx);
            //`uvm_info("SEQ", "Finished transaction.", UVM_LOW);

            byte_count++;
            if ((byte_count % 10) == 0) begin
                `uvm_info("SEQ", $sformatf("Processed %0d/3983 bytes so far.", byte_count), UVM_LOW);
            end
        end

        `uvm_info("SEQ", $sformatf("Sequence completed. Total bytes processed: %0d", byte_count), UVM_LOW);
        $fclose(in_file);
        $fclose(exp_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;