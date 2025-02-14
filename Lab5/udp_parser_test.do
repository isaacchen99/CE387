# Set simulation time unit
setenv LMC_TIMEUNIT -9

# Create and map work library
vlib work
vmap work work

# Compile sources
vlog -work work "ctrl_fifo.sv"
vlog -work work "fifo.sv"
vlog -work work "udp_parser.sv"
vlog -work work "udp_parser_top.sv"
vlog -work work "udp_parser_tb.sv"

# Simulate
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.udp_parser_tb -wlf udp_parser_tb.wlf

# Add signals to waveform
add wave -noupdate -group TOP -radix binary udp_parser_tb/*

# Run the simulation
run -all