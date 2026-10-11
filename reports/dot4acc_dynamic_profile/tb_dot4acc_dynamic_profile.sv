import cpu_defs_pkg::*;

module tb_dot4acc_dynamic_profile;
    localparam int IMEM_DEPTH = 256;
    localparam int DMEM_DEPTH = 256;
    localparam logic [31:0] A_WORD = 32'hff01_fe03;
    localparam logic [31:0] B_WORD = 32'h0500_807f;
    localparam logic [31:0] INITIAL_ACC = 32'd37;
    localparam int LENGTHS [0:2] = '{16, 64, 128};

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b0;
    logic retire_valid, retire_mem_write;
    logic [3:0] retire_opcode;
    logic [31:0] retire_mem_addr;
    logic [31:0] total_cycles, retired_instructions;
    logic [31:0] pipeline_fill_cycles, data_hazard_stall_cycles;
    logic [31:0] load_use_stall_cycles, control_hazard_flush_cycles;
    logic [31:0] instruction_fetch_wait_cycles, memory_wait_cycles;
    logic [31:0] taken_branches, not_taken_branches, jumps;
    logic [31:0] wrong_path_instructions_flushed;

    integer csv_fd;
    integer checks_failed = 0;

    always #5 clk = ~clk;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(IMEM_DEPTH), .DMEM_DEPTH(DMEM_DEPTH), .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk), .rst(rst), .enable(enable),
        .retire_valid(retire_valid), .retire_opcode(retire_opcode),
        .retire_mem_write(retire_mem_write), .retire_mem_addr(retire_mem_addr),
        .total_cycles(total_cycles), .retired_instructions(retired_instructions),
        .pipeline_fill_cycles(pipeline_fill_cycles),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .taken_branches(taken_branches), .not_taken_branches(not_taken_branches),
        .jumps(jumps), .wrong_path_instructions_flushed(wrong_path_instructions_flushed),
        .dot_issue_valid(), .dot_issue_accept(), .dot_issue_rd(),
        .dot_issue_packed_a(), .dot_issue_packed_b(), .dot_issue_accumulator(),
        .dot_issue_chain(), .dot_issue_pc(), .dot_issue_opcode(),
        .dot_inflight_valid(), .dot_inflight_rd(), .dot_complete_valid(),
        .dot_complete_eligible(), .dot_complete_rd(), .dot_complete_result(),
        .dot_complete_pc(), .dot_complete_opcode(), .normal_wb_valid(),
        .dot_wb_valid(), .rf_write_enable(), .rf_write_addr(), .rf_write_data(),
        .dot_retire_valid(), .dot_active(), .dot_frontend_hold(),
        .dot_dependency_stall(), .dot_source_dependency_stall(),
        .dot_accumulator_dependency_stall(), .dot_cancel_event()
    );

    function automatic logic [31:0] instr(
        input logic [3:0] op, input logic [4:0] rd, input logic [4:0] rs1,
        input logic [4:0] rs2, input logic [12:0] imm
    );
        instr = {op, rd, rs1, rs2, imm};
    endfunction

    function automatic logic [31:0] expected_for(input int n);
        logic [31:0] value;
        value = INITIAL_ACC;
        for (int i = 0; i < n / 4; i++)
            value = value + 32'd632;
        expected_for = value;
    endfunction

    task automatic reset_and_clear;
        rst = 1'b1; enable = 1'b0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        for (int i = 0; i < IMEM_DEPTH; i++) dut.instr_mem_inst.mem[i] = {OP_NOP, 28'd0};
        for (int i = 0; i < DMEM_DEPTH; i++) dut.data_mem_inst.mem[i] = 32'd0;
    endtask

    task automatic run_case(input int n);
        int k, pc, timeout;
        int dots, loads, stores, addis, branches, jumps_local, other;
        bit done;
        logic [31:0] expected;
        k = n / 4;
        pc = 0;
        reset_and_clear();
        dut.regs[9] = INITIAL_ACC;
        dut.regs[10] = 32'd64;
        for (int block = 0; block < k; block++) begin
            dut.data_mem_inst.mem[16 + 2*block] = A_WORD;
            dut.data_mem_inst.mem[17 + 2*block] = B_WORD;
            dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd1, 5'd10, 5'd0, block * 8);
            dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd2, 5'd10, 5'd0, (block * 8) + 4);
            dut.instr_mem_inst.mem[pc++] = {OP_DOT4ACC, 5'd9, 5'd1, 5'd2, 13'd0};
        end
        dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
        expected = expected_for(n);
        dots = 0; loads = 0; stores = 0; addis = 0; branches = 0; jumps_local = 0; other = 0;
        timeout = 0; done = 1'b0; enable = 1'b1;
        while (!done && timeout < 3000) begin
            @(posedge clk); #1; timeout++;
            if (retire_valid) begin
                if (retire_opcode == OP_DOT4ACC) dots++;
                else if (retire_opcode == OP_LOAD) loads++;
                else if (retire_opcode == OP_STORE) stores++;
                else if (retire_opcode == OP_ADDI) addis++;
                else if (retire_opcode == OP_BEQ) branches++;
                else if (retire_opcode == OP_JUMP) jumps_local++;
                else other++;
                if (retire_mem_write && retire_mem_addr == 0) done = 1'b1;
            end
        end
        enable = 1'b0;
        if (!done || dut.data_mem_inst.mem[0] !== expected) begin
            checks_failed++;
            $display("FAIL N=%0d done=%0d result=%08h expected=%08h", n, done,
                     dut.data_mem_inst.mem[0], expected);
        end
        if (dots != k || loads != 2*k || stores != 1 || addis != 0 ||
            branches != 0 || jumps_local != 0 || other != 0) begin
            checks_failed++;
            $display("FAIL counts N=%0d dot=%0d load=%0d store=%0d addi=%0d branch=%0d jump=%0d other=%0d",
                     n, dots, loads, stores, addis, branches, jumps_local, other);
        end
        $fwrite(csv_fd, "memory_fed,%0d,%0d,0x%08h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
                n, n, dut.data_mem_inst.mem[0], total_cycles, retired_instructions,
                dots, loads, stores, addis, branches, jumps_local, other,
                instruction_fetch_wait_cycles, memory_wait_cycles,
                data_hazard_stall_cycles, load_use_stall_cycles, pipeline_fill_cycles);
        $fwrite(csv_fd, "%0.6f,%0.6f,%0d,%0d,%0d,%0d,%0d,PASS\n",
                real'(total_cycles) / real'(n),
                real'(retired_instructions) / real'(n), taken_branches,
                not_taken_branches, wrong_path_instructions_flushed,
                control_hazard_flush_cycles, timeout);
        $display("DOT_PROFILE N=%0d result=%08h cycles=%0d retired=%0d dots=%0d loads=%0d stores=%0d addi=%0d branches=%0d jumps=%0d other=%0d fetch=%0d memory=%0d hazards=%0d loaduse=%0d fill=%0d flush=%0d",
                 n, dut.data_mem_inst.mem[0], total_cycles, retired_instructions,
                 dots, loads, stores, addis, branches, jumps_local, other,
                 instruction_fetch_wait_cycles, memory_wait_cycles,
                 data_hazard_stall_cycles, load_use_stall_cycles,
                 pipeline_fill_cycles, control_hazard_flush_cycles);
    endtask

    initial begin
        csv_fd = $fopen("reports/dot4acc_dynamic_profile/results.csv", "w");
        if (csv_fd == 0) $fatal(1, "could not open profiling CSV");
        $fdisplay(csv_fd, "kernel,N,mac_equivalent,result,total_cycles,retired,dot4acc,loads,stores,addi_setup,branches,jumps,other,fetch_waits,memory_waits,hazard_stalls,load_use_stalls,pipeline_fill,cycles_per_mac,instructions_per_mac,taken_branches,not_taken_branches,wrong_path_flushes,control_flushes,timeout,correctness");
        for (int i = 0; i < 3; i++) run_case(LENGTHS[i]);
        $fclose(csv_fd);
        if (checks_failed != 0) $fatal(1, "DOT profiling checks failed: %0d", checks_failed);
        $finish;
    end
endmodule
