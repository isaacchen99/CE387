setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# compile
vlog -work work "fifo.sv"
vlog -work work "grayscale.sv"
vlog -work work "background_subtract.sv"
vlog -work work "highlight.sv"
vlog -work work "motion_detect_top.sv"
vlog -work work "motion_detect_tb.sv"

# simulate
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.motion_detect_tb -wlf motion_detect_tb.wlf

# wave
add wave -noupdate -group TOP -radix binary motion_detect_tb/*

# run simulation
run -all