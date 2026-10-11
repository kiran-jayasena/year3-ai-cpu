open_project [file join [pwd] project mb_reference.xpr]
set xdc [file join [pwd] microblaze_clock.xdc]
if {![file exists $xdc]} { set f [open $xdc w]; puts $f {create_clock -name sys_clk -period 10.752 [get_ports sys_clk]}; close $f; add_files -fileset constrs_1 $xdc }
set_property top mb_system_wrapper [current_fileset]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
open_run synth_1
report_utilization -file [file join [pwd] synth_utilization.rpt]
report_timing_summary -file [file join [pwd] synth_timing.rpt]
close_project
exit
