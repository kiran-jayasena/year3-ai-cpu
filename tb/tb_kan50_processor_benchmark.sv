import cpu_defs_pkg::*;

module tb_kan50_processor_benchmark;
    localparam int IMEM_DEPTH = 256;
    localparam int DMEM_DEPTH = 256;
    localparam int RUNS = 5;
    localparam int OUTPUT_BASE_WORD = 109;
    localparam int SENTINEL_ADDR = (OUTPUT_BASE_WORD + 4) * 4;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic enable = 1'b0;
    logic retire_valid;
    logic [31:0] retire_mem_addr;
    logic retire_mem_write;
    logic [31:0] total_cycles;
    logic [31:0] retired_instructions;
    logic [31:0] fetch_pc;
    logic [31:0] instruction_addr;
    logic [31:0] fetch_request_pc;
    logic fetch_request_valid;
    logic if_id_valid;
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instruction;
    logic [3:0] decoded_opcode;
    logic decoded_valid;
    logic id_ex_valid;
    logic ex_mem_valid;
    logic mem_wb_valid;
    logic [31:0] alu_result;
    logic [31:0] data_addr;
    logic [31:0] memory_read_data;
    logic [3:0] retire_opcode;
    logic [4:0] retire_rd;
    logic retire_reg_write;
    logic [31:0] retire_write_data;
    logic reg_write;
    logic mem_write;
    logic pc_redirect;
    logic [31:0] expected [0:3];
    integer report_file;
    integer run_id;
    integer index;
    integer cycles_at_end;
    integer retired_at_end;
    integer timeout;
    bit all_pass;
    bit output_pass;

    always #5 clk = ~clk;

    cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 #(
        .IMEM_DEPTH(IMEM_DEPTH),
        .DMEM_DEPTH(DMEM_DEPTH),
        .IMEM_INIT_FILE("programs/kan50_conv2_tile.mem")
    ) dut (
        .clk(clk), .rst(rst), .enable(enable),
        .fetch_pc(fetch_pc), .instruction_addr(instruction_addr),
        .fetch_request_pc(fetch_request_pc), .fetch_request_valid(fetch_request_valid),
        .if_id_valid(if_id_valid), .if_id_pc(if_id_pc), .if_id_instruction(if_id_instruction),
        .decoded_opcode(decoded_opcode), .decoded_valid(decoded_valid),
        .id_ex_valid(id_ex_valid), .ex_mem_valid(ex_mem_valid), .mem_wb_valid(mem_wb_valid),
        .alu_result(alu_result), .data_addr(data_addr), .memory_read_data(memory_read_data),
        .retire_valid(retire_valid), .retire_mem_addr(retire_mem_addr),
        .retire_mem_write(retire_mem_write), .retire_opcode(retire_opcode),
        .retire_rd(retire_rd), .retire_reg_write(retire_reg_write),
        .retire_write_data(retire_write_data), .reg_write(reg_write), .mem_write(mem_write),
        .pc_redirect(pc_redirect), .total_cycles(total_cycles),
        .retired_instructions(retired_instructions)
    );

    initial begin
        $readmemh("programs/kan50_conv2_tile_golden.mem", expected);
        report_file = $fopen("reports/kan50_processor_benchmark/repeated_runs.csv", "w");
        if (report_file == 0) $fatal(1, "could not open KAN-50 result CSV");
        $fdisplay(report_file, "run,output0,output1,output2,output3,cycles,retired,output_pass");
        all_pass = 1'b1;

        for (run_id = 1; run_id <= RUNS; run_id = run_id + 1) begin
            $readmemh("programs/kan50_conv2_tile_data.mem", dut.data_mem_inst.mem);
            rst = 1'b1;
            enable = 1'b0;
            repeat (3) @(posedge clk);
            rst = 1'b0;
            repeat (2) @(posedge clk);
            enable = 1'b1;
            timeout = 0;
            while (1) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
                if (retire_valid && retire_mem_write && (retire_mem_addr == SENTINEL_ADDR)) begin
                    break;
                end
                if (timeout > 20000) $fatal(1, "KAN-50 benchmark timeout on run %0d", run_id);
            end
            cycles_at_end = total_cycles;
            retired_at_end = retired_instructions;
            enable = 1'b0;
            output_pass = 1'b1;
            for (index = 0; index < 4; index = index + 1) begin
                if (dut.data_mem_inst.mem[OUTPUT_BASE_WORD + index] !== expected[index]) begin
                    output_pass = 1'b0;
                    $display("KAN50 mismatch run=%0d output=%0d expected=%0d actual=%0d", run_id,
                             index, $signed(expected[index]), $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + index]));
                end
            end
            if (!output_pass) all_pass = 1'b0;
            $fdisplay(report_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%s", run_id,
                      $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 0]),
                      $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 1]),
                      $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 2]),
                      $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 3]),
                      cycles_at_end, retired_at_end, output_pass ? "PASS" : "FAIL");
            $display("KAN50 run=%0d outputs=[%0d,%0d,%0d,%0d] cycles=%0d retired=%0d %s", run_id,
                     $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 0]),
                     $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 1]),
                     $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 2]),
                     $signed(dut.data_mem_inst.mem[OUTPUT_BASE_WORD + 3]),
                     cycles_at_end, retired_at_end, output_pass ? "PASS" : "FAIL");
        end
        $fclose(report_file);
        if (!all_pass) $fatal(1, "KAN-50 representative benchmark failed");
        $display("KAN-50 representative benchmark PASSED");
        $finish;
    end
endmodule
