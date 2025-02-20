import uvm_pkg::*;

//---------------------------------------------------------------------
// Monitor: Captures DUT output from output FIFO and sends transactions 
// to the scoreboard
//---------------------------------------------------------------------
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    // Analysis port to send DUT output transactions
    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int out_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Retrieve the virtual interface handle
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name(
            .scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new("mon_ap_output", this);

        // Open an output file to log DUT output (as ASCII)
        out_file = $fopen("output_result.txt", "w");
        if (!out_file) begin
            `uvm_fatal("MON_OUT_BUILD", "Failed to open output_result.txt");
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out;
        byte actual_byte;

        // Wait for reset to de-assert
        @(posedge vif.reset);
        @(negedge vif.reset);

        // Ensure the read enable is initially de-asserted.
        vif.out_fifo_rd_en = 1'b0;

        forever begin
            // On every negative edge, check if there is output data.
            @(negedge vif.clk) begin
                if (vif.out_fifo_empty == 1'b0) begin
                    // Assert read enable so that the DUT outputs valid data.
                    vif.out_fifo_rd_en = 1'b1;
                end else begin
                    vif.out_fifo_rd_en = 1'b0;
                end
            end

            // Wait a cycle and then capture the data if read enable was asserted.
            @(negedge vif.clk);
            if (vif.out_fifo_rd_en == 1'b1) begin
                actual_byte = vif.out_fifo_dout;
                // Write the output byte as a character to the output file.
                $fwrite(out_file, "%c", actual_byte);

                // Create a transaction carrying the actual output data.
                tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));
                tx_out.data_byte = actual_byte;
                mon_ap_output.write(tx_out);
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", "Closing file output_result.txt...", UVM_LOW);
        $fclose(out_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output

import uvm_pkg::*;

//---------------------------------------------------------------------
// Monitor: Reads expected output from test_output.txt and sends 
// transactions to the scoreboard for comparison
//---------------------------------------------------------------------
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int cmp_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Retrieve the virtual interface handle
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name(
            .scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new("mon_ap_compare", this);

        // Open the expected output file (test_output.txt) in read mode.
        cmp_file = $fopen("../sv/test_output.txt", "r");
        if (!cmp_file) begin
            `uvm_fatal("MON_CMP_BUILD", "Failed to open file test_output.txt");
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_cmp;
        byte expected_byte;
        int read_val;

        // Raise an objection to keep the simulation running.
        phase.raise_objection(this);

        // Wait for reset de-assertion.
        @(posedge vif.reset);
        @(negedge vif.reset);

        forever begin
            @(negedge vif.clk);
            if (vif.out_fifo_empty == 1'b0) begin
                read_val = $fgetc(cmp_file);
                if (read_val == -1) begin
                    `uvm_info("MON_CMP", "Reached end of test_output.txt. Ending monitor run_phase gracefully.", UVM_LOW);
                    break;
                end
                expected_byte = read_val[7:0];
                tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));
                tx_cmp.expected_char = expected_byte;
                mon_ap_compare.write(tx_cmp);
            end
        end

        // Drop the objection to indicate this monitor is done.
        phase.drop_objection(this);
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", "Closing file test_output.txt...", UVM_LOW);
        $fclose(cmp_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare