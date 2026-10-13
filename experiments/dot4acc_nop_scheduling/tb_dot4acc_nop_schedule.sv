import cpu_defs_pkg::*;

module tb_dot4acc_nop_schedule;
    localparam int OUTPUT_BASE_WORD = 25;
    localparam int SENTINEL_ADDR = (OUTPUT_BASE_WORD + 4) * 4;
    localparam int MAX_CYCLES = 5000;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b0;
    logic retire_valid, retire_mem_write;
    logic [31:0] retire_mem_addr, retire_mem_data;
    logic [3:0] retire_opcode;
    logic [31:0] total_cycles, retired_instructions;
    logic [31:0] pipeline_fill_cycles, data_hazard_stall_cycles;
    logic [31:0] load_use_stall_cycles, control_hazard_flush_cycles;
    logic [31:0] instruction_fetch_wait_cycles, memory_wait_cycles;
    logic [31:0] taken_branches, not_taken_branches, jumps;
    logic [31:0] wrong_path_instructions_flushed;

    integer opcode_counts [0:15];
    integer cycle_count;
    integer i;
    integer result_file;
    bit output_pass;
    bit done;

    always #5 clk = ~clk;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(256),
        .DMEM_DEPTH(256),
        .IMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .retire_valid(retire_valid),
        .retire_opcode(retire_opcode),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_data(retire_mem_data),
        .total_cycles(total_cycles),
        .retired_instructions(retired_instructions),
        .pipeline_fill_cycles(pipeline_fill_cycles),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .taken_branches(taken_branches),
        .not_taken_branches(not_taken_branches),
        .jumps(jumps),
        .wrong_path_instructions_flushed(wrong_path_instructions_flushed)
    );

    initial begin
        $readmemh("experiments/dot4acc_nop_scheduling/current_schedule.mem",
                  dut.instr_mem_inst.mem);
        $readmemh("programs/kan50_conv2_tile_dot4acc_data.mem",
                  dut.data_mem_inst.mem);

        for (i = 0; i < 16; i = i + 1)
            opcode_counts[i] = 0;

        rst = 1'b1;
        enable = 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        enable = 1'b1;
        cycle_count = 0;
        done = 1'b0;

        while (!done && cycle_count < MAX_CYCLES) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (retire_valid) begin
                opcode_counts[retire_opcode] = opcode_counts[retire_opcode] + 1;
                if (retire_mem_write && (retire_mem_addr == SENTINEL_ADDR))
                    done = 1'b1;
            end
        end
        enable = 1'b0;

        output_pass = 1'b1;
        if (dut.data_mem_inst.mem[OUTPUT_BASE_WORD+0] !== 32'hffff_ff8c)
            output_pass = 1'b0;
        if (dut.data_mem_inst.mem[OUTPUT_BASE_WORD+1] !== 32'h0000_000f)
            output_pass = 1'b0;
        if (dut.data_mem_inst.mem[OUTPUT_BASE_WORD+2] !== 32'hffff_ff9f)
            output_pass = 1'b0;
        if (dut.data_mem_inst.mem[OUTPUT_BASE_WORD+3] !== 32'h0000_005a)
            output_pass = 1'b0;

        result_file = $fopen("experiments/dot4acc_nop_scheduling/current_result.csv", "w");
        if (result_file == 0)
            $fatal(1, "could not open current scheduling result");
        $fdisplay(result_file,
            "cycles,retired,nops,dot4acc,loads,stores,fetch_waits,memory_waits,hazard_stalls,load_use_stalls,pipeline_fill,output_pass,completed");
        $fdisplay(result_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            total_cycles, retired_instructions, opcode_counts[0],
            opcode_counts[12], opcode_counts[7], opcode_counts[8],
            instruction_fetch_wait_cycles, memory_wait_cycles,
            data_hazard_stall_cycles, load_use_stall_cycles,
            pipeline_fill_cycles, output_pass, done);
        $fclose(result_file);

        $display("NOP_SCHEDULE_RESULT cycles=%0d retired=%0d nops=%0d dots=%0d loads=%0d stores=%0d fetch=%0d memory=%0d hazards=%0d loaduse=%0d output=%0d completed=%0d",
            total_cycles, retired_instructions, opcode_counts[0],
            opcode_counts[12], opcode_counts[7], opcode_counts[8],
            instruction_fetch_wait_cycles, memory_wait_cycles,
            data_hazard_stall_cycles, load_use_stall_cycles,
            output_pass, done);

        if (!done || !output_pass || opcode_counts[12] != 12 ||
            opcode_counts[7] != 24 || opcode_counts[8] != 5)
            $fatal(1, "NOP scheduling functional/profile expectation failed");
        $finish;
    end
endmodule
