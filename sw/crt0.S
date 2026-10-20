# C runtime start-up: set up sp/gp, zero .bss, call main, then ECALL with
# main's return value in a0 (0 = pass) so the testbench can check it.
    .section .text.init
    .globl _start
_start:
    la   sp, __stack_top
    .option push
    .option norelax
    la   gp, __global_pointer$
    .option pop
    la   t0, __bss_start
    la   t1, __bss_end
1:  bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:  call main
    ecall
3:  j    3b
