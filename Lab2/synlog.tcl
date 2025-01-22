history clear
add_file -verilog /home/icl5712/GitHub/CE387/Lab2/matmul_top.sv
add_file -verilog ./matmul.sv
add_file -verilog ./bram.sv
project -run  
timing_corr::q_opt_corr_qii  -impl_name {/home/icl5712/GitHub/CE387/Lab2/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab2/rev_1/bram.vqm}  -sdc_verif 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab2/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab2/rev_1/bram.vqm}  -load_sta 
timing_corr::pro_qii_corr  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab2/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab2/rev_1/bram.vqm}  -load_sta 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab2/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab2/rev_1/bram.vqm}  -load_sta 
timing_corr::q_opt_corr_qii  -impl_name {/home/icl5712/GitHub/CE387/Lab2/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab2/rev_1/bram.vqm}  -sdc_verif 
timing_corr::q_correlate_db_qii  -paths_per 1  -qor 1  -sdc_verif  -impl_name {/home/icl5712/GitHub/CE387/Lab2/proj_1.prj|rev_1}  -impl_result {/home/icl5712/GitHub/CE387/Lab2/rev_1/bram.vqm}  -load_sta 
text_select 285 1 301 1
text_select 577 79 580 88
project -close /home/icl5712/GitHub/CE387/Lab2/proj_1.prj
