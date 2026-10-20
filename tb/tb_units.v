`timescale 1ns/1ps
`default_nettype none
`include "defs.vh"

// Unit tests for the ALU, immediate generator and register file,
// checked against independently computed reference values.
module tb_units;
    integer errors = 0;
    integer checks = 0;

    task check(input [255:0] what, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: got %08x expected %08x", what, got, exp);
            end
        end
    endtask

    // ---------------- ALU ----------------
    reg  [31:0] a, b;
    reg  [3:0]  op;
    wire [31:0] y;
    alu u_alu (.a(a), .b(b), .op(op), .y(y));

    function [31:0] ref_alu(input [3:0] o, input [31:0] x, input [31:0] z);
        case (o)
            `ALU_ADD:   ref_alu = x + z;
            `ALU_SUB:   ref_alu = x - z;
            `ALU_SLL:   ref_alu = x << z[4:0];
            `ALU_SLT:   ref_alu = ($signed(x) < $signed(z)) ? 1 : 0;
            `ALU_SLTU:  ref_alu = (x < z) ? 1 : 0;
            `ALU_XOR:   ref_alu = x ^ z;
            `ALU_SRL:   ref_alu = x >> z[4:0];
            `ALU_SRA:   ref_alu = (x >> z[4:0]) | (x[31] ? ~(32'hffffffff >> z[4:0]) : 32'b0);
            `ALU_OR:    ref_alu = x | z;
            `ALU_AND:   ref_alu = x & z;
            `ALU_PASSB: ref_alu = z;
            default:    ref_alu = 0;
        endcase
    endfunction

    // ---------------- imm_gen ----------------
    reg  [31:0] instr;
    wire [31:0] imm;
    imm_gen u_imm (.instr(instr), .imm(imm));

    // ---------------- regfile ----------------
    reg         clk = 0;
    reg  [4:0]  rs1, rs2, rd;
    reg         we;
    reg  [31:0] wd;
    wire [31:0] rd1, rd2;
    regfile u_rf (.clk(clk), .rs1(rs1), .rs2(rs2), .rd1(rd1), .rd2(rd2), .we(we), .rd(rd), .wd(wd));

    integer i, o;
    reg [31:0] corner [0:7];

    initial begin
        // ALU: corner values x every op, plus random vectors
        corner[0] = 32'h0000_0000; corner[1] = 32'h0000_0001; corner[2] = 32'hffff_ffff;
        corner[3] = 32'h7fff_ffff; corner[4] = 32'h8000_0000; corner[5] = 32'h0000_001f;
        corner[6] = 32'h0000_0020; corner[7] = 32'hdead_beef;
        for (o = 0; o <= 10; o = o + 1)
            for (i = 0; i < 64; i = i + 1) begin
                op = o; a = corner[i / 8]; b = corner[i % 8]; #1;
                check("alu corner", y, ref_alu(op, a, b));
            end
        for (i = 0; i < 2000; i = i + 1) begin
            op = $urandom % 11; a = $urandom; b = $urandom; #1;
            check("alu random", y, ref_alu(op, a, b));
        end

        // imm_gen: one hand-encoded instruction per format
        instr = 32'hfff00093; #1; check("I addi x1,x0,-1",        imm, 32'hffff_ffff);
        instr = 32'h7ff00093; #1; check("I addi x1,x0,2047",      imm, 32'h0000_07ff);
        instr = 32'hfe112e23; #1; check("S sw x1,-4(x2)",         imm, 32'hffff_fffc);
        instr = 32'h00208463; #1; check("B beq x1,x2,+8",         imm, 32'h0000_0008);
        instr = 32'hfe208ee3; #1; check("B beq x1,x2,-4",         imm, 32'hffff_fffc);
        instr = 32'h123450b7; #1; check("U lui x1,0x12345",       imm, 32'h1234_5000);
        instr = 32'h008000ef; #1; check("J jal x1,+8",            imm, 32'h0000_0008);
        instr = 32'hffdff0ef; #1; check("J jal x1,-4",            imm, 32'hffff_fffc);
        instr = 32'h800000ef; #1; check("J jal x1,-1MiB",         imm, 32'hfff0_0000);

        // regfile: x0 stays zero, write/read, same-cycle bypass
        we = 1; rd = 0; wd = 32'hffff_ffff; rs1 = 0; rs2 = 0;
        #1 clk = 1; #1 clk = 0;
        check("x0 write ignored", rd1, 0);
        for (i = 1; i < 32; i = i + 1) begin
            rd = i; wd = i * 32'h0101_0101; #1 clk = 1; #1 clk = 0;
        end
        we = 0;
        for (i = 1; i < 32; i = i + 1) begin
            rs1 = i; rs2 = 32 - i; #1;
            check("rf read rs1", rd1, i * 32'h0101_0101);
            check("rf read rs2", rd2, (32 - i) * 32'h0101_0101);
        end
        we = 1; rd = 5; wd = 32'hcafe_f00d; rs1 = 5; rs2 = 0; #1;
        check("rf write bypass", rd1, 32'hcafe_f00d);
        check("rf bypass x0",    rd2, 0);

        if (errors == 0) $display("unit tests: %0d checks passed", checks);
        else             $display("unit tests: %0d/%0d checks FAILED", errors, checks);
        if (errors != 0) $fatal(1);
        $finish;
    end
endmodule

`default_nettype wire
