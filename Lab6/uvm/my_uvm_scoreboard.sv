import uvm_pkg::*;

class my_uvm_scoreboard extends uvm_component;
  `uvm_component_utils(my_uvm_scoreboard)

  // Analysis export to receive transactions from the agent/monitor
  uvm_analysis_imp#(my_uvm_transaction, my_uvm_scoreboard) analysis_export;

  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction: new

  // Function to calculate expected cosine and sine values based on the input angle
  function void calc_expected(logic [15:0] angle,
                              output logic [15:0] exp_cos,
                              output logic [15:0] exp_sin);
    if (angle == 16'h3243) begin  // 45°: 0.7854 rad, 0.7071*16384 ≈ 11585
      exp_cos = 16'd11585;
      exp_sin = 16'd11585;
    end
    else if (angle == 16'h0000) begin  // 0°: cos=1.0, sin=0.0 → 16384 and 0
      exp_cos = 16'd16384;
      exp_sin = 16'd0;
    end
    else if (angle == 16'hDE7D) begin  // -30°: cos(30°)=0.8660, sin(-30°)=-0.5
      exp_cos = 16'd14189;  // 0.8660 * 16384 ≈ 14189
      exp_sin = -16'd8192;  // -0.5 * 16384 = -8192
    end
    else begin
      exp_cos = 16'd0;
      exp_sin = 16'd0;
    end
  endfunction: calc_expected

  // Write method is called whenever a transaction is received via the analysis port.
  virtual function void write(my_uvm_transaction tx);
    logic [15:0] exp_cos;
    logic [15:0] exp_sin;

    // Calculate expected outputs based on the input angle.
    calc_expected(tx.angle, exp_cos, exp_sin);

    // Compare the captured cosine value with expected value.
    if (tx.cos_data !== exp_cos) begin
      `uvm_error("SCOREBOARD", $sformatf("Cosine mismatch for angle 0x%h: expected %0d, got %0d",
                                          tx.angle, exp_cos, tx.cos_data));
    end
    else begin
      `uvm_info("SCOREBOARD", $sformatf("Cosine match for angle 0x%h: %0d", tx.angle, tx.cos_data), UVM_LOW);
    end

    // Compare the captured sine value with expected value.
    if (tx.sin_data !== exp_sin) begin
      `uvm_error("SCOREBOARD", $sformatf("Sine mismatch for angle 0x%h: expected %0d, got %0d",
                                          tx.angle, exp_sin, tx.sin_data));
    end
    else begin
      `uvm_info("SCOREBOARD", $sformatf("Sine match for angle 0x%h: %0d", tx.angle, tx.sin_data), UVM_LOW);
    end
  endfunction: write

endclass: my_uvm_scoreboard