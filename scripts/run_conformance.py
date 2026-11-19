#!/usr/bin/env python3
"""Run baseline golden-trace cases and the additional assembly samples."""

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
BASELINE_DIR = REPO_ROOT / "sim" / "tests"
SAMPLES_DIR = REPO_ROOT / "tests" / "conformance"
BUILD_DIR = REPO_ROOT / "build" / "conformance"

RTL_SOURCES = [
    "dsd8_cpu.v", "prog_counter.v", "instr_memory.v", "instr_decoder.v",
    "register_file.v", "alu.v", "flags_reg.v", "data_memory.v",
    "control_unit.v", "io_bus.v",
]


class ToolNotFound(Exception):
    pass


def find_tool(name):
    bundled = TOOLS / "iverilog" / "app" / "bin" / f"{name}.exe"
    if bundled.is_file():
        return str(bundled)
    tool = shutil.which(name)
    if tool is None:
        raise ToolNotFound(f"'{name}' is not installed or not on PATH.")
    return tool


def run(cmd):
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, cwd=REPO_ROOT
        )
    except FileNotFoundError as exc:
        raise ToolNotFound(f"Could not run '{cmd[0]}': {exc}") from exc


def relative(path):
    return path.relative_to(REPO_ROOT).as_posix()


def sample_reference(asm_path, work_dir):
    hex_path = work_dir / f"{asm_path.stem}.hex"
    gold_path = work_dir / f"{asm_path.stem}.gold.trace"

    result = run([
        sys.executable, str(TOOLS / "dsd8asm.py"),
        relative(asm_path), "-o", relative(hex_path),
    ])
    if result.returncode:
        return None, None, f"assembler failed:\n{result.stdout}{result.stderr}"
    if not hex_path.is_file():
        return None, None, f"assembler did not create {relative(hex_path)}"

    result = run([
        sys.executable, str(TOOLS / "dsd8sim.py"),
        relative(hex_path), "--trace", relative(gold_path),
    ])
    if result.returncode:
        return None, None, (
            f"golden simulator failed:\n{result.stdout}{result.stderr}"
        )
    if not gold_path.is_file() or gold_path.stat().st_size == 0:
        return None, None, (
            f"reference simulator did not create a non-empty trace: "
            f"{relative(gold_path)}"
        )
    return hex_path, gold_path, None


def normalize_trace(path):
    return [line.strip().upper() for line in path.read_text().splitlines() if line.strip()]


def normalize_image(path):
    words = [0] * 512
    address = 0
    for line in path.read_text().splitlines():
        content = line.split("//", 1)[0].strip()
        for token in content.split():
            if token.startswith("@"):
                address = int(token[1:], 16)
            else:
                if address >= len(words):
                    raise ValueError(f"image exceeds 512 words: {path}")
                words[address] = int(token, 16) & 0xFFFF
                address += 1
    return tuple(words)


def first_diff(gold_path, dut_path):
    gold_lines = normalize_trace(gold_path)
    dut_lines = normalize_trace(dut_path)
    if gold_lines == dut_lines:
        return None

    for line_number, (gold, dut) in enumerate(zip(gold_lines, dut_lines), start=1):
        if gold != dut:
            return (
                f"line {line_number}:\n"
                f"  expected: {gold}\n"
                f"  got:      {dut}"
            )
    return (
        f"trace length differs (gold={len(gold_lines)}, "
        f"DUT={len(dut_lines)})"
    )


def find_duplicate(image_path, gold_path):
    """Return the matching baseline name, or None when no baseline matches."""
    image = normalize_image(image_path)
    trace = normalize_trace(gold_path)
    for baseline_image in sorted(BASELINE_DIR.glob("T*.hex")):
        baseline_name = baseline_image.stem
        baseline_gold = BASELINE_DIR / f"{baseline_name}_gold.trace"
        if (
            baseline_gold.is_file()
            and normalize_image(baseline_image) == image
            and normalize_trace(baseline_gold) == trace
        ):
            return baseline_name
    return None


def collect_cases(filter_text):
    baseline_cases = []
    for image in sorted(BASELINE_DIR.glob("T*.hex")):
        name = image.stem
        if not filter_text or filter_text.lower() in name.lower():
            baseline_cases.append(
                (name, image, BASELINE_DIR / f"{name}_gold.trace")
            )

    sample_cases = []
    for asm in sorted(SAMPLES_DIR.glob("*.asm")):
        name = asm.stem
        if not filter_text or filter_text.lower() in name.lower():
            duplicate = {
                "sample01_multiply": "T36",
                "sample02_popcount": "T37",
            }.get(name)
            sample_cases.append((name, asm, duplicate))
    return baseline_cases, sample_cases


def compile_harness():
    sources = [RTL / name for name in RTL_SOURCES] + [PERIPHERALS, TB]
    missing = [source for source in sources if not source.is_file()]
    if missing:
        return None, "missing source file(s): " + ", ".join(map(str, missing))

    sim_bin = BUILD_DIR / "tb_dsd8.vvp"
    result = run([
        find_tool("iverilog"), "-g2005", "-o", relative(sim_bin),
        *[relative(source) for source in sources],
    ])
    if result.returncode:
        return None, f"iverilog compile failed:\n{result.stdout}{result.stderr}"
    if result.stdout or result.stderr:
        print((result.stdout + result.stderr).rstrip())
    return sim_bin, None


