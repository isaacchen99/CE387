setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# compile
vlog -work work "bram.sv"
vlog -work work "matmul.sv"
vlog -work work "matmul_top.sv"
vlog -work work "matmul_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.matmul_tb -wlf matmul_tb.wlf

# wave
add wave -noupdate -group TOP -radix binary matmul_tb/*

run -all