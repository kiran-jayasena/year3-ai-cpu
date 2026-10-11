open_project [file join [pwd] project mb_reference.xpr]
set bd [get_files */mb_system.bd]
reset_target all $bd
generate_target all $bd
generate_target all $bd
export_ip_user_files -of_objects $bd -no_script -sync -force
file mkdir [file join [pwd] sim_ip_user_files]
file mkdir [file join [pwd] sim_ipstatic]
file mkdir [file join [pwd] sim_export]
export_simulation -of_objects $bd -simulator xsim -directory [file join [pwd] sim_export] -ip_user_files_dir [file join [pwd] sim_ip_user_files] -ipstatic_source_dir [file join [pwd] sim_ipstatic] -force
close_project
exit
