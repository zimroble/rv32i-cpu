// Self-checking test helpers (in the spirit of riscv-tests).
// x28 (t3) holds the current test number. On a mismatch the program halts
// with a0 = test number; if every check passes it halts with a0 = 0.
#define TESTNUM x28

#define TEST_BEGIN          \
    .section .text.init;    \
    .globl _start;          \
_start:                     \
    li   sp, 0x10000;

#define TEST_END            \
pass:                       \
    li   a0, 0;             \
    ecall;                  \
fail:                       \
    mv   a0, TESTNUM;       \
    ecall;

// Run `code`, then check that `reg` == `expected` (uses t6 as scratch).
#define TEST_CASE(num, reg, expected, code...) \
    li   TESTNUM, num;                         \
    code;                                      \
    li   x31, expected;                        \
    bne  reg, x31, fail;

// reg-reg op: rd = rs1 op rs2
#define TEST_RR(num, inst, expected, v1, v2)   \
    TEST_CASE(num, x14, expected, li x11, v1; li x12, v2; inst x14, x11, x12)

// reg-imm op: rd = rs1 op imm
#define TEST_RI(num, inst, expected, v1, imm)  \
    TEST_CASE(num, x14, expected, li x11, v1; inst x14, x11, imm)

// Branch must be taken
#define TEST_BR_TAKEN(num, inst, v1, v2)       \
    li   TESTNUM, num;                         \
    li   x11, v1; li x12, v2;                  \
    inst x11, x12, 1f;                         \
    j    fail;                                 \
1:

// Branch must not be taken
#define TEST_BR_NOT_TAKEN(num, inst, v1, v2)   \
    li   TESTNUM, num;                         \
    li   x11, v1; li x12, v2;                  \
    inst x11, x12, fail;
