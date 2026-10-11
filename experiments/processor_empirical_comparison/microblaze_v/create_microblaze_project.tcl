set FPGA_PART xc7a35tcpg236-1
set PROJECT_DIR [file normalize [file join [pwd] project]]
set PROJECT_NAME mb_reference

create_project $PROJECT_NAME $PROJECT_DIR -part $FPGA_PART -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
create_bd_design mb_system

create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze_riscv:1.0 microblaze_0
set_property -dict [list \
    CONFIG.C_DATA_SIZE {32} \
    CONFIG.C_OPTIMIZATION {1} \
    CONFIG.C_USE_MULDIV {1} \
    CONFIG.C_USE_ICACHE {0} \
    CONFIG.C_USE_DCACHE {0} \
    CONFIG.C_I_LMB {1} \
    CONFIG.C_D_LMB {1} \
    CONFIG.C_I_AXI {0} \
    CONFIG.C_D_AXI {0} \
    CONFIG.C_S_AXI {0} \
    CONFIG.C_USE_EXTENDED_FSL_INSTR {0} \
    CONFIG.C_USE_COUNTERS {1} \
    CONFIG.C_DEBUG_ENABLED {0} \
    CONFIG.C_USE_FPU {0} \
    CONFIG.C_USE_COMPRESSION {0} \
    CONFIG.C_USE_ATOMIC {0} \
    CONFIG.C_USE_BARREL {1}] [get_bd_cells microblaze_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 ilmb_bram_if_cntlr
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_bram_if_cntlr
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 ilmb_bram
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 dlmb_bram
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_sys
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 interrupt_const

set_property -dict [list CONFIG.Memory_Type {Single_Port_RAM} CONFIG.Write_Width_A {32} CONFIG.Read_Width_A {32} CONFIG.Write_Depth_A {8192} CONFIG.Load_Init_File {false}] [get_bd_cells ilmb_bram]
set_property -dict [list CONFIG.Memory_Type {Single_Port_RAM} CONFIG.Write_Width_A {32} CONFIG.Read_Width_A {32} CONFIG.Write_Depth_A {8192} CONFIG.Load_Init_File {false}] [get_bd_cells dlmb_bram]
set_property CONFIG.CONST_VAL {0} [get_bd_cells interrupt_const]

create_bd_port -dir I -type clk -freq_hz 93000000 sys_clk
create_bd_port -dir I -type rst sys_rst
set_property CONFIG.POLARITY {ACTIVE_HIGH} [get_bd_ports sys_rst]

connect_bd_net [get_bd_ports sys_clk] [get_bd_pins microblaze_0/Clk] [get_bd_pins rst_sys/slowest_sync_clk]
connect_bd_net [get_bd_ports sys_rst] [get_bd_pins rst_sys/ext_reset_in]
connect_bd_net [get_bd_pins rst_sys/mb_reset] [get_bd_pins microblaze_0/Reset]
connect_bd_net [get_bd_pins interrupt_const/dout] [get_bd_pins microblaze_0/Interrupt]

connect_bd_intf_net [get_bd_intf_pins microblaze_0/ILMB] [get_bd_intf_pins ilmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins microblaze_0/DLMB] [get_bd_intf_pins dlmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins ilmb_bram/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins dlmb_bram/BRAM_PORTA]

connect_bd_net [get_bd_ports sys_clk] [get_bd_pins ilmb_bram_if_cntlr/LMB_Clk] [get_bd_pins dlmb_bram_if_cntlr/LMB_Clk]
connect_bd_net [get_bd_pins rst_sys/peripheral_reset] [get_bd_pins ilmb_bram_if_cntlr/LMB_Rst] [get_bd_pins dlmb_bram_if_cntlr/LMB_Rst]

assign_bd_address -offset 0x00000000 -range 0x00008000 -target_address_space [get_bd_addr_spaces microblaze_0/Data] [get_bd_addr_segs dlmb_bram_if_cntlr/SLMB/Mem]
assign_bd_address -offset 0x00000000 -range 0x00008000 -target_address_space [get_bd_addr_spaces microblaze_0/Instruction] [get_bd_addr_segs ilmb_bram_if_cntlr/SLMB/Mem]

validate_bd_design
save_bd_design
make_wrapper -files [get_files [file join $PROJECT_DIR $PROJECT_NAME.srcs sources_1 bd mb_system mb_system.bd]] -top
add_files -norecurse [file join $PROJECT_DIR $PROJECT_NAME.gen sources_1 bd mb_system hdl mb_system_wrapper.v]
update_compile_order -fileset sources_1
set_property top mb_system_wrapper [get_filesets sources_1]
set_property platform.name mb_reference [current_project]
set_property platform.board_id xc7a35tcpg236-1 [current_project]
generate_target all [get_files [file join $PROJECT_DIR $PROJECT_NAME.srcs sources_1 bd mb_system mb_system.bd]]
set_property platform.name mb_reference [current_project]
set_property platform.board_id xc7a35tcpg236-1 [current_project]
set_property platform.default_output_type {sd_card} [current_project]
set_property platform.design_intent.embedded {true} [current_project]
write_hw_platform -fixed -force [file join $PROJECT_DIR mb_system_fixed.xsa]
close_bd_design [get_bd_designs mb_system]
close_project
exit
