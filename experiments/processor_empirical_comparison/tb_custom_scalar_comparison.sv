import cpu_defs_pkg::*;

module tb_custom_scalar_comparison;
`ifdef N16
    localparam string IMEM_FILE = "experiments/processor_empirical_comparison/n16/custom_scalar.mem";
    localparam string DATA_FILE = "experiments/processor_empirical_comparison/n16/custom_data.mem";
    localparam int EXPECTED = 32'hffff_ff96;
`else
    localparam string IMEM_FILE = "experiments/processor_empirical_comparison/n128/custom_scalar.mem";
    localparam string DATA_FILE = "experiments/processor_empirical_comparison/n128/custom_data.mem";
    localparam int EXPECTED = 32'h0000_0240;
`endif
    localparam int MAX_CYCLES = 200000;

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
    integer opcode_counts [0:15];
    integer multiply_emulation_instructions;
    integer cycle_count;
    integer i;
    logic pass;

    always #5 clk = ~clk;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(256), .DMEM_DEPTH(256), .IMEM_INIT_FILE(IMEM_FILE)
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
    );

    initial begin
        $readmemh(DATA_FILE, dut.data_mem_inst.mem);
        for (i = 0; i < 16; i = i + 1) opcode_counts[i] = 0;
        multiply_emulation_instructions = 0;
        rst = 1'b1;
        enable = 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        enable = 1'b1;
        cycle_count = 0;
        while (cycle_count < MAX_CYCLES) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (retire_valid) begin
                opcode_counts[retire_opcode] = opcode_counts[retire_opcode] + 1;
                // The generated metadata marks the fixed N=16 repeated-add /
                // subtract PCs and the N=128 inner multiply loop. The range
                // test below is replaced by the generated case list for N=16.
`ifdef N16
                case (retire_pc >> 2)
                    8,9,10,17,18,19,20,27,34,35,42,43,50,51,52,53,54,
                    61,62,63,64,65,66,73,74,75,82,83,84,85,92,93,94,95,
                    96,97,98,105,106,107,108,109,110,111,112,119,126,127,
                    134,135,136,137,138,145,146,147,148,149,150,151,152,153,160:
                        multiply_emulation_instructions = multiply_emulation_instructions + 1;
                    default: ;
                endcase
`else
                if ((retire_pc >> 2) >= 12 && (retire_pc >> 2) <= 15)
                    multiply_emulation_instructions = multiply_emulation_instructions + 1;
`endif
            end
            if (retire_valid && retire_mem_write && (retire_mem_addr == 32'd0)) break;
        end
        enable = 1'b0;
        pass = (dut.data_mem_inst.mem[0] === EXPECTED);
        $display("CUSTOM_CASE=%s cycles=%0d retired=%0d pass=%0d multiply_instructions=%0d", IMEM_FILE, total_cycles, retired_instructions, pass, multiply_emulation_instructions);
        $display("COUNTERS loads=%0d stores=%0d branches_taken=%0d branches_not_taken=%0d jumps=%0d control_flush=%0d fetch_wait=%0d memory_wait=%0d data_hazard=%0d load_use=%0d", opcode_counts[7], opcode_counts[8], taken_branches, not_taken_branches, jumps, control_hazard_flush_cycles, instruction_fetch_wait_cycles, memory_wait_cycles, data_hazard_stall_cycles, load_use_stall_cycles);
        $display("OPCODES add=%0d sub=%0d addi=%0d load=%0d store=%0d beq=%0d jump=%0d", opcode_counts[1], opcode_counts[2], opcode_counts[6], opcode_counts[7], opcode_counts[8], opcode_counts[9], opcode_counts[10]);
        if (!pass) $fatal(1, "custom scalar result mismatch: expected %h got %h", EXPECTED, dut.data_mem_inst.mem[0]);
        if (cycle_count >= MAX_CYCLES) $fatal(1, "custom scalar timeout");
        $finish;
    end
endmodule
