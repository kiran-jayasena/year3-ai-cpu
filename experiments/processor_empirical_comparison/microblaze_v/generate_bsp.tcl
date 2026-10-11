set xsa [file normalize [file join [pwd] project mb_system_fixed.xsa]]
set out [file normalize [file join [pwd] hsi_bsp]]
hsi open_hw_design $xsa
hsi create_sw_design -proc microblaze_0 -os standalone -name standalone_microblaze_0
hsi generate_bsp -dir $out
hsi close_sw_design [hsi current_sw_design]
hsi close_hw_design [hsi current_hw_design]
exit
