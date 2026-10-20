// Register-register and register-immediate ALU instructions, including
// sign/overflow corner cases.
#include "test_macros.h"
TEST_BEGIN

    TEST_RR( 1, add,  0x00000003, 1, 2)
    TEST_RR( 2, add,  0x80000000, 0x7fffffff, 1)          // signed overflow wraps
    TEST_RR( 3, add,  0x00000000, 0xffffffff, 1)
    TEST_RR( 4, sub,  0xffffffff, 0, 1)
    TEST_RR( 5, sub,  0x7fffffff, 0x80000000, 1)
    TEST_RR( 6, sll,  0x80000000, 1, 31)
    TEST_RR( 7, sll,  0x00000002, 1, 33)                   // only rs2[4:0] used
    TEST_RR( 8, srl,  0x00000001, 0x80000000, 31)
    TEST_RR( 9, sra,  0xffffffff, 0x80000000, 31)
    TEST_RR(10, sra,  0x00000003, 0x0000000f, 2)
    TEST_RR(11, slt,  1, -1, 0)
    TEST_RR(12, slt,  0, 0, -1)
    TEST_RR(13, sltu, 0, -1, 0)
    TEST_RR(14, sltu, 1, 0, -1)
    TEST_RR(15, xor,  0x0f0f0f0f, 0xff00ff00, 0xf00ff00f)
    TEST_RR(16, or,   0xff0fff0f, 0xff00ff00, 0xf00ff00f)
    TEST_RR(17, and,  0xf000f000, 0xff00ff00, 0xf00ff00f)

    TEST_RI(20, addi,  0x00000000, 1, -1)
    TEST_RI(21, addi,  0x800007fe, 0x7fffffff, 0x7ff)
    TEST_RI(22, slti,  1, -5, -4)
    TEST_RI(23, sltiu, 1, 5, -1)                           // imm sign-extends, then unsigned
    TEST_RI(24, xori,  0xfffff0ff, 0x00000f00, -1)
    TEST_RI(25, ori,   0x00000fff, 0x00000f00, 0xff)
    TEST_RI(26, andi,  0x00000700, 0x00000f00, 0x7ff)
    TEST_RI(27, slli,  0x00010000, 1, 16)
    TEST_RI(28, srli,  0x00ffffff, 0xffffffff, 8)
    TEST_RI(29, srai,  0xffffffff, 0xffffffff, 8)
    TEST_RI(30, srai,  0x00f00000, 0x0f000000, 4)

    // Writes to x0 are discarded
    TEST_CASE(40, x0, 0, li x11, 123; add x0, x11, x11)

TEST_END
