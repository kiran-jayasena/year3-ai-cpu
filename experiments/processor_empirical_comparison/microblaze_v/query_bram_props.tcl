open_project [file join [pwd] project mb_reference.xpr]
open_bd_design [get_files */mb_system.bd]
foreach c {ilmb_bram dlmb_bram} {
  puts "CELL=$c"
  foreach p [list_property [get_bd_cells $c]] {
    if {[string match *Init* $p] || [string match *Coe* $p] || [string match *Memory* $p]} { puts "$p=[get_property $p [get_bd_cells $c]]" }
  }
}
close_project
exit
