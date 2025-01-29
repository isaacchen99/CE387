history clear
project -new /home/icl5712/GitHub/CE387/Lab3/proj_1.prj
add_file -verilog /home/icl5712/GitHub/CE387/Lab3/motion_detect_top.sv
add_file -verilog /home/icl5712/GitHub/CE387/Lab3/highlight.sv
add_file -verilog /home/icl5712/GitHub/CE387/Lab3/grayscale.sv
add_file -verilog /home/icl5712/GitHub/CE387/Lab3/fifo.sv
add_file -verilog /home/icl5712/GitHub/CE387/Lab3/background_subtract.sv
project -run  
timing_corr::q_opt_corr_qii  -impl_name {/home/icl5712/GitHub/CE387/Lab3/proj_1.prj|rev_3}  -impl_result {/home/icl5712/GitHub/CE387/Lab3/rev_3/background_subtract.vqm}  -sdc_verif 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab3/proj_1.prj|rev_3}  -impl_result {/home/icl5712/GitHub/CE387/Lab3/rev_3/background_subtract.vqm}  -load_sta 
timing_corr::pro_qii_corr  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab3/proj_1.prj|rev_3}  -impl_result {/home/icl5712/GitHub/CE387/Lab3/rev_3/background_subtract.vqm}  -load_sta 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab3/proj_1.prj|rev_3}  -impl_result {/home/icl5712/GitHub/CE387/Lab3/rev_3/background_subtract.vqm}  -load_sta 
project -close /home/icl5712/GitHub/CE387/Lab3/proj_1.prj
