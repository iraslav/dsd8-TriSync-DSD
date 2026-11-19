#!/usr/bin/env python3
"""Master DSD-8 verification runner."""

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys

try:
    from .windows_path import repository_path
except ImportError:
    from windows_path import repository_path

ROOT_DIR = pathlib.Path(os.path.abspath(__file__)).parent.parent
SUMMARY_RE = re.compile(
    r"SUMMARY: PASS=(\d+) FAIL=(\d+) BLOCKED=(\d+) TOTAL=(\d+)"
)
PIPELINE_RE = re.compile(
    r"PIPELINE SUMMARY: PASS=(\d+) FAIL=(\d+) BLOCKED=(\d+) "
    r"TOTAL=(\d+) DUPLICATES=(\d+)"
)


def expected_case_counts(root):
    unit_count = len([
        path for path in (root / "tb").glob("tb_*.v")
        if path.name != "tb_dsd8.v"
    ])
    conformance_count = len(list((root / "sim" / "tests").glob("T*.hex")))
    pipeline_count = len(list((root / "tests" / "conformance").glob("*.asm")))
    return unit_count, conformance_count, pipeline_count


def run_script(root, relative_script):
    command = [sys.executable, str(root / relative_script)]
    try:
        result = subprocess.run(
            command, cwd=root, capture_output=True, text=True
        )
    except OSError as exc:
        return None, f"Could not run {relative_script}: {exc}"

    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    return result, None


def summarize_child(result, error, expected_count, expected_pipeline, label):
    pipeline_counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
    if error:
        print(f"{label}: BLOCKED - {error}")
        pipeline_counts["BLOCKED"] = expected_pipeline
        return (
            {"PASS": 0, "FAIL": 0, "BLOCKED": expected_count},
            pipeline_counts,
            False,
        )

    match = SUMMARY_RE.search(result.stdout)
    if match is None:
        detail = f"{label} exited with code {result.returncode} without a test summary"
        print(f"{label}: BLOCKED - {detail}")
        pipeline_counts["BLOCKED"] = expected_pipeline
        return (
            {"PASS": 0, "FAIL": 0, "BLOCKED": expected_count},
            pipeline_counts,
            False,
        )

    counts = {
        "PASS": int(match.group(1)),
        "FAIL": int(match.group(2)),
        "BLOCKED": int(match.group(3)),
    }
    reported_total = int(match.group(4))
    summary_ok = (
        reported_total == expected_count
        and reported_total == sum(counts.values())
    )
    if not summary_ok:
        print(
            f"{label}: FAIL - reported total {reported_total} does not match "
            f"expected {expected_count} and component counts {sum(counts.values())}"
        )
    pipeline_ok = True
    if expected_pipeline:
        pipeline_match = PIPELINE_RE.search(result.stdout)
        if pipeline_match is None:
            pipeline_counts["BLOCKED"] = expected_pipeline
            pipeline_ok = False
            print(f"{label}: BLOCKED - missing pipeline-check summary")
        else:
            pipeline_counts = {
                "PASS": int(pipeline_match.group(1)),
                "FAIL": int(pipeline_match.group(2)),
                "BLOCKED": int(pipeline_match.group(3)),
            }
            pipeline_ok = (
                int(pipeline_match.group(4)) == expected_pipeline
                and sum(pipeline_counts.values()) == expected_pipeline
            )
    exit_ok = result.returncode == 0
    if summary_ok and not exit_ok:
        print(f"{label}: FAIL - runner exited with code {result.returncode}")
    return counts, pipeline_counts, summary_ok and pipeline_ok and exit_ok


def lint(root):
    command = ["make", "lint"]
    try:
        result = subprocess.run(
            command, cwd=root, capture_output=True, text=True
        )
    except OSError as exc:
        print(f"LINT: BLOCKED - could not run make lint: {exc}")
        return "BLOCKED", False

    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    if result.returncode == 0:
        return "PASS", True
    return "FAIL", False


