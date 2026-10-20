// Sieve of Eratosthenes: counts the primes below 10000 using byte arrays.
#include "runtime.h"

#define LIMIT 10000
static uint8_t composite[LIMIT];

int main(void) {
    uint32_t count = 0, last = 0;
    for (uint32_t i = 2; i < LIMIT; i++) {
        if (composite[i]) continue;
        count++; last = i;
        for (uint32_t j = i * i; j < LIMIT; j += i) composite[j] = 1;
    }
    print_str("primes below 10000: "); print_uint(count);
    print_str(", largest: "); print_uint(last); putch('\n');
    return (count == 1229 && last == 9973) ? 0 : 1;
}
