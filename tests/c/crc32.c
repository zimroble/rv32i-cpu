// Bitwise CRC-32 (IEEE 802.3) of a string: heavy on shifts, XOR, and branches.
#include "runtime.h"

static uint32_t crc32(const char *s) {
    uint32_t crc = 0xffffffffu;
    while (*s) {
        crc ^= (uint8_t)*s++;
        for (int k = 0; k < 8; k++)
            crc = (crc >> 1) ^ (0xedb88320u & -(crc & 1));
    }
    return ~crc;
}

static void print_hex(uint32_t v) {
    for (int i = 28; i >= 0; i -= 4) putch("0123456789abcdef"[(v >> i) & 0xf]);
}

int main(void) {
    uint32_t c = crc32("The quick brown fox jumps over the lazy dog");
    print_str("crc32 = 0x"); print_hex(c); putch('\n');
    return c == 0x414fa339u ? 0 : 1;
}
