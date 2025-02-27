import uvm_pkg::*;

class my_uvm_env extends uvm_env;
    `uvm_component_utils(my_uvm_env)

    my_uvm_agent   agent;
    my_uvm_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = my_uvm_agent::type_id::create("agent", this);
        sb    = my_uvm_scoreboard::type_id::create("sb", this);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect the agent's analysis port to the scoreboard's analysis export.
        agent.agent_ap.connect(sb.analysis_export);
    endfunction: connect_phase

endclass: my_uvm_env