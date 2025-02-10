history clear
add_file -verilog /home/icl5712/GitHub/CE387/Lab4/sv/sobel_top.sv
project -run  
add_file -verilog ./sobel_top.sv
add_file -verilog ./sobel.sv
add_file -verilog ./grayscale.sv
add_file -verilog ./fifo.sv
project -run  
timing_corr::q_opt_corr_qii  -impl_name {/home/icl5712/GitHub/CE387/Lab4/sv/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab4/sv/rev_1/sobel_top.vqm}  -sdc_verif 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab4/sv/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab4/sv/rev_1/sobel_top.vqm}  -load_sta 
timing_corr::pro_qii_corr  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab4/sv/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab4/sv/rev_1/sobel_top.vqm}  -load_sta 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab4/sv/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab4/sv/rev_1/sobel_top.vqm}  -load_sta 
project -close /home/icl5712/GitHub/CE387/Lab4/sv/proj_1.prj
