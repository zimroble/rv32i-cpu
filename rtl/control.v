`timescale 1ns/1ps
`default_nettype none
`include "defs.vh"

// Main decoder: turns an instruction into the control signals carried
// down the pipeline. Unknown opcodes raise `illegal`.
module control (
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_sel,
    output reg         alu_src_imm,  // operand b = immediate
    output reg         alu_src_pc,   // operand a = PC (AUIPC)
    output reg  [3:0]  alu_op,
    output reg         branch,
    output reg         jal,
    output reg         jalr,
    output reg         uses_rs1,
    output reg         uses_rs2,
    output reg         halt,         // ECALL / EBREAK
    output reg         illegal
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire       f7_bit = instr[30];

    // ALU op for OP / OP-IMM, selected by funct3 (and funct7 bit 5).
    reg [3:0] arith_op;
    always @(*) begin
        case (funct3)
            3'b000: arith_op = (opcode == `OP_REG && f7_bit) ? `ALU_SUB : `ALU_ADD;
            3'b001: arith_op = `ALU_SLL;
            3'b010: arith_op = `ALU_SLT;
            3'b011: arith_op = `ALU_SLTU;
            3'b100: arith_op = `ALU_XOR;
            3'b101: arith_op = f7_bit ? `ALU_SRA : `ALU_SRL;
            3'b110: arith_op = `ALU_OR;
            default: arith_op = `ALU_AND;
        endcase
    end

    always @(*) begin
        reg_write = 1'b0; mem_read = 1'b0; mem_write = 1'b0;
        wb_sel = `WB_ALU; alu_src_imm = 1'b0; alu_src_pc = 1'b0;
        alu_op = `ALU_ADD; branch = 1'b0; jal = 1'b0; jalr = 1'b0;
        uses_rs1 = 1'b0; uses_rs2 = 1'b0; halt = 1'b0; illegal = 1'b0;

        case (opcode)
            `OP_LUI:    begin reg_write = 1; alu_src_imm = 1; alu_op = `ALU_PASSB; end
            `OP_AUIPC:  begin reg_write = 1; alu_src_imm = 1; alu_src_pc = 1; end
            `OP_JAL:    begin reg_write = 1; wb_sel = `WB_PC4; jal = 1; end
            `OP_JALR:   begin reg_write = 1; wb_sel = `WB_PC4; jalr = 1; uses_rs1 = 1; alu_src_imm = 1; end
            `OP_BRANCH: begin branch = 1; uses_rs1 = 1; uses_rs2 = 1; end
            `OP_LOAD:   begin reg_write = 1; mem_read = 1; wb_sel = `WB_MEM; alu_src_imm = 1; uses_rs1 = 1; end
            `OP_STORE:  begin mem_write = 1; alu_src_imm = 1; uses_rs1 = 1; uses_rs2 = 1; end
            `OP_IMM:    begin
                            // ADDI never subtracts (arith_op only checks bit 30 for OP),
                            // while SRAI/SRLI do use bit 30 to pick the shift.
                            reg_write = 1; alu_src_imm = 1; uses_rs1 = 1; alu_op = arith_op;
                        end
            `OP_REG:    begin reg_write = 1; uses_rs1 = 1; uses_rs2 = 1; alu_op = arith_op; end
            `OP_FENCE:  begin end // single in-order core: FENCE is a no-op
            `OP_SYSTEM: begin halt = 1; end
            default:    begin illegal = 1; end
        endcase
    end
endmodule

`default_nettype wire
