open_project [file join [pwd] project mb_reference.xpr]
open_bd_design [get_files */mb_system.bd]
set imem [file normalize [file join [pwd] software imem.mem]]
set dmem [file normalize [file join [pwd] software dmem.mem]]
set_property -dict [list CONFIG.Write_Depth_A {8192} CONFIG.Load_Init_File {true} CONFIG.Coe_File [file normalize [file join [pwd] software imem.coe]]] [get_bd_cells ilmb_bram]
set_property -dict [list CONFIG.Write_Depth_A {8192} CONFIG.Load_Init_File {true} CONFIG.Coe_File [file normalize [file join [pwd] software dmem.coe]]] [get_bd_cells dlmb_bram]
save_bd_design
generate_target all [get_files */mb_system.bd]
close_project
exit
