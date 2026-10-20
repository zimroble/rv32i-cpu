# rv32i-cpu build: simulator, test programs, and the test runner.

IVERILOG ?= iverilog
VVP      ?= vvp
CROSS    ?= riscv64-unknown-elf-
CC        = $(CROSS)gcc
OBJCOPY   = $(CROSS)objcopy
PYTHON   ?= python3

BUILD    := build
RTL      := $(wildcard rtl/*.v)
ARCH     := -march=rv32i -mabi=ilp32
ASFLAGS  := $(ARCH) -Wl,--no-warn-rwx-segments -nostdlib -nostartfiles -Itests/asm -Tsw/link.ld
CFLAGS   := $(ARCH) -Wl,--no-warn-rwx-segments -O2 -ffreestanding -nostdlib -nostartfiles -Isw -Tsw/link.ld \
            -Wall -Wextra -Werror

ASM_SRCS := $(wildcard tests/asm/*.S)
C_SRCS   := $(wildcard tests/c/*.c)
ASM_HEX  := $(patsubst tests/asm/%.S,$(BUILD)/asm/%.hex,$(ASM_SRCS))
C_HEX    := $(patsubst tests/c/%.c,$(BUILD)/c/%.hex,$(C_SRCS))

.PHONY: all sim programs test unit clean
all: test

sim: $(BUILD)/soc.vvp $(BUILD)/tb_units.vvp
programs: $(ASM_HEX) $(C_HEX)

$(BUILD)/soc.vvp: $(RTL) tb/tb_soc.v | $(BUILD)
	$(IVERILOG) -g2012 -Wall -Irtl -o $@ $(RTL) tb/tb_soc.v

$(BUILD)/tb_units.vvp: rtl/alu.v rtl/imm_gen.v rtl/regfile.v rtl/defs.vh tb/tb_units.v | $(BUILD)
	$(IVERILOG) -g2012 -Wall -Irtl -o $@ rtl/alu.v rtl/imm_gen.v rtl/regfile.v tb/tb_units.v

$(BUILD)/asm/%.elf: tests/asm/%.S tests/asm/test_macros.h sw/link.ld
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -o $@ $<

$(BUILD)/c/%.elf: tests/c/%.c sw/crt0.S sw/runtime.h sw/link.ld
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ sw/crt0.S $< -lgcc

$(BUILD)/%.hex: $(BUILD)/%.elf scripts/bin2hex.py
	$(OBJCOPY) -O binary $< $(basename $@).bin
	$(PYTHON) scripts/bin2hex.py $(basename $@).bin $@

unit: $(BUILD)/tb_units.vvp
	$(VVP) -n $<

test: sim programs
	$(VVP) -n $(BUILD)/tb_units.vvp
	$(PYTHON) scripts/run_tests.py --build $(BUILD)

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD)
