// Instructions younger than ECALL must not commit: the stores below sit in
// the pipeline behind the ECALL and would print "X" if they leaked through.
#include "test_macros.h"
TEST_BEGIN
    li   x11, 0x10000000
    li   x12, 'X'
    li   a0, 0
    ecall
    sw   x12, 0(x11)
    sw   x12, 0(x11)
    sw   x12, 0(x11)
    li   a0, 1
TEST_END
