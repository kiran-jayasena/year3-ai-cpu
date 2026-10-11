`timescale 1ns/1ps
module tb_microblaze_elf;
  logic sys_clk = 0, sys_rst = 1;
  always #5 sys_clk = ~sys_clk;
  integer cycles = 0, result_count = 0, status_count = 0;
  reg [31:0] result16, result128, status_values [0:9];
  wire [0:31] daddr = dut.dlmb_bram_if_cntlr_BRAM_PORT_ADDR;
  wire [0:31] ddin = dut.dlmb_bram_if_cntlr_BRAM_PORT_DIN;
  wire [0:3] dwe = dut.dlmb_bram_if_cntlr_BRAM_PORT_WE;
  wire den = dut.dlmb_bram_if_cntlr_BRAM_PORT_EN;
  mb_system dut(.sys_clk(sys_clk), .sys_rst(sys_rst));
  initial begin
    repeat (10) @(posedge sys_clk); sys_rst <= 1'b0;
    forever begin
      @(posedge sys_clk); cycles = cycles + 1;
      if (den && (|dwe)) begin
        if ({daddr} == 32'h00007ffc) begin
          result_count = result_count + 1;
          if (result_count == 1) result16 = {ddin};
          if (result_count == 2) result128 = {ddin};
        end
        if ({daddr} == 32'h00007ff8) begin
          if (status_count < 10) status_values[status_count] = {ddin};
          status_count = status_count + 1;
        end
      end
      if (result_count >= 2 && status_count >= 6) begin
        $display("MB_RESULT16=%08x", result16);
        $display("MB_RESULT128=%08x", result128);
        $display("MB_TOTAL_CYCLES=%0d", cycles);
        $display("MB_N16_CYCLES=%0d", status_values[1]);
        $display("MB_N16_INSTRET=%0d", status_values[2]);
        $display("MB_N128_CYCLES=%0d", status_values[4]);
        $display("MB_N128_INSTRET=%0d", status_values[5]);
        if (result16 !== 32'hffffff96 || result128 !== 32'h00000240) $fatal(1, "golden mismatch");
        $finish;
      end
      if (cycles > 200000) $fatal(1, "MicroBlaze timeout");
    end
  end
endmodule
