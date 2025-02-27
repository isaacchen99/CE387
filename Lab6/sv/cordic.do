# Set simulation time unit
setenv LMC_TIMEUNIT -9

# Create and map work library
vlib work
vmap work work

# Compile sources
vlog -work work "fifo.sv"
vlog -work work "cordic_stage.sv"
vlog -work work "cordic.sv"
vlog -work work "cordic_top.sv"
vlog -work work "cordic_tb.sv"

# Simulate the testbench
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.cordic_tb

# Add signals to waveform
add wave -noupdate -group TOP -radix binary *
add wave -noupdate -group DUT -radix binary /cordic_tb/dut/*
# add wave -noupdate -group DUT -radix binary /cordic_tb/dut/cordic_inst/*
add wave -noupdate -group DUT -radix binary /cordic_tb/dut/cordic_inst/x_pipe
add wave -noupdate -group DUT -radix binary /cordic_tb/dut/cordic_inst/y_pipe
add wave -noupdate -group DUT -radix binary /cordic_tb/dut/cordic_inst/z_pipe

# Run the simulation
run -all