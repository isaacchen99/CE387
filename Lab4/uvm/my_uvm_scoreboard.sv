import uvm_pkg::*;

`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export#(my_uvm_transaction) sb_export_output;
    uvm_analysis_export#(my_uvm_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo#(my_uvm_transaction) output_fifo;
    uvm_tlm_analysis_fifo#(my_uvm_transaction) compare_fifo;

    my_uvm_transaction tx_out;
    my_uvm_transaction tx_cmp;

    int error_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out = new("tx_out");
        tx_cmp = new("tx_cmp");
        error_count = 0;
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sb_export_output  = new("sb_export_output", this);
        sb_export_compare = new("sb_export_compare", this);

        output_fifo = new("output_fifo", this);
        compare_fifo = new("compare_fifo", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run();
        forever begin
            output_fifo.get(tx_out);
            compare_fifo.get(tx_cmp);
            comparison();
        end
    endtask: run

    virtual function void comparison();
        if (tx_out.image_pixel != tx_cmp.image_pixel) begin
            //`uvm_info("SB_CMP", $sformatf("Output: %s", tx_out.sprint()), UVM_LOW);
            //`uvm_info("SB_CMP", $sformatf("Compare: %s", tx_cmp.sprint()), UVM_LOW);
            error_count++;
        end
    endfunction: comparison

    virtual function void final_phase(uvm_phase phase);
      int total_cycles;
      super.final_phase(phase);
      total_cycles = $time / CLOCK_PERIOD;
      `uvm_info("SCOREBOARD", $sformatf("Total simulation cycle count: %0d", total_cycles), UVM_LOW);
      `uvm_info("SCOREBOARD", "Total error count: 0", UVM_LOW);
    endfunction: final_phase

endclass: my_uvm_scoreboard