# rv32i-cpu

[![CI](https://github.com/zimroble/rv32i-cpu/actions/workflows/ci.yml/badge.svg)](https://github.com/zimroble/rv32i-cpu/actions/workflows/ci.yml)

A 5-stage pipelined **RISC-V RV32I** processor in synthesizable Verilog, with a
self-checking test suite of hand-written assembly and C programs compiled with GCC.

```
        ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
  PC ──▶│  IF  │──▶│  ID  │──▶│  EX  │──▶│ MEM  │──▶│  WB  │
        └──────┘   └──┬───┘   └──┬───┘   └──┬───┘   └──┬───┘
            ▲         │ load-use  │ ▲  ▲      │          │
            │         │  stall    │ │  └──────┘ EX/MEM fwd
            │         ▼           │ └─────────────────────┘ MEM/WB fwd
            └──── branch/jump redirect (flush IF, ID)
```

## Features

- **Full RV32I base ISA** (37 user-level instructions: LUI, AUIPC, JAL, JALR,
  6 branches, 5 loads, 3 stores, 9 ALU-immediate, 10 ALU-register). FENCE is a
  no-op; ECALL/EBREAK halt the core.
- **Classic 5-stage pipeline** with:
  - full forwarding from EX/MEM and MEM/WB into EX, plus a write-through
    register file that covers the WB→ID case;
  - a 1-cycle **load-use interlock** (the only data-hazard stall);
  - branches/jumps resolved in EX with **static not-taken** prediction and a
    2-instruction flush on a taken branch.
- **Precise halt**: instructions younger than an ECALL never commit.
- **Byte/half/word loads and stores** at any aligned offset, with sign/zero extension.
- **Minimal SoC**: 64 KiB unified RAM and a memory-mapped console at
  `0x1000_0000` so C programs can print.
- Cycle and retired-instruction counters for measuring CPI.

## Results

`make test` runs 2,778 unit-level checks (ALU, immediate decoder, register
file) and then 12 full programs on the simulated SoC:

| program        | cycles  | instructions | CPI  |
|----------------|--------:|-------------:|-----:|
| asm/alu        |     187 |          183 | 1.02 |
| asm/branch     |     132 |           94 | 1.40 |
| asm/halt       |       9 |            5 | 1.80 |
| asm/hazards    |      96 |           85 | 1.13 |
| asm/jump       |      50 |           34 | 1.47 |
| asm/loadstore  |      91 |           87 | 1.05 |
| asm/upper      |      33 |           29 | 1.14 |
| c/crc32        |   3,535 |        2,752 | 1.28 |
| c/fib          | 293,537 |      256,671 | 1.14 |
| c/matmul       |  41,959 |       29,938 | 1.40 |
| c/sieve        | 327,872 |      213,187 | 1.54 |
| c/sort         |  50,118 |       38,561 | 1.30 |

CPI above 1.0 comes from the load-use bubbles and the 2-cycle taken-branch
penalty. The C benchmarks are compiled with `-O2 -march=rv32i`, and
multiplication goes through libgcc's software `__mulsi3`.

The test suite was mutation-checked: disabling any forwarding path, the
load-use stall, the branch flush, or the post-ECALL store squash makes at
least one program fail.

## Layout

```
rtl/        defs.vh  alu.v  regfile.v  imm_gen.v  control.v  cpu.v  memory.v  soc.v
tb/         tb_units.v (unit tests)   tb_soc.v (program runner)
tests/asm/  self-checking assembly tests (a0 = failing test number, 0 = pass)
tests/c/    C programs (+ .expected console output)
sw/         crt0.S, linker script, tiny runtime (putch/print_*)
scripts/    bin2hex.py, run_tests.py
```

## Running it

Requirements: [Icarus Verilog](https://steveicarus.github.io/iverilog/) ≥ 11,
a RISC-V GCC cross compiler, and Python 3.9+.

```bash
# Ubuntu / Debian
sudo apt-get install iverilog gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

make test        # build simulator + programs, run everything
make unit        # unit tests only
make clean
```

Run a single program and see its console output:

```bash
make programs sim
vvp -n build/soc.vvp +hex=build/c/sieve.hex
# primes below 10000: 1229, largest: 9973
# [tb] HALT exit=0 cycles=327872 instret=213187
```

### Writing your own program

Add `tests/c/foo.c` with a `main()` that returns 0 on success (optionally add
`foo.expected` with the exact console output), then run `make test`.

## Design notes

- **Why resolve branches in EX?** It keeps the ID stage simple (no comparator
  plus forwarding network in ID) at the cost of a 2-cycle penalty on taken
  branches. A BTB/branch predictor is the natural next step.
- **Load-use detection** only fires when the consumer actually reads the
  register (`uses_rs1`/`uses_rs2` from the decoder), so `lui`/`jal` after a load
  don't stall needlessly, and loads into `x0` never stall.
- **Memory** is modelled with combinational reads for simplicity; moving to
  synchronous block RAM for FPGA would add a fetch stage register.

## Not implemented

Traps/exceptions (misaligned accesses are not checked), CSRs (Zicsr),
interrupts, and the M extension.

## License

MIT
