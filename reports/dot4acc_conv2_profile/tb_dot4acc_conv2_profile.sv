import cpu_defs_pkg::*;

module tb_dot4acc_conv2_profile;
    localparam int OUTPUT_BASE_WORD = 25;
    localparam int SENTINEL_ADDR = (OUTPUT_BASE_WORD + 4) * 4;
    localparam int MAX_CYCLES = 5000;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b0;
    logic retire_valid, retire_mem_write;
    logic [31:0] retire_pc, retire_mem_addr, retire_mem_data;
    logic [3:0] retire_opcode;
    logic [31:0] total_cycles, retired_instructions;
    logic [31:0] pipeline_fill_cycles, data_hazard_stall_cycles;
    logic [31:0] load_use_stall_cycles, control_hazard_flush_cycles;
    logic [31:0] instruction_fetch_wait_cycles, memory_wait_cycles;
    logic [31:0] taken_branches, not_taken_branches, jumps;
    logic [31:0] wrong_path_instructions_flushed;
    logic dot_issue_accept, dot_complete_valid;
    logic [31:0] dot_issue_packed_a, dot_issue_packed_b, dot_issue_accumulator;
    logic [31:0] dot_complete_result;
    logic [31:0] expected [0:3];
    integer trace_file, summary_file;
    integer opcode_counts [0:15];
    integer cycle_count;
    integer i;
    bit output_pass;

    always #5 clk = ~clk;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(256), .DMEM_DEPTH(256),
        .IMEM_INIT_FILE("programs/kan50_conv2_tile_dot4acc_scheduled.mem")
    ) dut (
        .clk(clk), .rst(rst), .enable(enable),
        .retire_valid(retire_valid), .retire_pc(retire_pc),
        .retire_opcode(retire_opcode), .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr), .retire_mem_data(retire_mem_data),
        .total_cycles(total_cycles), .retired_instructions(retired_instructions),
        .pipeline_fill_cycles(pipeline_fill_cycles),
        .data_hazard_stall_cycles(data_hazard_stall_cycles),
        .load_use_stall_cycles(load_use_stall_cycles),
        .control_hazard_flush_cycles(control_hazard_flush_cycles),
        .instruction_fetch_wait_cycles(instruction_fetch_wait_cycles),
        .memory_wait_cycles(memory_wait_cycles),
        .taken_branches(taken_branches), .not_taken_branches(not_taken_branches),
        .jumps(jumps), .wrong_path_instructions_flushed(wrong_path_instructions_flushed)
        ,.dot_issue_accept(dot_issue_accept)
        ,.dot_issue_packed_a(dot_issue_packed_a)
        ,.dot_issue_packed_b(dot_issue_packed_b)
        ,.dot_issue_accumulator(dot_issue_accumulator)
        ,.dot_complete_valid(dot_complete_valid)
        ,.dot_complete_result(dot_complete_result)
    );

    initial begin
        $readmemh("programs/kan50_conv2_tile_dot4acc_data.mem", dut.data_mem_inst.mem);
        expected[0] = 32'hffff_ff8c;
        expected[1] = 32'h0000_000f;
        expected[2] = 32'hffff_ff9f;
        expected[3] = 32'h0000_005a;
        for (i = 0; i < 16; i = i + 1) opcode_counts[i] = 0;
        trace_file = $fopen("reports/dot4acc_conv2_profile/execution_trace.txt", "w");
        summary_file = $fopen("reports/dot4acc_conv2_profile/trace_summary.csv", "w");
        if (trace_file == 0 || summary_file == 0)
            $fatal(1, "could not open DOT4ACC Conv2 evidence files");

        rst = 1'b1;
        enable = 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        enable = 1'b1;
        cycle_count = 0;
        $fdisplay(trace_file, "cycle,retired_index,pc,opcode,mem_write,mem_addr,mem_data");
        while (cycle_count < MAX_CYCLES) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (dot_issue_accept)
                $display("DOT_ISSUE cycle=%0d a=%08h b=%08h acc=%08h", total_cycles, dot_issue_packed_a, dot_issue_packed_b, dot_issue_accumulator);
            if (dot_complete_valid)
                $display("DOT_COMPLETE cycle=%0d result=%08h", total_cycles, dot_complete_result);
            if (retire_valid) begin
                opcode_counts[retire_opcode] = opcode_counts[retire_opcode] + 1;
                $fdisplay(trace_file, "%0d,%0d,%08h,%h,%0d,%0d,%08h", total_cycles,
                          retired_instructions, retire_pc, retire_opcode,
                          retire_mem_write, retire_mem_addr, retire_mem_data);
            end
            if (retire_valid && retire_mem_write && (retire_mem_addr == SENTINEL_ADDR))
                break;
        end
        enable = 1'b0;
        output_pass = 1'b1;
        for (i = 0; i < 4; i = i + 1)
            if (dut.data_mem_inst.mem[OUTPUT_BASE_WORD+i] !== expected[i])
                output_pass = 1'b0;

        $fdisplay(summary_file, "field,value");
        $fdisplay(summary_file, "cycles,%0d", total_cycles);
        $fdisplay(summary_file, "retired,%0d", retired_instructions);
        $fdisplay(summary_file, "output_pass,%0d", output_pass);
        $fdisplay(summary_file, "pipeline_fill,%0d", pipeline_fill_cycles);
        $fdisplay(summary_file, "data_hazard,%0d", data_hazard_stall_cycles);
        $fdisplay(summary_file, "load_use,%0d", load_use_stall_cycles);
        $fdisplay(summary_file, "control_flush,%0d", control_hazard_flush_cycles);
        $fdisplay(summary_file, "fetch_wait,%0d", instruction_fetch_wait_cycles);
        $fdisplay(summary_file, "memory_wait,%0d", memory_wait_cycles);
        $fdisplay(summary_file, "taken_branches,%0d", taken_branches);
        $fdisplay(summary_file, "not_taken_branches,%0d", not_taken_branches);
        $fdisplay(summary_file, "jumps,%0d", jumps);
        $fdisplay(summary_file, "wrong_path_flushed,%0d", wrong_path_instructions_flushed);
        for (i = 0; i < 16; i = i + 1)
            $fdisplay(summary_file, "opcode_%h,%0d", i, opcode_counts[i]);
        $fclose(trace_file);
        $fclose(summary_file);
        $display("DOT4ACC_CONV2 cycles=%0d retired=%0d output_pass=%0d", total_cycles, retired_instructions, output_pass);
        $display("DOT4ACC_CONV2 counters fill=%0d data_hazard=%0d load_use=%0d control_flush=%0d fetch_wait=%0d memory_wait=%0d taken=%0d not_taken=%0d jumps=%0d wrong_path=%0d", pipeline_fill_cycles, data_hazard_stall_cycles, load_use_stall_cycles, control_hazard_flush_cycles, instruction_fetch_wait_cycles, memory_wait_cycles, taken_branches, not_taken_branches, jumps, wrong_path_instructions_flushed);
        if (!output_pass || (opcode_counts[12] != 12) || (opcode_counts[11] != 0))
            $fatal(1, "DOT4ACC Conv2 functional/profile expectation failed");
        $finish;
    end
endmodule
