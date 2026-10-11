module pico_top(input wire clk, input wire resetn, output wire [31:0] debug_addr, output wire [31:0] debug_data, output wire debug_valid);
  localparam integer WORDS = 16384;
  wire trap, mem_valid, mem_instr, mem_ready;
  wire [31:0] mem_addr, mem_wdata, mem_rdata;
  wire [3:0] mem_wstrb;
  reg [31:0] mem [0:WORDS-1];
  assign mem_ready = mem_valid;
  assign mem_rdata = mem[mem_addr[15:2]];
  assign debug_addr = mem_addr;
  assign debug_data = mem_wdata;
  assign debug_valid = mem_valid;
  always @(posedge clk) if (mem_valid && |mem_wstrb) mem[mem_addr[15:2]] <= mem_wdata;
  (* DONT_TOUCH = "yes" *) picorv32 #(.ENABLE_COUNTERS(1), .ENABLE_COUNTERS64(1), .ENABLE_REGS_DUALPORT(1), .ENABLE_PCPI(0), .ENABLE_MUL(1), .ENABLE_FAST_MUL(0)) cpu (
    .clk(clk), .resetn(resetn), .trap(trap), .mem_valid(mem_valid), .mem_instr(mem_instr),
    .mem_ready(mem_ready), .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
    .irq(32'b0), .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0));
endmodule
