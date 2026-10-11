create_project mb_ip_query [file join [pwd] "vivado_query_short"] -part xc7a35tcpg236-1 -force
puts "Vivado version: [version -short]"
puts "MicroBlaze IP definitions:"
foreach ip [get_ipdefs -all *microblaze*] { puts $ip }
puts "BRAM/controller IP definitions:"
foreach ip [get_ipdefs -all *bram*] { puts $ip }
close_project
exit
