// All six conditional branches, taken and not taken, signed vs unsigned.
#include "test_macros.h"
TEST_BEGIN

    TEST_BR_TAKEN     ( 1, beq,  7, 7)
    TEST_BR_NOT_TAKEN ( 2, beq,  7, 8)
    TEST_BR_TAKEN     ( 3, bne,  7, 8)
    TEST_BR_NOT_TAKEN ( 4, bne,  7, 7)
    TEST_BR_TAKEN     ( 5, blt,  -1, 0)
    TEST_BR_NOT_TAKEN ( 6, blt,  0, -1)
    TEST_BR_TAKEN     ( 7, bge,  0, -1)
    TEST_BR_TAKEN     ( 8, bge,  3, 3)
    TEST_BR_NOT_TAKEN ( 9, bge,  -2, -1)
    TEST_BR_TAKEN     (10, bltu, 0, -1)
    TEST_BR_NOT_TAKEN (11, bltu, -1, 0)
    TEST_BR_TAKEN     (12, bgeu, -1, 0)
    TEST_BR_NOT_TAKEN (13, bgeu, 0, -1)

    // Instructions after a taken branch must be squashed
    li   TESTNUM, 14
    li   x14, 0
    beq  x0, x0, 1f
    addi x14, x14, 1
    addi x14, x14, 1
1:  bnez x14, fail

    // Backward branch loop: sum 1..10
    li   TESTNUM, 15
    li   x11, 10
    li   x14, 0
2:  add  x14, x14, x11
    addi x11, x11, -1
    bnez x11, 2b
    li   x31, 55
    bne  x14, x31, fail

TEST_END