def simulate_image(name, image_path, expected_path, sim_bin, work_dir):
    if not image_path.is_file():
        return "BLOCKED", f"missing image: {relative(image_path)}", None
    if not expected_path.is_file():
        return "BLOCKED", f"missing golden trace: {relative(expected_path)}", None

    dut_trace = work_dir / f"{name}.dut.trace"
    if dut_trace.exists():
        dut_trace.unlink()

    result = run([
        find_tool("vvp"), relative(sim_bin),
        f"+IMAGE={relative(image_path)}",
        f"+TRACE={relative(dut_trace)}",
    ])
    output = result.stdout + result.stderr
    if result.returncode:
        return "FAIL", f"vvp exited with code {result.returncode}:\n{output}", None
    if not dut_trace.is_file() or dut_trace.stat().st_size == 0:
        return "FAIL", f"simulation did not create a non-empty DUT trace:\n{output}", None

    difference = first_diff(expected_path, dut_trace)
    if difference:
        return "FAIL", difference, dut_trace
    return "PASS", None, dut_trace


def execute_baseline(case, sim_bin):
    name, image_path, expected_path = case
    work_dir = BUILD_DIR / name
    work_dir.mkdir(parents=True, exist_ok=True)
    status, detail, _ = simulate_image(
        name, image_path, expected_path, sim_bin, work_dir
    )
    return status, detail


def execute_sample(case, sim_bin):
    name, asm_path, duplicate_id = case
    work_dir = BUILD_DIR / name
    work_dir.mkdir(parents=True, exist_ok=True)
    image_path, gold_path, error = sample_reference(asm_path, work_dir)
    if error:
        return "BLOCKED", error, None

    try:
        duplicate_id = find_duplicate(image_path, gold_path)
    except (OSError, ValueError) as exc:
        return "BLOCKED", f"could not compare sample with baselines: {exc}", None

    status, detail, _ = simulate_image(
        name, image_path, gold_path, sim_bin, work_dir
    )
    return status, detail, duplicate_id


def main():
    parser = argparse.ArgumentParser(
        description="Run baseline and additional DSD-8 conformance programs"
    )
    parser.add_argument(
        "filter", nargs="?", help="optional case-name substring filter"
    )
    args = parser.parse_args()

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    baseline_cases, sample_cases = collect_cases(args.filter)
    results = []
    pipeline_results = []

    if not baseline_cases and not sample_cases:
        print("BLOCKED: no matching conformance programs found")
        print("SUMMARY: PASS=0 FAIL=0 BLOCKED=1 TOTAL=1")
        print("PIPELINE SUMMARY: PASS=0 FAIL=0 BLOCKED=0 TOTAL=0 DUPLICATES=0")
        return 1

    try:
        find_tool("iverilog")
        find_tool("vvp")
        sim_bin, compile_error = compile_harness()
    except ToolNotFound as exc:
        sim_bin, compile_error = None, str(exc)

    if compile_error:
        results = [(name, "BLOCKED", compile_error) for name, *_ in baseline_cases]
        pipeline_results = [
            (name, "BLOCKED", compile_error, None)
            for name, *_ in sample_cases
        ]
    else:
        for case in baseline_cases:
            try:
                status, detail = execute_baseline(case, sim_bin)
            except ToolNotFound as exc:
                status, detail = "BLOCKED", str(exc)
            results.append((case[0], status, detail))
        for case in sample_cases:
            try:
                status, detail, duplicate = execute_sample(case, sim_bin)
            except ToolNotFound as exc:
                status, detail, duplicate = "BLOCKED", str(exc), None
            pipeline_results.append((case[0], status, detail, duplicate))

    print()
    print(f"{'TEST CASE':32s} RESULT")
    print("-" * 48)
    counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
    for name, status, detail in results:
        print(f"{name:32s} {status}")
        counts[status] += 1
        if detail:
            for line in detail.splitlines():
                print(f"    {line}")

    pipeline_counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
    duplicate_count = 0
    print()
    print("ADDITIONAL SAMPLE PIPELINE CHECKS (not extra unique test cases)")
    for name, status, detail, duplicate_id in pipeline_results:
        suffix = f" (same image/trace as {duplicate_id})" if duplicate_id else ""
        print(f"{name:32s} {status}{suffix}")
        pipeline_counts[status] += 1
        duplicate_count += int(duplicate_id is not None)
        if duplicate_id is None:
            results.append((name, status, detail))
        if detail:
            for line in detail.splitlines():
                print(f"    {line}")

    if any(duplicate_id is None for _, _, _, duplicate_id in pipeline_results):
        counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
        for _, status, _ in results:
            counts[status] += 1
    total = len(results)
    print("-" * 48)
    print(
        f"Passed: {counts['PASS']}  Failed: {counts['FAIL']}  "
        f"Blocked: {counts['BLOCKED']}  Total: {total}"
    )
    print(
        f"SUMMARY: PASS={counts['PASS']} FAIL={counts['FAIL']} "
        f"BLOCKED={counts['BLOCKED']} TOTAL={total}"
    )
    print(
        f"PIPELINE SUMMARY: PASS={pipeline_counts['PASS']} "
        f"FAIL={pipeline_counts['FAIL']} BLOCKED={pipeline_counts['BLOCKED']} "
        f"TOTAL={len(pipeline_results)} DUPLICATES={duplicate_count}"
    )
    return int(
        counts["FAIL"] > 0 or counts["BLOCKED"] > 0
        or pipeline_counts["FAIL"] > 0 or pipeline_counts["BLOCKED"] > 0
    )


if __name__ == "__main__":
    sys.exit(main())
