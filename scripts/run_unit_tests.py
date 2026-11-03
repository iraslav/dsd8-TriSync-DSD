#!/usr/bin/env python3
"""
run_unit_tests.py -- runs every per-module unit testbench under tb/
(everything matching tb_*.v except tb_dsd8.v, which is the conformance
harness and is run separately by run_conformance.py).

Testbenches use several verdict formats, including PASS: <testbench>,
STATUS: PASS, and TESTBENCH: PASS. Compilation failures are reported as
BLOCKED, runtime failures as FAIL, and an unrecognized verdict as BLOCKED.

Exit code is non-zero if any testbench fails, is missing the expected
output line, or does not compile.
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys

REPO_ROOT = pathlib.Path(os.path.abspath(__file__)).parent.parent
RTL = REPO_ROOT / "rtl"
TB_DIR = REPO_ROOT / "tb"
BUILD_DIR = REPO_ROOT / "build" / "unit"


def find_tool(name):
    bundled = REPO_ROOT / "tools" / "iverilog" / "app" / "bin" / f"{name}.exe"
    if bundled.is_file():
        return str(bundled)
    return shutil.which(name)


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, cwd=REPO_ROOT)


def classify_output(output, test_name, returncode):
    lines = output.splitlines()
    failure = next(
        (line for line in lines if re.search(
            r"^\s*(?:FAIL\b|TESTBENCH:\s*FAIL\b|STATUS:\s*FAIL\b)", line)),
        None,
    )
    if returncode != 0:
        return "FAIL", failure or f"simulation exited with code {returncode}"
    if failure:
        return "FAIL", failure

    success_patterns = (
        rf"^\s*PASS:\s*{test_name}(?:\s|$)",
        r"^\s*STATUS:\s*PASS(?:\s|$)",
        r"^\s*TESTBENCH:\s*PASS\s*$",
    )
    if any(re.search(pattern, line) for pattern in success_patterns for line in lines):
        return "PASS", None
    return "BLOCKED", "no recognized PASS/FAIL verdict found\n" + output


def main():
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    tb_files = sorted(p for p in TB_DIR.glob("tb_*.v") if p.name != "tb_dsd8.v")

    if not tb_files:
        print(f"BLOCKED: no unit testbenches found under {TB_DIR}")
        sys.exit(1)

    tools = {name: find_tool(name) for name in ("iverilog", "vvp")}
    missing = [name for name, path in tools.items() if path is None]

    rtl_sources = sorted(RTL.glob("*.v"))

    results = []
    for tb_path in tb_files:
        sim_bin = BUILD_DIR / (tb_path.stem + ".vvp")
        if missing:
            results.append((tb_path.name, "BLOCKED",
                            f"missing required tool(s): {', '.join(missing)}"))
            continue

        compile_cmd = [
            tools["iverilog"], "-g2012", "-o", str(sim_bin),
            *map(str, rtl_sources), str(tb_path),
        ]
        compiled = run(compile_cmd)
        if compiled.returncode != 0:
            results.append((tb_path.name, "BLOCKED",
                            f"compile failed:\n{compiled.stdout}{compiled.stderr}"))
            continue

        r = run([tools["vvp"], str(sim_bin)])
        output = r.stdout + r.stderr
        status, detail = classify_output(output, tb_path.stem, r.returncode)
        results.append((tb_path.name, status, detail))

    print()
    print(f"{'TESTBENCH':30s} RESULT")
    print("-" * 50)
    counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
    for name, status, detail in results:
        print(f"{name:30s} {status}")
        counts[status] += 1
        if detail:
            for line in detail.splitlines():
                print(f"    {line}")
    print("-" * 50)
    print(f"Passed: {counts['PASS']}  Failed: {counts['FAIL']}  Blocked: {counts['BLOCKED']}")
    print()

    sys.exit(0 if counts["FAIL"] == 0 and counts["BLOCKED"] == 0 else 1)


if __name__ == "__main__":
    main()
