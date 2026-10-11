create_project pico_reference [file join [pwd] synth_project] -part xc7a35tcpg236-1 -force
add_files [file normalize [file join [pwd] .. picorv32_upstream picorv32.v]]
add_files [file normalize [file join [pwd] pico_top.sv]]
set_property top pico_top [current_fileset]
set xdc [file normalize [file join [pwd] pico_clock.xdc]]
set f [open $xdc w]; puts $f {create_clock -period 10.752 [get_ports clk]}; close $f
add_files -fileset constrs_1 $xdc
update_compile_order -fileset sources_1
synth_design -top pico_top -part xc7a35tcpg236-1
report_utilization -file [file join [pwd] pico_utilization.rpt]
report_timing_summary -file [file join [pwd] pico_timing.rpt]
close_project
exit
