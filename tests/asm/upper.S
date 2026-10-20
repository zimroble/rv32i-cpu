// LUI and AUIPC.
#include "test_macros.h"
TEST_BEGIN

    TEST_CASE(1, x14, 0x12345000, lui x14, 0x12345)
    TEST_CASE(2, x14, 0xfffff000, lui x14, 0xfffff)
    TEST_CASE(3, x14, 0x12345678, lui x14, 0x12345; addi x14, x14, 0x678)

    // auipc: result is relative to its own PC
    li   TESTNUM, 4
1:  auipc x14, 0
    la    x15, 1b
    bne   x14, x15, fail

    li   TESTNUM, 5
2:  auipc x14, 1
    la    x15, 2b
    sub   x14, x14, x15
    li    x31, 0x1000
    bne   x14, x31, fail

TEST_END
