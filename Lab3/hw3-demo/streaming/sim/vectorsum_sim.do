
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/vectorsum.sv"
vlog -work work "../sv/vectorsum_top.sv"
vlog -work work "../sv/vectorsum_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.vectorsum_tb -wlf vectorsum.wlf

do vectorsum_wave.do

run -all

