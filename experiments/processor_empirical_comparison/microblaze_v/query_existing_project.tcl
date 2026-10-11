open_project [file join [pwd] "vivado_query" "mb_ip_query.xpr"]
puts "Vivado version: [version -short]"
puts "MicroBlaze IP definitions:"
puts [get_ipdefs -all *microblaze*]
puts "BRAM/controller IP definitions:"
puts [get_ipdefs -all *bram*]
close_project
exit
