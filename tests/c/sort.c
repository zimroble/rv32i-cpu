// Quicksort of a pseudo-random array (xorshift PRNG), then verify order.
#include "runtime.h"

#define N 256
static int32_t a[N];

static uint32_t xorshift(uint32_t *s) {
    uint32_t x = *s;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    return *s = x;
}

static void quicksort(int32_t *v, int lo, int hi) {
    while (lo < hi) {
        int32_t pivot = v[(lo + hi) / 2];
        int i = lo, j = hi;
        while (i <= j) {
            while (v[i] < pivot) i++;
            while (v[j] > pivot) j--;
            if (i <= j) { int32_t t = v[i]; v[i] = v[j]; v[j] = t; i++; j--; }
        }
        if (j - lo < hi - i) { quicksort(v, lo, j); lo = i; }
        else                 { quicksort(v, i, hi); hi = j; }
    }
}

int main(void) {
    uint32_t seed = 0x12345678u;
    int64_t sum_before = 0, sum_after = 0;
    for (int i = 0; i < N; i++) { a[i] = (int32_t)xorshift(&seed); sum_before += a[i]; }

    quicksort(a, 0, N - 1);

    for (int i = 0; i < N; i++) sum_after += a[i];
    for (int i = 1; i < N; i++)
        if (a[i - 1] > a[i]) { print_str("not sorted\n"); return 1; }
    if (sum_before != sum_after) { print_str("checksum mismatch\n"); return 2; }

    print_str("sorted "); print_uint(N); print_str(" ints, min=");
    print_int(a[0]); print_str(" max="); print_int(a[N - 1]); putch('\n');
    return 0;
}
