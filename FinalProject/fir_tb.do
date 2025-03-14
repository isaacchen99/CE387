setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# compile
vlog -work work "radio_const_pkg.sv"
vlog -work work "fifo.sv"
vlog -work work "fir.sv"
vlog -work work "fir_top.sv"
vlog -work work "fir_tb.sv"

# simulate
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.fir_tb -wlf fir_tb.wlf

# wave
add wave -noupdate -group TOP -radix binary fir_tb/*

# run simulation
run -all
