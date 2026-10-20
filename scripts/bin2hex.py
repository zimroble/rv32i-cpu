#!/usr/bin/env python3
"""Convert a flat little-endian binary into a $readmemh image of 32-bit words.

The image is zero-padded to the full RAM size so $readmemh fills every word.
"""
import sys

RAM_WORDS = 16384  # must match memory.v (64 KiB)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <in.bin> <out.hex>")
    data = open(sys.argv[1], "rb").read()
    data += b"\x00" * (-len(data) % 4)
    if len(data) > RAM_WORDS * 4:
        sys.exit(f"{sys.argv[1]}: image is {len(data)} bytes, RAM is {RAM_WORDS * 4}")
    data += b"\x00" * (RAM_WORDS * 4 - len(data))
    with open(sys.argv[2], "w") as out:
        for i in range(0, len(data), 4):
            out.write(f"{int.from_bytes(data[i:i + 4], 'little'):08x}\n")


if __name__ == "__main__":
    main()
