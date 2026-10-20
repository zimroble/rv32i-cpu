`timescale 1ns/1ps
`default_nettype none

// Program-level testbench. Loads a hex image, runs until the core halts
// (ECALL) or a cycle limit is hit, then reports a0 as the exit code along
// with cycle / instruction counts.
//
//   vvp sim.vvp +hex=prog.hex [+max_cycles=N] [+trace]
module tb_soc;
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;

    wire        halted, illegal_instr, console_we;
    wire [7:0]  console_data;
    wire [63:0] cycles, instret;

    soc u_soc (
        .clk(clk), .rst(rst), .halted(halted), .illegal_instr(illegal_instr),
        .cycle_count(cycles), .instret_count(instret),
        .console_we(console_we), .console_data(console_data)
    );

    reg [1023:0] hex_file;
    integer max_cycles;
    integer exit_code;

    always @(posedge clk)
        if (!rst && console_we) $write("%c", console_data);

    initial begin
        if (!$value$plusargs("hex=%s", hex_file)) begin
            $display("ERROR: pass +hex=<file>");
            $finish;
        end
        if (!$value$plusargs("max_cycles=%d", max_cycles)) max_cycles = 2_000_000;
        $readmemh(hex_file, u_soc.u_mem.mem);

        repeat (2) @(posedge clk);
        rst = 1'b0;

        while (!halted && cycles < max_cycles) @(posedge clk);
        #1;

        exit_code = u_soc.u_cpu.u_rf.regs[10];
        if (!halted)
            $display("\n[tb] TIMEOUT after %0d cycles", cycles);
        else if (illegal_instr)
            $display("\n[tb] ILLEGAL INSTRUCTION near pc=0x%08x", u_soc.u_cpu.memwb_pc);
        else
            $display("\n[tb] HALT exit=%0d cycles=%0d instret=%0d", exit_code, cycles, instret);
        $finish;
    end
endmodule

`default_nettype wire
