// Recursive Fibonacci: exercises deep call/return chains and stack traffic.
#include "runtime.h"

static uint32_t fib(uint32_t n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }

int main(void) {
    for (uint32_t i = 0; i <= 15; i++) {
        print_uint(fib(i));
        putch(i == 15 ? '\n' : ' ');
    }
    return fib(20) == 6765 ? 0 : 1;
}
