`timescale 1ns/1ps
module tb_pico_dotprod;
  localparam integer WORDS = 16384;
  logic clk = 0, resetn = 0;
  always #5 clk = ~clk;
  wire trap;
  wire mem_valid, mem_instr, mem_ready;
  wire [31:0] mem_addr, mem_wdata, mem_rdata;
  wire [3:0] mem_wstrb;
  reg [31:0] mem [0:WORDS-1];
  integer i, result_count, status_count, cycles;
  reg [31:0] result16, result128, status_last, status_values [0:9];
  assign mem_ready = mem_valid;
  assign mem_rdata = mem[mem_addr[17:2]];
  picorv32 #(.ENABLE_COUNTERS(1), .ENABLE_COUNTERS64(1), .ENABLE_REGS_DUALPORT(1), .ENABLE_PCPI(0), .ENABLE_MUL(1), .ENABLE_FAST_MUL(0)) dut (
    .clk(clk), .resetn(resetn), .trap(trap), .mem_valid(mem_valid), .mem_instr(mem_instr),
    .mem_ready(mem_ready), .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
    .pcpi_valid(), .pcpi_insn(), .pcpi_rs1(), .pcpi_rs2(), .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
    .irq(32'b0), .eoi(), .trace_valid(), .trace_data());
  initial begin
    $readmemh("pico.mem", mem);
    $display("MEM0=%08x MEM9=%08x", mem[0], mem[9]);
    result_count = 0; status_count = 0; cycles = 0;
    repeat (10) @(posedge clk); resetn <= 1'b1;
    forever begin
      @(posedge clk); cycles = cycles + 1;
      if (cycles < 80 && mem_valid) $display("REQ c=%0d a=%08x i=%0d r=%0d w=%x d=%08x", cycles, mem_addr, mem_instr, mem_ready, mem_wstrb, mem_wdata);
      if (mem_valid && |mem_wstrb) begin
        if (mem_addr == 32'h00007ffc) begin
          result_count = result_count + 1;
          if (result_count == 1) result16 = mem_wdata;
          if (result_count == 2) result128 = mem_wdata;
        end
        if (mem_addr == 32'h00007ff8) begin status_last = mem_wdata; if (status_count < 10) status_values[status_count] = mem_wdata; status_count = status_count + 1; end
      end
      if (result_count >= 2 && status_count >= 6) begin
        $display("PICO_RESULT16=%08x", result16);
        $display("PICO_RESULT128=%08x", result128);
        $display("PICO_CYCLES=%0d", cycles);
        $display("PICO_N16_CYCLES=%0d", status_values[1]);
        $display("PICO_N16_INSTRET=%0d", status_values[2]);
        $display("PICO_N128_CYCLES=%0d", status_values[4]);
        $display("PICO_N128_INSTRET=%0d", status_values[5]);
        if (result16 !== 32'hffffff96 || result128 !== 32'h00000240) $fatal(1, "golden mismatch");
        $finish;
      end
      if (cycles > 200000) $fatal(1, "timeout");
    end
  end
  always @(posedge clk) if (mem_valid && |mem_wstrb) begin
    if (mem_addr[17:2] < WORDS) mem[mem_addr[17:2]] <= mem_wdata;
  end
endmodule
