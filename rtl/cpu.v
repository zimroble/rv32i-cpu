`timescale 1ns/1ps
`default_nettype none
`include "defs.vh"

// Classic 5-stage in-order RV32I pipeline: IF -> ID -> EX -> MEM -> WB.
//
//  * Full forwarding from EX/MEM and MEM/WB into EX; the register file
//    bypasses WB -> ID, so the only data-hazard stall is load-use (1 cycle).
//  * Branches and jumps resolve in EX with static not-taken prediction:
//    a taken branch/jump flushes the two younger instructions (2-cycle penalty).
//  * ECALL/EBREAK halt the core once they reach WB, after all older
//    instructions have retired.
module cpu #(
    parameter [31:0] RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst,

    // Instruction port (combinational read)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data port (combinational read, synchronous byte-enabled write)
    output wire [31:0] dmem_addr,
    output wire        dmem_re,
    output wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,

    output reg         halted,
    output reg         illegal_instr,
    output reg  [63:0] cycle_count,
    output reg  [63:0] instret_count
);
    localparam [31:0] NOP = 32'h0000_0013; // addi x0, x0, 0

    // ------------------------------------------------------------------
    // Hazard / redirect signals (driven later in the file)
    // ------------------------------------------------------------------
    wire        stall;          // load-use hazard: hold PC and IF/ID
    wire        redirect;       // taken branch / jump resolved in EX
    wire [31:0] redirect_pc;

    // ==================================================================
    // IF
    // ==================================================================
    reg  [31:0] pc;
    assign imem_addr = pc;

    always @(posedge clk) begin
        if (rst)             pc <= RESET_PC;
        else if (halted)     pc <= pc;
        else if (redirect)   pc <= redirect_pc;
        else if (!stall)     pc <= pc + 32'd4;
    end

    // IF/ID
    reg  [31:0] ifid_pc, ifid_instr;
    reg         ifid_valid;

    always @(posedge clk) begin
        if (rst || redirect) begin
            ifid_pc <= 32'b0; ifid_instr <= NOP; ifid_valid <= 1'b0;
        end else if (!stall && !halted) begin
            ifid_pc <= pc; ifid_instr <= imem_rdata; ifid_valid <= 1'b1;
        end
    end

    // ==================================================================
    // ID
    // ==================================================================
    wire [4:0] id_rs1 = ifid_instr[19:15];
    wire [4:0] id_rs2 = ifid_instr[24:20];
    wire [4:0] id_rd  = ifid_instr[11:7];
    wire [2:0] id_funct3 = ifid_instr[14:12];

    wire        c_reg_write, c_mem_read, c_mem_write, c_alu_src_imm, c_alu_src_pc;
    wire        c_branch, c_jal, c_jalr, c_uses_rs1, c_uses_rs2, c_halt, c_illegal;
    wire [1:0]  c_wb_sel;
    wire [3:0]  c_alu_op;

    control u_control (
        .instr(ifid_instr),
        .reg_write(c_reg_write), .mem_read(c_mem_read), .mem_write(c_mem_write),
        .wb_sel(c_wb_sel), .alu_src_imm(c_alu_src_imm), .alu_src_pc(c_alu_src_pc),
        .alu_op(c_alu_op), .branch(c_branch), .jal(c_jal), .jalr(c_jalr),
        .uses_rs1(c_uses_rs1), .uses_rs2(c_uses_rs2), .halt(c_halt), .illegal(c_illegal)
    );

    wire [31:0] id_imm;
    imm_gen u_imm (.instr(ifid_instr), .imm(id_imm));

    // WB-stage write port (declared here, driven in WB)
    wire        wb_we;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;
    wire [31:0] id_rd1, id_rd2;

    regfile u_rf (
        .clk(clk), .rs1(id_rs1), .rs2(id_rs2), .rd1(id_rd1), .rd2(id_rd2),
        .we(wb_we), .rd(wb_rd), .wd(wb_data)
    );

    // ID/EX
    reg [31:0] idex_pc, idex_rs1_val, idex_rs2_val, idex_imm;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg [2:0]  idex_funct3;
    reg [3:0]  idex_alu_op;
    reg [1:0]  idex_wb_sel;
    reg        idex_valid, idex_reg_write, idex_mem_read, idex_mem_write;
    reg        idex_alu_src_imm, idex_alu_src_pc, idex_branch, idex_jal, idex_jalr;
    reg        idex_halt, idex_illegal;

    // Load-use hazard: the instruction in EX is a load whose result the
    // instruction in ID needs. Insert one bubble.
    assign stall = idex_valid && idex_mem_read && idex_rd != 5'd0 &&
                   ifid_valid &&
                   ((c_uses_rs1 && id_rs1 == idex_rd) || (c_uses_rs2 && id_rs2 == idex_rd));

    wire id_bubble = rst || redirect || stall || !ifid_valid;

    always @(posedge clk) begin
        if (halted) begin
            // freeze
        end else if (id_bubble) begin
            idex_valid <= 1'b0; idex_reg_write <= 1'b0; idex_mem_read <= 1'b0;
            idex_mem_write <= 1'b0; idex_branch <= 1'b0; idex_jal <= 1'b0;
            idex_jalr <= 1'b0; idex_halt <= 1'b0; idex_illegal <= 1'b0;
            idex_rd <= 5'd0; idex_rs1 <= 5'd0; idex_rs2 <= 5'd0;
        end else begin
            idex_valid <= 1'b1;
            idex_pc <= ifid_pc;
            idex_rs1_val <= id_rd1; idex_rs2_val <= id_rd2; idex_imm <= id_imm;
            idex_rs1 <= c_uses_rs1 ? id_rs1 : 5'd0;
            idex_rs2 <= c_uses_rs2 ? id_rs2 : 5'd0;
            idex_rd  <= c_reg_write ? id_rd : 5'd0;
            idex_funct3 <= id_funct3; idex_alu_op <= c_alu_op; idex_wb_sel <= c_wb_sel;
            idex_reg_write <= c_reg_write; idex_mem_read <= c_mem_read; idex_mem_write <= c_mem_write;
            idex_alu_src_imm <= c_alu_src_imm; idex_alu_src_pc <= c_alu_src_pc;
            idex_branch <= c_branch; idex_jal <= c_jal; idex_jalr <= c_jalr;
            idex_halt <= c_halt; idex_illegal <= c_illegal;
        end
    end

    // ==================================================================
    // EX
    // ==================================================================
    // EX/MEM and MEM/WB registers (declared early for forwarding)
    reg [31:0] exmem_pc, exmem_alu, exmem_store_val;
    reg [4:0]  exmem_rd;
    reg [2:0]  exmem_funct3;
    reg [1:0]  exmem_wb_sel;
    reg        exmem_valid, exmem_reg_write, exmem_mem_read, exmem_mem_write;
    reg        exmem_halt, exmem_illegal;

    reg [31:0] memwb_pc, memwb_alu, memwb_load;
    reg [4:0]  memwb_rd;
    reg [1:0]  memwb_wb_sel;
    reg        memwb_valid, memwb_reg_write, memwb_halt, memwb_illegal;

    // Value that EX/MEM will write back (never a load: load-use stalls).
    wire [31:0] exmem_fwd = (exmem_wb_sel == `WB_PC4) ? exmem_pc + 32'd4 : exmem_alu;

    wire fwd_a_mem = exmem_reg_write && exmem_rd != 5'd0 && exmem_rd == idex_rs1;
    wire fwd_a_wb  = wb_we           && wb_rd    != 5'd0 && wb_rd    == idex_rs1;
    wire fwd_b_mem = exmem_reg_write && exmem_rd != 5'd0 && exmem_rd == idex_rs2;
    wire fwd_b_wb  = wb_we           && wb_rd    != 5'd0 && wb_rd    == idex_rs2;

    wire [31:0] ex_rs1 = fwd_a_mem ? exmem_fwd : fwd_a_wb ? wb_data : idex_rs1_val;
    wire [31:0] ex_rs2 = fwd_b_mem ? exmem_fwd : fwd_b_wb ? wb_data : idex_rs2_val;

    wire [31:0] alu_a = idex_alu_src_pc  ? idex_pc  : ex_rs1;
    wire [31:0] alu_b = idex_alu_src_imm ? idex_imm : ex_rs2;
    wire [31:0] alu_y;

    alu u_alu (.a(alu_a), .b(alu_b), .op(idex_alu_op), .y(alu_y));

    reg branch_taken;
    always @(*) begin
        case (idex_funct3)
            3'b000:  branch_taken = (ex_rs1 == ex_rs2);                    // BEQ
            3'b001:  branch_taken = (ex_rs1 != ex_rs2);                    // BNE
            3'b100:  branch_taken = ($signed(ex_rs1) <  $signed(ex_rs2));  // BLT
            3'b101:  branch_taken = ($signed(ex_rs1) >= $signed(ex_rs2));  // BGE
            3'b110:  branch_taken = (ex_rs1 <  ex_rs2);                    // BLTU
            3'b111:  branch_taken = (ex_rs1 >= ex_rs2);                    // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    assign redirect = idex_valid && !halted &&
                      (idex_jal || idex_jalr || (idex_branch && branch_taken));
    assign redirect_pc = idex_jalr ? ((ex_rs1 + idex_imm) & ~32'd1)
                                   : (idex_pc + idex_imm);

    always @(posedge clk) begin
        if (rst) begin
            exmem_valid <= 1'b0; exmem_reg_write <= 1'b0; exmem_mem_read <= 1'b0;
            exmem_mem_write <= 1'b0; exmem_halt <= 1'b0; exmem_illegal <= 1'b0;
            exmem_rd <= 5'd0;
        end else if (!halted) begin
            exmem_valid <= idex_valid;
            exmem_pc <= idex_pc; exmem_alu <= alu_y; exmem_store_val <= ex_rs2;
            exmem_rd <= idex_rd; exmem_funct3 <= idex_funct3; exmem_wb_sel <= idex_wb_sel;
            exmem_reg_write <= idex_reg_write; exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write;
            exmem_halt <= idex_halt; exmem_illegal <= idex_illegal;
        end
    end

    // ==================================================================
    // MEM
    // ==================================================================
    wire [1:0] byte_off = exmem_alu[1:0];

    assign dmem_addr  = {exmem_alu[31:2], 2'b00};
    assign dmem_re    = exmem_valid && exmem_mem_read;

    reg [3:0]  wstrb;
    reg [31:0] wdata;
    always @(*) begin
        case (exmem_funct3[1:0])
            2'b00:   begin wstrb = 4'b0001 << byte_off;           wdata = {4{exmem_store_val[7:0]}};  end // SB
            2'b01:   begin wstrb = 4'b0011 << {byte_off[1], 1'b0}; wdata = {2{exmem_store_val[15:0]}}; end // SH
            default: begin wstrb = 4'b1111;                       wdata = exmem_store_val;            end // SW
        endcase
    end
    // A store that is younger than an ECALL sitting in WB must not commit.
    wire halt_in_wb = memwb_valid && (memwb_halt || memwb_illegal);
    assign dmem_wstrb = (exmem_valid && exmem_mem_write && !halted && !halt_in_wb) ? wstrb : 4'b0000;
    assign dmem_wdata = wdata;

    reg [31:0] load_val;
    wire [31:0] shifted = dmem_rdata >> {byte_off, 3'b000};
    always @(*) begin
        case (exmem_funct3)
            3'b000:  load_val = {{24{shifted[7]}},  shifted[7:0]};   // LB
            3'b001:  load_val = {{16{shifted[15]}}, shifted[15:0]};  // LH
            3'b100:  load_val = {24'b0, shifted[7:0]};               // LBU
            3'b101:  load_val = {16'b0, shifted[15:0]};              // LHU
            default: load_val = dmem_rdata;                          // LW
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            memwb_valid <= 1'b0; memwb_reg_write <= 1'b0; memwb_halt <= 1'b0;
            memwb_illegal <= 1'b0; memwb_rd <= 5'd0;
        end else if (!halted) begin
            memwb_valid <= exmem_valid;
            memwb_pc <= exmem_pc; memwb_alu <= exmem_alu; memwb_load <= load_val;
            memwb_rd <= exmem_rd; memwb_wb_sel <= exmem_wb_sel;
            memwb_reg_write <= exmem_reg_write;
            memwb_halt <= exmem_halt; memwb_illegal <= exmem_illegal;
        end
    end

    // ==================================================================
    // WB
    // ==================================================================
    assign wb_we   = memwb_valid && memwb_reg_write && !halted;
    assign wb_rd   = memwb_rd;
    assign wb_data = (memwb_wb_sel == `WB_MEM) ? memwb_load :
                     (memwb_wb_sel == `WB_PC4) ? memwb_pc + 32'd4 : memwb_alu;

    always @(posedge clk) begin
        if (rst) begin
            halted <= 1'b0; illegal_instr <= 1'b0;
            cycle_count <= 64'd0; instret_count <= 64'd0;
        end else if (!halted) begin
            cycle_count <= cycle_count + 64'd1;
            if (memwb_valid) begin
                instret_count <= instret_count + 64'd1;
                if (memwb_halt || memwb_illegal) halted <= 1'b1;
                if (memwb_illegal) illegal_instr <= 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
