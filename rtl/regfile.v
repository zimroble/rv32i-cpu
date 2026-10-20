`timescale 1ns/1ps
`default_nettype none

// 32 x 32-bit register file, two read ports and one write port.
// x0 is hard-wired to zero. A write in the same cycle as a read of the
// same register is bypassed to the read port (write-before-read), which
// removes the WB->ID hazard from the pipeline.
module regfile (
    input  wire        clk,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    input  wire        we,
    input  wire [4:0]  rd,
    input  wire [31:0] wd
);
    reg [31:0] regs [1:31];

    integer i;
    initial for (i = 1; i < 32; i = i + 1) regs[i] = 32'b0;

    always @(posedge clk)
        if (we && rd != 5'd0) regs[rd] <= wd;

    assign rd1 = (rs1 == 5'd0) ? 32'b0 : (we && rd == rs1) ? wd : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : (we && rd == rs2) ? wd : regs[rs2];
endmodule

`default_nettype wire
