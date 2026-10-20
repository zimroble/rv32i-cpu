#!/usr/bin/env python3
"""Run every compiled test program on the simulated SoC and report results.

A program passes when it halts via ECALL with a0 == 0 and, if a
`<name>.expected` file exists next to the source, its console output matches.
Also prints cycles, retired instructions and CPI for each program.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HALT_RE = re.compile(r"\[tb\] HALT exit=(\d+) cycles=(\d+) instret=(\d+)")


def run(vvp: Path, hex_file: Path) -> tuple[str, str]:
    proc = subprocess.run(
        ["vvp", "-n", str(vvp), f"+hex={hex_file}"],
        capture_output=True, text=True, timeout=600,
    )
    out = proc.stdout
    # vvp prints a "$finish called" line; strip it and our own status line.
    marker = out.rfind("\n[tb] ")
    console = out[:marker] if marker != -1 else out
    status = out[marker + 1:] if marker != -1 else out
    return console, status


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    ap.add_argument("--json", help="write per-program stats to this file")
    args = ap.parse_args()

    build = ROOT / args.build
    vvp = build / "soc.vvp"
    programs = sorted(build.glob("asm/*.hex")) + sorted(build.glob("c/*.hex"))
    if not programs:
        print("no programs found; run `make programs` first")
        return 1

    failures = 0
    stats = []
    print(f"{'program':<16}{'result':<8}{'cycles':>10}{'instret':>10}{'CPI':>7}")
    print("-" * 51)
    for hex_file in programs:
        kind = hex_file.parent.name
        name = hex_file.stem
        console, status = run(vvp, hex_file)
        m = HALT_RE.search(status)
        ok = bool(m) and m.group(1) == "0"
        expected = ROOT / "tests" / kind / f"{name}.expected"
        if ok and expected.exists() and console != expected.read_text():
            ok = False
            status += f"\n  console mismatch:\n  got:      {console!r}\n  expected: {expected.read_text()!r}"
        label = f"{kind}/{name}"
        if m:
            cycles, instret = int(m.group(2)), int(m.group(3))
            cpi = cycles / instret
            stats.append({"program": label, "cycles": cycles, "instret": instret, "cpi": round(cpi, 3)})
            print(f"{label:<16}{'PASS' if ok else 'FAIL':<8}{cycles:>10}{instret:>10}{cpi:>7.2f}")
        else:
            print(f"{label:<16}FAIL")
        if not ok:
            failures += 1
            print("  " + status.strip().replace("\n", "\n  "))

    print("-" * 51)
    print(f"{len(programs) - failures}/{len(programs)} programs passed")
    if args.json:
        import json
        Path(args.json).write_text(json.dumps(stats, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
