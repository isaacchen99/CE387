setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# Cordic architecture (files are located in ../sv/)
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/cordic_stage.sv"
vlog -work work "../sv/cordic.sv"
vlog -work work "../sv/cordic_top.sv"

# UVM library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# UVM package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# Start UVM simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/

# Load waveform configuration (adjust file name if needed)
do cordic_wave.do

run -all
#quit;