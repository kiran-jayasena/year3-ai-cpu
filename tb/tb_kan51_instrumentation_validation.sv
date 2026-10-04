import cpu_defs_pkg::*;

module tb_kan51_instrumentation_validation;

    localparam int unsigned IMEM_DEPTH = 256;
    localparam int unsigned DMEM_DEPTH = 256;
    localparam int unsigned VALIDATION_RUNS = 5;
    localparam logic [31:0] NOP_INSTRUCTION = {OP_NOP, 28'h0};

    logic clk;
    logic rst;
    logic enable;
    logic retire_valid;
    logic [3:0] retire_opcode;
    logic retire_mem_write;
    logic [31:0] total_cycles;
    logic [31:0] retired_instructions;

    int csv_fd;
    int checks_run;
    int checks_failed;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .retire_valid(retire_valid),
        .retire_opcode(retire_opcode),
        .retire_mem_write(retire_mem_write),
        .total_cycles(total_cycles),
        .retired_instructions(retired_instructions)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] instr(
        input logic [3:0] opcode,
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [12:0] imm13
    );
        instr = {opcode, rd, rs1, rs2, imm13};
    endfunction

    function automatic logic [12:0] imm13_signed(input int value);
        imm13_signed = value[12:0];
    endfunction

    task automatic step_clock();
        @(posedge clk);
        #2;
    endtask

    task automatic check_true(input string name, input bit condition);
        checks_run++;
        if (!condition) begin
            checks_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    task automatic clear_memories();
        for (int index = 0; index < IMEM_DEPTH; index++) begin
            dut.instr_mem_inst.mem[index] = NOP_INSTRUCTION;
        end
        for (int index = 0; index < DMEM_DEPTH; index++) begin
            dut.data_mem_inst.mem[index] = 32'h0000_0000;
        end
    endtask

    task automatic reset_for_case();
        enable = 1'b0;
        rst = 1'b1;
        repeat (3) step_clock();
        rst = 1'b0;
        repeat (2) step_clock();
    endtask

    task automatic run_case(input int test_id, input int run_id);
        int expected_retired;
        int expected_store_word;
        int expected_result;
        int timeout;
        bit completed;
        string test_name;

        clear_memories();
        reset_for_case();

        expected_store_word = 0;
        case (test_id)
            0: begin
                test_name = "straight_line_arithmetic";
                expected_retired = 6;
                expected_result = 0;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(7));
                dut.instr_mem_inst.mem[1] = instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(5));
                dut.instr_mem_inst.mem[2] = instr(OP_ADD,  5'd3, 5'd1, 5'd2, 13'd0);
                dut.instr_mem_inst.mem[3] = instr(OP_SUB,  5'd4, 5'd3, 5'd2, 13'd0);
                dut.instr_mem_inst.mem[4] = instr(OP_XOR,  5'd5, 5'd4, 5'd1, 13'd0);
                dut.instr_mem_inst.mem[5] = instr(OP_STORE, 5'd0, 5'd0, 5'd5, 13'd0);
            end
            1: begin
                test_name = "fixed_count_loop";
                expected_retired = 14;
                expected_result = 3;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(0));
                dut.instr_mem_inst.mem[1] = instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(3));
                dut.instr_mem_inst.mem[2] = instr(OP_ADDI, 5'd1, 5'd1, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[3] = instr(OP_ADDI, 5'd2, 5'd2, 5'd0, imm13_signed(-1));
                dut.instr_mem_inst.mem[4] = instr(OP_BEQ,  5'd0, 5'd2, 5'd0, imm13_signed(2));
                dut.instr_mem_inst.mem[5] = instr(OP_JUMP, 5'd0, 5'd0, 5'd0, imm13_signed(-3));
                dut.instr_mem_inst.mem[6] = instr(OP_STORE, 5'd0, 5'd0, 5'd1, 13'd0);
            end
            2: begin
                test_name = "taken_branch_control_flow";
                expected_retired = 5;
                expected_result = 7;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI, 5'd1, 5'd0, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[1] = instr(OP_ADDI, 5'd2, 5'd0, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[2] = instr(OP_BEQ,  5'd0, 5'd1, 5'd2, imm13_signed(2));
                dut.instr_mem_inst.mem[3] = instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(99));
                dut.instr_mem_inst.mem[4] = instr(OP_ADDI, 5'd3, 5'd0, 5'd0, imm13_signed(7));
                dut.instr_mem_inst.mem[5] = instr(OP_STORE, 5'd0, 5'd0, 5'd3, 13'd0);
            end
            3: begin
                test_name = "load_store";
                expected_retired = 4;
                expected_result = 43;
                expected_store_word = 1;
                dut.data_mem_inst.mem[0] = 32'd42;
                dut.instr_mem_inst.mem[0] = instr(OP_ADDI,  5'd1, 5'd0, 5'd0, imm13_signed(0));
                dut.instr_mem_inst.mem[1] = instr(OP_LOAD,  5'd2, 5'd1, 5'd0, imm13_signed(0));
                dut.instr_mem_inst.mem[2] = instr(OP_ADDI,  5'd3, 5'd2, 5'd0, imm13_signed(1));
                dut.instr_mem_inst.mem[3] = instr(OP_STORE, 5'd0, 5'd1, 5'd3, imm13_signed(4));
            end
            default: begin
                test_name = "invalid_test_id";
                expected_retired = -1;
                expected_result = -1;
            end
        endcase

        timeout = 0;
        completed = 1'b0;
        enable = 1'b1;
        while (!completed && (timeout < 500)) begin
            step_clock();
            if (retire_valid && retire_mem_write) begin
                completed = 1'b1;
            end
            timeout++;
        end
        enable = 1'b0;

        check_true({test_name, " completed"}, completed);
        check_true({test_name, " retired count"}, retired_instructions == expected_retired);
        check_true({test_name, " functional result"},
                   dut.data_mem_inst.mem[expected_store_word] == expected_result);
        check_true({test_name, " counter nonzero"}, total_cycles > 32'd0);

        $fdisplay(csv_fd, "%s,%0d,%0d,%0d,%0d,%0d,%0d,%s,%s",
                  test_name,
                  run_id,
                  expected_retired,
                  retired_instructions,
                  total_cycles,
                  expected_result,
                  dut.data_mem_inst.mem[expected_store_word],
                  (retired_instructions == expected_retired) ? "PASS" : "FAIL",
                  (dut.data_mem_inst.mem[expected_store_word] == expected_result) ? "PASS" : "FAIL");
    endtask

    initial begin
        checks_run = 0;
        checks_failed = 0;
        rst = 1'b0;
        enable = 1'b0;
        csv_fd = $fopen("reports/kan51_instrumentation/raw_repeated_runs.csv", "w");
        if (csv_fd == 0) begin
            $fatal(1, "Could not open KAN-51 raw results CSV");
        end
        $fdisplay(csv_fd, "test,run,expected_retired,measured_retired,cycles,expected_result,measured_result,retired_pass,functional_pass");

        for (int run = 1; run <= VALIDATION_RUNS; run++) begin
            for (int test = 0; test < 4; test++) begin
                run_case(test, run);
            end
        end

        $fclose(csv_fd);
        $display("KAN-51 instrumentation validation checks=%0d failures=%0d", checks_run, checks_failed);
        if (checks_failed != 0) begin
            $fatal(1, "KAN-51 instrumentation validation failed");
        end
        $display("KAN-51 instrumentation validation PASSED");
        $finish;
    end

endmodule
