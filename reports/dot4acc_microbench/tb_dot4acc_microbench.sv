import cpu_defs_pkg::*;

module tb_dot4acc_microbench;
    localparam int IMEM_DEPTH = 256;
    localparam int DMEM_DEPTH = 256;
    localparam logic [31:0] A_WORD = 32'hff01_fe03;
    localparam logic [31:0] B_WORD = 32'h0500_807f;
    localparam logic [31:0] INITIAL_ACC = 32'd37;
    localparam int K_LENGTHS [0:3] = '{4, 16, 32, 64};

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
        .fetch_pc(), .instruction_addr(), .fetch_request_pc(), .fetch_request_valid(),
        .if_id_valid(), .if_id_pc(), .if_id_instruction(), .decoded_opcode(),
        .decoded_valid(), .id_ex_valid(), .ex_mem_valid(), .mem_wb_valid(),
        .alu_result(), .data_addr(), .memory_read_data(), .retire_pc(), .retire_rd(),
        .retire_reg_write(), .retire_write_data(), .retire_mem_data(), .reg_write(),
        .mem_write(), .pc_redirect(), .dot_issue_valid(), .dot_issue_accept(),
        .dot_issue_rd(), .dot_issue_packed_a(), .dot_issue_packed_b(),
        .dot_issue_accumulator(), .dot_issue_chain(), .dot_issue_pc(),
        .dot_issue_opcode(), .dot_inflight_valid(), .dot_inflight_rd(),
        .dot_complete_valid(), .dot_complete_eligible(), .dot_complete_rd(),
        .dot_complete_result(), .dot_complete_pc(), .dot_complete_opcode(),
        .normal_wb_valid(), .dot_wb_valid(), .rf_write_enable(), .rf_write_addr(),
        .rf_write_data(), .dot_retire_valid(), .dot_active(), .dot_frontend_hold(),
        .dot_dependency_stall(), .dot_source_dependency_stall(), .dot_accumulator_dependency_stall(),
        .dot_cancel_event()
    );

    function automatic logic [31:0] instr(input logic [3:0] op, input logic [4:0] rd,
                                           input logic [4:0] rs1, input logic [4:0] rs2,
                                           input logic [12:0] imm);
        instr = {op, rd, rs1, rs2, imm};
    endfunction

    function automatic logic [31:0] dot_expected(input int k);
        dot_expected = INITIAL_ACC + (32'd632 * k);
    endfunction

    task automatic reset_and_clear;
        rst = 1'b1; enable = 1'b0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        for (int i = 0; i < IMEM_DEPTH; i++) dut.instr_mem_inst.mem[i] = {OP_NOP, 28'd0};
        for (int i = 0; i < DMEM_DEPTH; i++) dut.data_mem_inst.mem[i] = 32'd0;
    endtask

    task automatic emit_result(input string family, input int k,
                               input logic [31:0] expected,
                               input int dots, input int loads, input int stores,
                               input int addi, input int branches, input int jumps_dyn,
                               input int other, input int timeout);
        if (dut.data_mem_inst.mem[0] !== expected) begin
            checks_failed++;
            $display("FAIL %s K=%0d result=%08h expected=%08h", family, k,
                     dut.data_mem_inst.mem[0], expected);
        end
        $fwrite(csv_fd, "%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
                family, k, k*4, total_cycles, retired_instructions, dots, loads,
                stores, instruction_fetch_wait_cycles, memory_wait_cycles,
                data_hazard_stall_cycles, load_use_stall_cycles, pipeline_fill_cycles);
        $fwrite(csv_fd, "%0.6f,%0.6f,%0.6f,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%08h,0x%08h,PASS\n",
                real'(total_cycles) / real'(retired_instructions),
                (dots > 0) ? real'(total_cycles) / real'(dots) : 0.0,
                (dots > 0) ? real'(retired_instructions) / real'(dots) : 0.0,
                addi, branches, jumps_dyn, other, timeout,
                taken_branches, not_taken_branches, wrong_path_instructions_flushed,
                control_hazard_flush_cycles, dut.data_mem_inst.mem[0], expected);
        $display("MICROBENCH family=%s K=%0d result=%08h cycles=%0d retired=%0d dots=%0d loads=%0d stores=%0d fetch=%0d memory=%0d hazard=%0d loaduse=%0d fill=%0d cpi=%0.4f cycles_dot=%0.4f",
                 family, k, dut.data_mem_inst.mem[0], total_cycles, retired_instructions,
                 dots, loads, stores, instruction_fetch_wait_cycles, memory_wait_cycles,
                 data_hazard_stall_cycles, load_use_stall_cycles, pipeline_fill_cycles,
                 real'(total_cycles) / real'(retired_instructions),
                 (dots > 0) ? real'(total_cycles) / real'(dots) : 0.0);
    endtask

    task automatic run_case(input string family, input int k, input int mode);
        int pc, timeout, dots, loads, stores, addi, branches, jumps_dyn, other;
        bit done;
        logic [31:0] expected;
        reset_and_clear();
        dut.regs[1] = A_WORD;
        dut.regs[2] = B_WORD;
        dut.regs[9] = INITIAL_ACC;
        dut.regs[10] = 32'd64;
        pc = 0;
        for (int block = 0; block < k; block++) begin
            if (mode == 0) begin
                dut.instr_mem_inst.mem[pc++] = {OP_DOT4ACC, 5'd9, 5'd1, 5'd2, 13'd0};
            end else if (mode == 1) begin
                dut.data_mem_inst.mem[16 + 2*block] = A_WORD;
                dut.data_mem_inst.mem[17 + 2*block] = B_WORD;
                dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd1, 5'd10, 5'd0, block * 8);
                dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd2, 5'd10, 5'd0, (block * 8) + 4);
                dut.instr_mem_inst.mem[pc++] = {OP_NOP, 28'd0};
            end else begin
                dut.data_mem_inst.mem[16 + 2*block] = A_WORD;
                dut.data_mem_inst.mem[17 + 2*block] = B_WORD;
                dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd1, 5'd10, 5'd0, block * 8);
                dut.instr_mem_inst.mem[pc++] = instr(OP_LOAD, 5'd2, 5'd10, 5'd0, (block * 8) + 4);
                dut.instr_mem_inst.mem[pc++] = {OP_DOT4ACC, 5'd9, 5'd1, 5'd2, 13'd0};
            end
        end
        if (mode == 0) begin
            dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
            expected = dot_expected(k);
        end else if (mode == 1) begin
            dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd2, 13'd0);
            expected = B_WORD;
        end else begin
            dut.instr_mem_inst.mem[pc] = instr(OP_STORE, 5'd0, 5'd0, 5'd9, 13'd0);
            expected = dot_expected(k);
        end
        dots = 0; loads = 0; stores = 0; addi = 0; branches = 0; jumps_dyn = 0; other = 0;
        timeout = 0; done = 1'b0; enable = 1'b1;
        while (!done && timeout < 3000) begin
            @(posedge clk); #1; timeout++;
            if (retire_valid) begin
                if (retire_opcode == OP_DOT4ACC) dots++;
                else if (retire_opcode == OP_LOAD) loads++;
                else if (retire_opcode == OP_STORE) stores++;
                else if (retire_opcode == OP_ADDI) addi++;
                else if (retire_opcode == OP_BEQ) branches++;
                else if (retire_opcode == OP_JUMP) jumps_dyn++;
                else if (retire_opcode != OP_NOP) other++;
                if (retire_mem_write && retire_mem_addr == 0) done = 1'b1;
            end
        end
        enable = 1'b0;
        if (!done) checks_failed++;
        emit_result(family, k, expected, dots, loads, stores, addi, branches, jumps_dyn, other, timeout);
    endtask

    initial begin
        csv_fd = $fopen("reports/dot4acc_microbench/results.csv", "w");
        if (csv_fd == 0) $fatal(1, "could not open microbenchmark CSV");
        $fdisplay(csv_fd, "family,dot_count,mac_equivalent,total_cycles,retired,dot4acc,loads,stores,fetch_waits,memory_waits,data_hazard_stalls,load_use_stalls,pipeline_fill,cycles_per_instruction,cycles_per_dot,instructions_per_dot,addi_setup,branches,jumps,other,timeout,taken_branches,not_taken_branches,wrong_path_flushes,control_flushes,result,expected,correctness");
        for (int i = 0; i < 4; i++) begin
            run_case("A_register_resident", K_LENGTHS[i], 0);
            run_case("B_load_only", K_LENGTHS[i], 1);
            run_case("C_load_load_dot", K_LENGTHS[i], 2);
        end
        $fclose(csv_fd);
        if (checks_failed != 0) $fatal(1, "microbenchmark checks failed: %0d", checks_failed);
        $finish;
    end
endmodule
