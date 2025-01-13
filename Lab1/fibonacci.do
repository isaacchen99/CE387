setenv LMC_TIMEUNIT -9
vlib work
vmap work work


# compile
vlog -work work "fibonacci_tb.sv"
vlog -work work "fibonacci.sv"


vsim -classdebug -voptargs=+acc +notimingchecks -L work work.fibonacci_tb -wlf fibonacci_tb.wlf


# wave
add wave -noupdate -group TOP -radix binary fibonacci_tb/*

run -all
