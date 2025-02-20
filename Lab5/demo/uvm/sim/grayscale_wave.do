

#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/grayscale_inst
add wave -noupdate -group my_uvm_tb/grayscale_inst -radix hexadecimal /my_uvm_tb/grayscale_inst/*

add wave -noupdate -group my_uvm_tb/grayscale_inst/grayscale_inst
add wave -noupdate -group my_uvm_tb/grayscale_inst/grayscale_inst -radix hexadecimal /my_uvm_tb/grayscale_inst/grayscale_inst/*

add wave -noupdate -group my_uvm_tb/grayscale_inst/fifo_in_inst
add wave -noupdate -group my_uvm_tb/grayscale_inst/fifo_in_inst -radix hexadecimal /my_uvm_tb/grayscale_inst/fifo_in_inst/*

add wave -noupdate -group my_uvm_tb/grayscale_inst/fifo_out_inst
add wave -noupdate -group my_uvm_tb/grayscale_inst/fifo_out_inst -radix hexadecimal /my_uvm_tb/grayscale_inst/fifo_out_inst/*