def lint_only(root):
    rtl_files = sorted((root / "rtl").glob("*.v"))
    if not rtl_files:
        print("LINT: BLOCKED - no RTL Verilog files found")
        return 1

    bundled = root / "tools" / "iverilog" / "app" / "bin" / "iverilog.exe"
    compiler = str(bundled) if bundled.is_file() else shutil.which("iverilog")
    if compiler is None:
        print("LINT: BLOCKED - Icarus Verilog is not installed or not on PATH")
        return 1

    result = subprocess.run(
        [compiler, "-g2012", "-t", "null", *[str(path) for path in rtl_files]],
        cwd=root, capture_output=True, text=True,
    )
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    if result.returncode == 0:
        print("LINT: PASS")
        return 0
    print(f"LINT: FAIL (iverilog exit code {result.returncode})")
    return 1


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--unit-only", action="store_true", help="run unit and integration benches")
    mode.add_argument("--conformance-only", action="store_true", help="run baseline and sample conformance")
    mode.add_argument("--lint-only", action="store_true", help="run the RTL syntax check")
    return parser.parse_args()


def main():
    args = parse_args()
    try:
        with repository_path(ROOT_DIR) as root:
            if args.lint_only:
                return lint_only(root)

            unit_expected, conformance_expected, pipeline_expected = expected_case_counts(root)
            unit_counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
            conformance_counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
            pipeline_counts = {"PASS": 0, "FAIL": 0, "BLOCKED": 0}
            runners_ok = True

            if not args.conformance_only:
                print("=== Unit and integration testbenches ===")
                result, error = run_script(root, pathlib.Path("scripts/run_unit_tests.py"))
                unit_counts, _, ok = summarize_child(
                    result, error, unit_expected, 0, "Unit tests"
                )
                runners_ok &= ok

            if not args.unit_only:
                print("=== Baseline and additional conformance tests ===")
                result, error = run_script(root, pathlib.Path("scripts/run_conformance.py"))
                conformance_counts, pipeline_counts, ok = summarize_child(
                    result, error, conformance_expected, pipeline_expected,
                    "Conformance tests"
                )
                runners_ok &= ok

            test_counts = {
                name: unit_counts[name] + conformance_counts[name]
                for name in ("PASS", "FAIL", "BLOCKED")
            }
            test_total = sum(test_counts.values())
            if args.unit_only or args.conformance_only:
                lint_status, lint_ok = "NOT RUN", True
            else:
                print("=== RTL lint ===")
                lint_status, lint_ok = lint(root)

            print()
            print(
                f"TEST CASES: {test_total}  "
                f"PASS: {test_counts['PASS']}  "
                f"FAIL: {test_counts['FAIL']}  "
                f"BLOCKED: {test_counts['BLOCKED']}"
            )
            if not args.unit_only:
                print(
                    f"ADDITIONAL PIPELINE CHECKS: "
                    f"PASS: {pipeline_counts['PASS']}  "
                    f"FAIL: {pipeline_counts['FAIL']}  "
                    f"BLOCKED: {pipeline_counts['BLOCKED']} "
                    "(sample programs overlapping baseline cases are not double-counted)"
                )
            print(f"LINT: {lint_status}")
            passed = (
                runners_ok
                and lint_ok
                and test_counts["FAIL"] == 0
                and test_counts["BLOCKED"] == 0
                and pipeline_counts["FAIL"] == 0
                and pipeline_counts["BLOCKED"] == 0
            )
            print(f"OVERALL: {'PASS' if passed else 'FAIL'}")
            print(
                f"SUMMARY: PASS={test_counts['PASS']} "
                f"FAIL={test_counts['FAIL']} "
                f"BLOCKED={test_counts['BLOCKED']} TOTAL={test_total}"
            )
            return 0 if passed else 1
    except OSError as exc:
        print(f"BLOCKED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
