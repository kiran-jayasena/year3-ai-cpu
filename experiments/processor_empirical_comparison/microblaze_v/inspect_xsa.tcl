hsi open_hw_design [file normalize [file join [pwd] project mb_system_fixed.xsa]]
set cells [hsi get_cells]
foreach c $cells {
    puts "CELL=$c"
    foreach p {IP_NAME VLNV CORE_NAME NAME IP_TYPE HW_TYPE} {
        catch {puts "  $p=[hsi get_property $p $c]"}
    }
}
puts "DRIVERS=[hsi get_drivers]"
hsi close_hw_design
exit
