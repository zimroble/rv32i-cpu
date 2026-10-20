// 8x8 integer matrix multiply. RV32I has no MUL instruction, so the
// compiler emits calls to libgcc's software __mulsi3.
#include "runtime.h"

#define N 8
static int32_t A[N][N], B[N][N], C[N][N];

int main(void) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) { A[i][j] = i + j; B[i][j] = 3 * i - j + 1; }

    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int32_t s = 0;
            for (int k = 0; k < N; k++) s += A[i][k] * B[k][j];
            C[i][j] = s;
        }

    int32_t trace = 0;
    for (int i = 0; i < N; i++) trace += C[i][i];
    print_str("trace(A*B) = "); print_int(trace); putch('\n');
    return trace == 4256 ? 0 : 1;
}
