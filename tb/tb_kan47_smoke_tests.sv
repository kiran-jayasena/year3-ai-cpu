import cpu_defs_pkg::*;

module tb_kan47_smoke_tests;
    localparam int IMEM_DEPTH = 256;
    localparam int DMEM_DEPTH = 256;
    localparam int RUNS = 5;

    logic clk = 1'b0;
    logic rst = 1'b0;
    logic enable = 1'b0;
    logic [31:0] fetch_pc;
    logic retire_valid;
    logic retire_mem_write;
    logic [31:0] retire_mem_addr;
    logic [31:0] total_cycles;
    logic [31:0] retired_instructions;

    integer csv_fd;
    integer run_id;
    integer test_id;
    integer index;
    integer timeout;
    integer checks_run;
    integer checks_failed;
    bit all_pass;

    always #5 clk = ~clk;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .fetch_pc(fetch_pc),
        .retire_valid(retire_valid),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .total_cycles(total_cycles),
        .retired_instructions(retired_instructions)
    );

    function automatic logic [31:0] instr(
        input logic [3:0] opcode,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [12:0] imm13
    );
        instr = {opcode, rd, rs1, rs2, imm13};
    endfunction

    function automatic logic [12:0] imm13_signed(input integer value);
        imm13_signed = value[12:0];
    endfunction

    task automatic step_clock();
        @(posedge clk);
        #2;
    endtask

    task automatic check_true(input string name, input bit condition);
        checks_run = checks_run + 1;
        if (!condition) begin
            checks_failed = checks_failed + 1;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic clear_memories();
        for (index = 0; index < IMEM_DEPTH; index = index + 1) begin
            dut.instr_mem_inst.mem[index] = {OP_NOP, 28'h0};
        end
        for (index = 0; index < DMEM_DEPTH; index = index + 1) begin
            dut.data_mem_inst.mem[index] = 32'd0;
        end
    endtask

    task automatic reset_cpu(output bit reset_pc_ok);
        enable = 1'b0;
        rst = 1'b1;
        repeat (3) step_clock();
        reset_pc_ok = (fetch_pc == 32'd0);
        rst = 1'b0;
        repeat (2) step_clock();
    endtask

    task automatic install_program(
        input integer id,
        output integer expected_value,
        output integer sentinel_address
    );
        expected_value = 0;
        sentinel_address = 0;
        case (id)
            0: begin
                // Reset/start-up: entry PC must be zero, then execute ADDI and STORE.
                expected_value = 1;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[1] = instr(OP_STORE, 5'd0, 5'd0, 5'd1, 13'd0);
            end
            1: begin
                // 5 + 7 = 12; 12 - 5 = 7.
                expected_value = 7;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(5));
                dut.instr_mem_inst.mem[1] = instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(7));
                dut.instr_mem_inst.mem[2] = instr(OP_ADD,  5'd3, 5'd1, 5'd2, 13'd0);
                dut.instr_mem_inst.mem[3] = instr(OP_SUB,  5'd4, 5'd3, 5'd1, 13'd0);
                dut.instr_mem_inst.mem[4] = instr(OP_STORE, 5'd0, 5'd0, 5'd4, 13'd0);
            end
            2: begin
                // Taken BEQ skips the wrong-path ADDI x3=99 and reaches x3=7.
                expected_value = 7;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[1] = instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[2] = instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2));
                dut.instr_mem_inst.mem[3] = instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(99));
                dut.instr_mem_inst.mem[4] = instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(7));
                dut.instr_mem_inst.mem[5] = instr(OP_STORE, 5'd0, 5'd0, 5'd3, 13'd0);
            end
            3: begin
                // Store 43, load it back, then store the loaded value at byte address 4.
                expected_value = 43;
                sentinel_address = 4;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI,  5'd1, 5'd0, 5'd0, imm13_signed(43));
                dut.instr_mem_inst.mem[1] = instr(OP_STORE, 5'd0, 5'd0, 5'd1, imm13_signed(0));
                dut.instr_mem_inst.mem[2] = instr(OP_LOAD,  5'd2, 5'd0, 5'd0, imm13_signed(0));
                dut.instr_mem_inst.mem[3] = instr(OP_STORE, 5'd0, 5'd0, 5'd2, imm13_signed(4));
            end
            4: begin
                // Load-use dependency: load 5, immediately double it, store 10.
                expected_value = 10;
                sentinel_address = 4;
                dut.data_mem_inst.mem[0] = 32'd5;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(0));
                dut.instr_mem_inst.mem[1] = instr(OP_LOAD, 5'd2, 5'd1, 5'd0, imm13_signed(0));
                dut.instr_mem_inst.mem[2] = instr(OP_ADD,  5'd3, 5'd2, 5'd2, 13'd0);
                dut.instr_mem_inst.mem[3] = instr(OP_STORE, 5'd0, 5'd0, 5'd3, imm13_signed(4));
            end
            default: begin
                expected_value = -1;
            end
        endcase
    endtask

    task automatic run_case(input integer id, input integer repetition);
        integer expected_value;
        integer sentinel_address;
        integer observed_value;
        bit reset_pc_ok;
        bit completed;
        bit result_ok;
        string test_name;

        case (id)
            0: test_name = "reset_startup";
            1: test_name = "scalar_arithmetic";
            2: test_name = "taken_branch";
            3: test_name = "load_store";
            4: test_name = "load_use_dependency";
            default: test_name = "invalid";
        endcase

        clear_memories();
        install_program(id, expected_value, sentinel_address);
        reset_cpu(reset_pc_ok);

        timeout = 0;
        completed = 1'b0;
        enable = 1'b1;
        while (!completed && (timeout < 1000)) begin
            step_clock();
            if (retire_valid && retire_mem_write && (retire_mem_addr == sentinel_address)) begin
                completed = 1'b1;
            end
            timeout = timeout + 1;
        end
        enable = 1'b0;

        observed_value = dut.data_mem_inst.mem[sentinel_address >> 2];
        result_ok = completed && reset_pc_ok && (observed_value == expected_value);
        check_true({test_name, " completed"}, completed);
        check_true({test_name, " reset entry PC"}, reset_pc_ok);
        check_true({test_name, " architectural result"}, observed_value == expected_value);
        $fdisplay(csv_fd, "%s,%0d,%0d,%0d,%0d,%0d,%s,%s", test_name, repetition,
                  expected_value, observed_value, total_cycles, retired_instructions,
                  reset_pc_ok ? "PASS" : "FAIL", result_ok ? "PASS" : "FAIL");
endtask

    initial begin
        checks_run = 0;
        checks_failed = 0;
        csv_fd = $fopen("reports/kan47_smoke_tests/repeated_runs.csv", "w");
        if (csv_fd == 0) $fatal(1, "could not open KAN-47 CSV");
        $fdisplay(csv_fd, "test,run,expected,actual,cycles,retired,reset_pass,result");
        all_pass = 1'b1;
        for (run_id = 1; run_id <= RUNS; run_id = run_id + 1) begin
            for (test_id = 0; test_id < 5; test_id = test_id + 1) begin
                run_case(test_id, run_id);
            end
        end
        $fclose(csv_fd);
        if (checks_failed != 0) all_pass = 1'b0;
        $display("KAN-47 smoke checks=%0d failures=%0d", checks_run, checks_failed);
        if (!all_pass) $fatal(1, "KAN-47 smoke tests FAILED");
        $display("KAN-47 smoke tests PASSED");
        $finish;
    end
endmodule
