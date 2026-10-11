open_project [file join [pwd] project mb_reference.xpr]
open_bd_design [get_files */mb_system.bd]
foreach cell {microblaze_0 ilmb_bram_if_cntlr dlmb_bram_if_cntlr ilmb_bram dlmb_bram rst_sys} {
    puts "CELL $cell PINS [get_bd_pins -quiet -of_objects [get_bd_cells $cell]]"
    puts "CELL $cell IFACES [get_bd_intf_pins -quiet -of_objects [get_bd_cells $cell]]"
}
close_project
exit
