// Tiny freestanding runtime for programs running on the rv32i-cpu SoC.
#ifndef RUNTIME_H
#define RUNTIME_H

#include <stdint.h>

#define CONSOLE (*(volatile uint8_t *)0x10000000u)

static inline void putch(char c) { CONSOLE = (uint8_t)c; }

static inline void print_str(const char *s) {
    while (*s) putch(*s++);
}

static inline void print_uint(uint32_t v) {
    char buf[11];
    int i = 0;
    do { buf[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i) putch(buf[--i]);
}

static inline void print_int(int32_t v) {
    if (v < 0) { putch('-'); print_uint((uint32_t)(-(int64_t)v)); }
    else print_uint((uint32_t)v);
}

#endif
