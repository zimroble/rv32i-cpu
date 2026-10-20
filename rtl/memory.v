`timescale 1ns/1ps
`default_nettype none

// Unified instruction/data RAM. Port A is a read-only instruction port,
// port B is the byte-enabled data port. Reads are combinational, writes
// are synchronous. Initialised from a $readmemh image of 32-bit words.
module memory #(
    parameter integer WORDS    = 16384,      // 64 KiB
    parameter         INIT_HEX = ""
) (
    input  wire        clk,
    input  wire [31:0] a_addr,
    output wire [31:0] a_rdata,
    input  wire [31:0] b_addr,
    input  wire [3:0]  b_wstrb,
    input  wire [31:0] b_wdata,
    output wire [31:0] b_rdata
);
    localparam integer AW = $clog2(WORDS);
    reg [31:0] mem [0:WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0013;
        if (INIT_HEX != "") $readmemh(INIT_HEX, mem);
    end

    wire [AW-1:0] a_idx = a_addr[AW+1:2];
    wire [AW-1:0] b_idx = b_addr[AW+1:2];

    assign a_rdata = mem[a_idx];
    assign b_rdata = mem[b_idx];

    always @(posedge clk) begin
        if (b_wstrb[0]) mem[b_idx][7:0]   <= b_wdata[7:0];
        if (b_wstrb[1]) mem[b_idx][15:8]  <= b_wdata[15:8];
        if (b_wstrb[2]) mem[b_idx][23:16] <= b_wdata[23:16];
        if (b_wstrb[3]) mem[b_idx][31:24] <= b_wdata[31:24];
    end
endmodule

`default_nettype wire
