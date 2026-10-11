open_project [file join [pwd] project mb_reference.xpr]
set_property platform.name mb_reference [current_project]
set_property platform.board_id xc7a35tcpg236-1 [current_project]
set_property platform.default_output_type {sd_card} [current_project]
set_property platform.design_intent.embedded {true} [current_project]
set bd [get_files */mb_system.bd]
generate_target all $bd
write_hw_platform -fixed -force [file join [pwd] project mb_system_fixed.xsa]
close_project
exit
