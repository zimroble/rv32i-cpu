// Byte / half / word loads and stores, sign vs zero extension,
// and every byte offset within a word.
#include "test_macros.h"
TEST_BEGIN

    la   x20, scratch

    li   x11, 0x80f17f01
    sw   x11, 0(x20)
    TEST_CASE( 1, x14, 0x80f17f01, lw  x14, 0(x20))
    TEST_CASE( 2, x14, 0x00000001, lb  x14, 0(x20))
    TEST_CASE( 3, x14, 0x0000007f, lb  x14, 1(x20))
    TEST_CASE( 4, x14, 0xfffffff1, lb  x14, 2(x20))
    TEST_CASE( 5, x14, 0xffffff80, lb  x14, 3(x20))
    TEST_CASE( 6, x14, 0x000000f1, lbu x14, 2(x20))
    TEST_CASE( 7, x14, 0x00000080, lbu x14, 3(x20))
    TEST_CASE( 8, x14, 0x00007f01, lh  x14, 0(x20))
    TEST_CASE( 9, x14, 0xffff80f1, lh  x14, 2(x20))
    TEST_CASE(10, x14, 0x000080f1, lhu x14, 2(x20))

    // byte stores only touch their own byte
    li   x11, 0
    sw   x11, 4(x20)
    li   x11, 0xaa
    sb   x11, 4(x20)
    li   x11, 0xbb
    sb   x11, 5(x20)
    li   x11, 0xcc
    sb   x11, 6(x20)
    li   x11, 0x123456dd        // upper bits must be ignored
    sb   x11, 7(x20)
    TEST_CASE(11, x14, 0xddccbbaa, lw x14, 4(x20))

    // half-word stores
    li   x11, 0xffffbeef
    sh   x11, 8(x20)
    li   x11, 0xdead
    sh   x11, 10(x20)
    TEST_CASE(12, x14, 0xdeadbeef, lw x14, 8(x20))

    // negative offsets
    addi x21, x20, 16
    li   x11, 0x5a5a5a5a
    sw   x11, -4(x21)
    TEST_CASE(13, x14, 0x5a5a5a5a, lw x14, 12(x20))

TEST_END

    .data
    .align 2
scratch:
    .space 32
