
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/grayscale_top.sv"
vlog -work work "../sv/grayscale_tb.sv"

vsim -voptargs=+acc +notimingchecks -L work work.grayscale_tb -wlf grayscale_tb.wlf

do grayscale_wave.do

run -all

