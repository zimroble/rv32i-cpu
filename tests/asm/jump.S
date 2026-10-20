// JAL / JALR link values, targets, and the LSB-clearing rule of JALR.
#include "test_macros.h"
TEST_BEGIN

    li   TESTNUM, 1
    jal  x1, 1f
ret1:
    j    fail
1:  la   x15, ret1
    bne  x1, x15, fail

    // jalr through a register, with offset, link into a different reg
    li   TESTNUM, 2
    la   x11, target2
    jalr x5, 4(x11)
ret2:
    j    fail
target2:
    j    fail            // skipped by the +4 offset
    la   x15, ret2
    bne  x5, x15, fail

    // jalr clears bit 0 of the target
    li   TESTNUM, 3
    la   x11, target3
    addi x11, x11, 1
    jalr x0, 0(x11)
    j    fail
target3:

    // jalr where rd == rs1 must use the old rs1 value
    li   TESTNUM, 4
    la   x6, target4
    jalr x6, 0(x6)
ret4:
    j    fail
target4:
    la   x15, ret4
    bne  x6, x15, fail

    // function call / return
    li   TESTNUM, 5
    li   a1, 20
    call double_it
    li   x31, 40
    bne  a1, x31, fail

TEST_END

double_it:
    add  a1, a1, a1
    ret
