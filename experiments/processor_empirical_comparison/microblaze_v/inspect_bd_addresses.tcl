open_project [file join [pwd] project mb_reference.xpr]
open_bd_design [get_files */mb_system.bd]
puts "SPACES [get_bd_addr_spaces]"
puts "SEGS [get_bd_addr_segs]"
foreach s [get_bd_addr_spaces] { puts "SPACE $s SEGS [get_bd_addr_segs -of_objects $s]" }
close_project
exit
