#!/usr/bin/env python3
"""
run_conformance.py -- the "certify the code" script.

For every *.asm program under tests/conformance/, this:
  1. assembles it with tools/dsd8asm.py,
  2. runs tools/dsd8sim.py to produce the golden trace,
  3. compiles tb/tb_dsd8.v against your rtl/ and sim/peripherals.v with
     Icarus Verilog, pointed at that program's .hex image,
  4. runs the simulation to produce your dut.trace,
  5. diffs the two traces and reports the first differing line.

Exit code is non-zero if any test fails -- this is what CI (and the
pre-push hook) treat as "does not certify".

Usage:
    python3 scripts/run_conformance.py                  # every test
    python3 scripts/run_conformance.py sample01_multiply # one test, by stem
"""
import argparse
import os
import pathlib
import shutil
import subprocess
import sys

REPO_ROOT = pathlib.Path(os.path.abspath(__file__)).parent.parent
TOOLS = REPO_ROOT / "tools"
RTL = REPO_ROOT / "rtl"
TB = REPO_ROOT / "tb" / "tb_dsd8.v"
PERIPHERALS = REPO_ROOT / "sim" / "peripherals.v"
TESTS_DIR = REPO_ROOT / "tests" / "conformance"
BUILD_DIR = REPO_ROOT / "build" / "conformance"

RTL_SOURCES = [
    "dsd8_cpu.v", "prog_counter.v", "instr_memory.v", "instr_decoder.v",
    "register_file.v", "alu.v", "flags_reg.v", "data_memory.v",
    "control_unit.v", "io_bus.v",
]


class ToolNotFound(Exception):
    pass


def run(cmd, **kwargs):
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, cwd=REPO_ROOT, **kwargs
        )
    except FileNotFoundError as e:
        raise ToolNotFound(
            f"'{cmd[0]}' is not installed or not on PATH ({e}). "
            f"Install Icarus Verilog (apt-get install iverilog) before running this."
        )


def assemble_and_simulate_gold(asm_path, work_dir):
    hex_path = work_dir / (asm_path.stem + ".hex")
    gold_path = work_dir / (asm_path.stem + ".gold.trace")

    r = run([
        sys.executable, str(TOOLS / "dsd8asm.py"),
        str(asm_path.relative_to(REPO_ROOT)), "-o",
        str(hex_path.relative_to(REPO_ROOT)),
    ])
    if r.returncode != 0:
        return None, None, f"assembler failed:\n{r.stdout}{r.stderr}"
    if not hex_path.is_file():
        return None, None, f"assembler did not create the image: {hex_path}"

    r = run([
        sys.executable, str(TOOLS / "dsd8sim.py"),
        str(hex_path.relative_to(REPO_ROOT)), "--trace",
        str(gold_path.relative_to(REPO_ROOT)),
    ])
    if r.returncode != 0:
        return None, None, f"golden simulator failed:\n{r.stdout}{r.stderr}"
    if not gold_path.is_file() or gold_path.stat().st_size == 0:
        return None, None, f"reference simulator did not create a non-empty trace: {gold_path}"

    return hex_path, gold_path, None


def compile_and_simulate_dut(hex_path, work_dir, test_name):
    dut_trace = work_dir / (test_name + ".dut.trace")
    sim_bin = work_dir / (test_name + ".vvp")

    sources = [RTL / f for f in RTL_SOURCES] + [PERIPHERALS, TB]
    for src in sources:
        if not pathlib.Path(src).exists():
            return None, f"missing source file: {src}"

    compile_cmd = [
        find_tool("iverilog"), "-g2005", "-o",
        str(sim_bin.relative_to(REPO_ROOT)),
    ] + [str(src.relative_to(REPO_ROOT)) for src in sources]
    r = run(compile_cmd)
    if r.returncode != 0:
        return None, f"iverilog compile failed:\n{r.stdout}{r.stderr}"

    if dut_trace.exists():
        dut_trace.unlink()

    r = run([
        find_tool("vvp"), str(sim_bin.relative_to(REPO_ROOT)),
        f"+IMAGE={hex_path.relative_to(REPO_ROOT)}",
        f"+TRACE={dut_trace.relative_to(REPO_ROOT)}",
    ])
    if r.returncode != 0:
        return None, f"vvp simulation failed:\n{r.stdout}{r.stderr}"
    if not dut_trace.is_file() or dut_trace.stat().st_size == 0:
        return None, f"vvp did not create a non-empty DUT trace:\n{r.stdout}{r.stderr}"

    return dut_trace, None


def find_tool(name):
    bundled = REPO_ROOT / "tools" / "iverilog" / "app" / "bin" / f"{name}.exe"
    if bundled.is_file():
        return str(bundled)
    tool = shutil.which(name)
    if tool is None:
        raise ToolNotFound(f"'{name}' is not installed or not on PATH.")
    return tool


def first_diff(gold_path, dut_path):
    gold_lines = gold_path.read_text().splitlines()
    dut_lines = dut_path.read_text().splitlines() if dut_path.exists() else []

    if gold_lines == dut_lines:
        return None

    for i, (g, d) in enumerate(zip(gold_lines, dut_lines), start=1):
        if g != d:
            return f"line {i}:\n  expected: {g}\n  got:      {d}"
    if len(gold_lines) != len(dut_lines):
        longer, shorter = ("gold", "dut") if len(gold_lines) > len(dut_lines) else ("dut", "gold")
        return f"trace length differs: {longer} trace has more lines than {shorter} " \
               f"(gold={len(gold_lines)}, dut={len(dut_lines)})"
    return "traces differ (unable to localise -- this should not happen)"


def main():
    ap = argparse.ArgumentParser(description="Run the DSD-8 conformance suite")
    ap.add_argument("filter", nargs="?", help="only run the test whose filename stem matches this")
    args = ap.parse_args()

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    asm_files = sorted(TESTS_DIR.glob("*.asm"))
    if args.filter:
        asm_files = [p for p in asm_files if args.filter in p.stem]

    if not asm_files:
        print(f"no test programs found under {TESTS_DIR}", file=sys.stderr)
        sys.exit(2)

    try:
        find_tool("iverilog")
        find_tool("vvp")
    except ToolNotFound as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(3)

    results = []
    for asm_path in asm_files:
        name = asm_path.stem
        try:
            hex_path, gold_path, err = assemble_and_simulate_gold(asm_path, BUILD_DIR)
            if err:
                results.append((name, "ERROR", err))
                continue

            dut_path, err = compile_and_simulate_dut(hex_path, BUILD_DIR, name)
            if err:
                results.append((name, "ERROR", err))
                continue

            diff = first_diff(gold_path, dut_path)
            if diff is None:
                results.append((name, "PASS", None))
            else:
                results.append((name, "FAIL", diff))
        except ToolNotFound as e:
            results.append((name, "BLOCKED", str(e)))

    print()
    print(f"{'TEST':30s} RESULT")
    print("-" * 50)
    n_pass = 0
    for name, status, detail in results:
        print(f"{name:30s} {status}")
        if status == "PASS":
            n_pass += 1
        elif detail:
            for line in detail.splitlines():
                print(f"    {line}")
    print("-" * 50)
    print(f"{n_pass} / {len(results)} passed")
    print()

    sys.exit(0 if n_pass == len(results) else 1)


if __name__ == "__main__":
    main()
