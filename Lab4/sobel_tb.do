setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# compile
vlog -work work "fifo.sv"
vlog -work work "grayscale.sv"
vlog -work work "sobel.sv"
vlog -work work "sobel_top.sv"
vlog -work work "sobel_tb.sv"

# simulate
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.sobel_tb -wlf sobel_tb.wlf

# wave
add wave -noupdate -group TOP -radix binary sobel_tb/*

# run simulation
run -all