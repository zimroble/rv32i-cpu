`timescale 1ns/1ps
`default_nettype none

// Minimal system: CPU + 64 KiB RAM at 0x0000_0000 + a write-only console
// register at 0x1000_0000 (each byte stored there is printed by the
// simulator, which lets C programs call putchar()).
module soc #(
    parameter INIT_HEX = ""
) (
    input  wire        clk,
    input  wire        rst,
    output wire        halted,
    output wire        illegal_instr,
    output wire [63:0] cycle_count,
    output wire [63:0] instret_count,
    output wire        console_we,
    output wire [7:0]  console_data
);
    localparam [31:0] CONSOLE_ADDR = 32'h1000_0000;

    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata, ram_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_re;

    cpu u_cpu (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_re(dmem_re), .dmem_wstrb(dmem_wstrb),
        .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
        .halted(halted), .illegal_instr(illegal_instr),
        .cycle_count(cycle_count), .instret_count(instret_count)
    );

    wire is_console = (dmem_addr == CONSOLE_ADDR);
    wire is_ram     = (dmem_addr[31:16] == 16'h0000);

    memory #(.INIT_HEX(INIT_HEX)) u_mem (
        .clk(clk),
        .a_addr(imem_addr), .a_rdata(imem_rdata),
        .b_addr(dmem_addr), .b_wstrb(is_ram ? dmem_wstrb : 4'b0000),
        .b_wdata(dmem_wdata), .b_rdata(ram_rdata)
    );

    assign dmem_rdata   = is_ram ? ram_rdata : 32'b0;
    assign console_we   = is_console && dmem_wstrb[0];
    assign console_data = dmem_wdata[7:0];
endmodule

`default_nettype wire
