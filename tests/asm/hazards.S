// Pipeline hazards: every forwarding path, load-use stalls, and hazards
// feeding branches, jumps, and store data.
#include "test_macros.h"
TEST_BEGIN

    // EX/MEM -> EX (distance 1)
    TEST_CASE(1, x14, 3, li x11, 1; addi x12, x11, 1; add x14, x12, x11)

    // MEM/WB -> EX (distance 2)
    TEST_CASE(2, x14, 6, li x11, 2; addi x12, x11, 2; nop; add x14, x12, x11)

    // WB -> ID through the register file (distance 3)
    TEST_CASE(3, x14, 8, li x11, 3; addi x12, x11, 2; nop; nop; add x14, x12, x11)

    // Most recent producer wins when two in flight write the same reg
    TEST_CASE(4, x14, 30, li x11, 10; li x11, 20; li x11, 30; mv x14, x11)

    // Chain of dependent instructions
    TEST_CASE(5, x14, 16, li x14, 1; add x14, x14, x14; add x14, x14, x14; add x14, x14, x14; add x14, x14, x14)

    la   x20, data

    // Load-use: consumer immediately after the load (1-cycle stall)
    TEST_CASE(6, x14, 43, lw x11, 0(x20); addi x14, x11, 1)

    // Load-use on rs2
    TEST_CASE(7, x14, 84, lw x11, 0(x20); add x14, x11, x11)

    // Load feeding a load address
    TEST_CASE(8, x14, 42, lw x11, 4(x20); lw x14, 0(x11))

    // Load followed by store of the loaded value (store-data forwarding)
    TEST_CASE(9, x14, 42, lw x11, 0(x20); sw x11, 8(x20); lw x14, 8(x20))

    // ALU result forwarded into store data and store address
    TEST_CASE(10, x14, 77, li x11, 77; addi x12, x20, 12; sw x11, 0(x12); lw x14, 12(x20))

    // Load-use into a branch comparison
    li   TESTNUM, 11
    lw   x11, 0(x20)
    li   x12, 42
    bne  x11, x12, fail

    // ALU result forwarded into a branch
    li   TESTNUM, 12
    li   x11, 5
    addi x11, x11, -5
    bnez x11, fail

    // Load-use into jalr target
    li   TESTNUM, 13
    lw   x11, 16(x20)
    jalr x0, 0(x11)
    j    fail
jump_ok:

    // Loads to x0 must not cause a stall or forward anything
    TEST_CASE(14, x14, 5, li x14, 5; lw x0, 0(x20); add x14, x14, x0)

TEST_END

    .data
    .align 2
data:
    .word 42
    .word data
    .word 0
    .word 0
    .word jump_ok
