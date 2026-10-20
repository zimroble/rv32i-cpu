`timescale 1ns/1ps
`default_nettype none
`include "defs.vh"

// Builds the sign-extended immediate for each RV32I instruction format.
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
    wire [6:0] opcode = instr[6:0];
    always @(*) begin
        case (opcode)
            `OP_LUI, `OP_AUIPC:            imm = {instr[31:12], 12'b0};                                          // U
            `OP_JAL:                       imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J
            `OP_BRANCH:                    imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};   // B
            `OP_STORE:                     imm = {{21{instr[31]}}, instr[30:25], instr[11:7]};                   // S
            default:                       imm = {{21{instr[31]}}, instr[30:20]};                                // I
        endcase
    end
endmodule

`default_nettype wire
