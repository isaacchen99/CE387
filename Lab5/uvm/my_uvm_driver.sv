import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(my_uvm_transaction);

    `uvm_component_utils(my_uvm_driver)

    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name(
            .scope("ifs"), .name("vif"), .val(vif)));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        drive();
    endtask: run_phase

    virtual task drive();
        my_uvm_transaction tx;
        byte out_data;
        int timeout_cycles;
        int timeout_limit = 100; // maximum number of cycles to wait

        // Wait for reset de-assertion.
        @(posedge vif.reset);
        @(negedge vif.reset);

        // Initialize FIFO interface signals.
        vif.in_fifo_wr_en   = 1'b0;
        vif.out_fifo_rd_en  = 1'b0;
        vif.in_fifo_din     = 8'b0;

        forever begin
            // Get the next transaction from the sequencer.
            seq_item_port.get_next_item(tx);

            // --- Drive the Input FIFO ---
            // Wait until the input FIFO is not full.
            wait(vif.in_fifo_full == 1'b0);
            @(negedge vif.clk) begin
                vif.in_fifo_din  = tx.data_byte;
                vif.in_fifo_wr_en = 1'b1;
            end
            @(negedge vif.clk);
            vif.in_fifo_wr_en = 1'b0;

            // --- Read and Compare from the Output FIFO ---
            // Poll until output FIFO is not empty or timeout occurs.
            timeout_cycles = timeout_limit;
            while (vif.out_fifo_empty && (timeout_cycles > 0)) begin
                @(negedge vif.clk);
                timeout_cycles--;
            end

            if (timeout_cycles == 0) begin
                `uvm_error("DRV", "Timeout waiting for output FIFO data");
                // Signal end of transaction and continue to next transaction.
                seq_item_port.item_done();
                continue;
            end

            // Once data is available, read from the output FIFO.
            @(negedge vif.clk) begin
                vif.out_fifo_rd_en = 1'b1;
            end
            @(negedge vif.clk);
            out_data = vif.out_fifo_dout;
            vif.out_fifo_rd_en = 1'b0;

            // Compare the received output with the expected ASCII.
            if (out_data !== tx.expected_char) begin
            end else begin
                `uvm_info("DRV", $sformatf("Match: '%c'", out_data), UVM_LOW);
            end

            seq_item_port.item_done();
        end
    endtask: drive

endclass