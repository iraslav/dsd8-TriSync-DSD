#!/usr/bin/env python3
"""
Master CI and Verification Runner for DSD-8 Processor (scripts/run_all.py)
Executes all self-checking unit testbenches, the 12,200-vector random ALU test,
and the complete 40-test Conformance Suite, returning exit code 0 on all pass.
"""

import os
import sys
import subprocess
import glob
import time

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IVERILOG = os.path.join(ROOT_DIR, "tools", "iverilog", "app", "bin", "iverilog.exe")
VVP = os.path.join(ROOT_DIR, "tools", "iverilog", "app", "bin", "vvp.exe")
GTKWAVE = os.path.join(ROOT_DIR, "tools", "iverilog", "app", "gtkwave", "bin", "gtkwave.exe")
RTL_DIR = os.path.join(ROOT_DIR, "rtl")
TB_DIR = os.path.join(ROOT_DIR, "tb")
SIM_DIR = os.path.join(ROOT_DIR, "sim")
TESTS_DIR = os.path.join(SIM_DIR, "tests")
WAVES_DIR = os.path.join(SIM_DIR, "waves")


def fwd(path):
    """iverilog plusargs read paths best with forward slashes."""
    return path.replace("\\", "/")


def gtkw_view_for(tb_name, vcd_path):
    """Ask run_wave.py for a paired .gtkw view (never fails the regression)."""
    try:
        import run_wave
        return run_wave.make_savefile_for(vcd_path, tb_name)
    except Exception as exc:  # auxiliary nicety only
        print(f"      (wave view skipped: {exc})")
        return None


def run_cmd(cmd, cwd=ROOT_DIR):
    res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.returncode, res.stdout, res.stderr

def run_unit_tests(with_waves=True):
    print("=" * 70)
    print("STEP 1: RUNNING SELF-CHECKING UNIT TESTBENCHES" + ("  (+ auto VCD waves)" if with_waves else ""))
    print("=" * 70)

    unit_tests = [
        ("tb_prog_counter.v",   ["prog_counter.v"]),
        ("tb_register_file.v",  ["register_file.v"]),
        ("tb_alu.v",            ["alu.v"]),
        ("tb_flags_reg.v",      ["flags_reg.v"]),
        ("tb_instr_decoder.v",  ["instr_decoder.v"]),
        ("tb_data_memory.v",    ["data_memory.v"]),
        ("tb_control_unit.v",   ["control_unit.v"]),
        ("tb_io_bus.v",         ["io_bus.v"]),
        ("tb_alu_random.v",     ["alu.v"]),
    ]

    unit_passed = 0
    unit_waves = 0
    total_units = len(unit_tests)
    if with_waves:
        os.makedirs(WAVES_DIR, exist_ok=True)

    for tb_name, req_rtls in unit_tests:
        tb_path = os.path.join(TB_DIR, tb_name)
        vvp_out = os.path.join(SIM_DIR, tb_name.replace(".v", ".vvp"))
        rtl_paths = [os.path.join(RTL_DIR, r) for r in req_rtls]

        # Compile
        compile_cmd = [IVERILOG, "-g2012", "-o", vvp_out, tb_path] + rtl_paths
        code, out, err = run_cmd(compile_cmd)
        if code != 0:
            print(f"  [COMPILATION ERROR] {tb_name}:\n{err}")
            continue

        # Run (with automatic VCD waveform capture)
        sim_cmd = [VVP, vvp_out]
        if with_waves:
            vcd_out = os.path.join(WAVES_DIR, tb_name.replace(".v", ".vcd"))
            sim_cmd.append(f"+VCD={fwd(os.path.relpath(vcd_out, ROOT_DIR))}")
        code, out, err = run_cmd(sim_cmd)
        if "PASS" in out and code == 0:
            print(f"  [PASS] {tb_name:<20}")
            unit_passed += 1
            if with_waves and os.path.isfile(vcd_out) and os.path.getsize(vcd_out) > 0:
                gtkw_view_for(tb_name[:-2], vcd_out)
                unit_waves += 1
        else:
            print(f"  [FAIL] {tb_name:<20}\n{out}\n{err}")

    branch = f"  ({unit_waves} waveform(s) in sim/waves/)" if with_waves else ""
    print(f"\nUnit Test Summary: {unit_passed}/{total_units} Passed.{branch}\n")
    return unit_passed == total_units

def run_conformance_suite(with_waves=True):
    print("=" * 70)
    print("STEP 2: RUNNING 40-TEST CONFORMANCE SUITE (T01 - T40)" + ("  (+ auto VCD waves)" if with_waves else ""))
    print("=" * 70)

    # 1. Compile top testbench harness once
    all_rtls = glob.glob(os.path.join(RTL_DIR, "*.v"))
    tb_harness = os.path.join(TB_DIR, "tb_dsd8.v")
    harness_vvp = os.path.join(SIM_DIR, "tb_dsd8.vvp")

    compile_cmd = [IVERILOG, "-g2012", "-o", harness_vvp, tb_harness] + all_rtls
    code, out, err = run_cmd(compile_cmd)
    if code != 0:
        print(f"FATAL: Failed to compile tb_dsd8.v harness:\n{err}")
        return False

    if with_waves:
        os.makedirs(WAVES_DIR, exist_ok=True)

    tests = sorted(glob.glob(os.path.join(TESTS_DIR, "T*.hex")))
    passed_tests = 0
    passed_waves = 0
    total_tests = len(tests)

    print(f"{'Test':<8} {'Name':<28} {'Status':<8} {'Cycles':<8} {'Retire':<8}")
    print("-" * 65)

    descriptions = {
        "T01": "LDI into each register",
        "T02": "LDI boundary values",
        "T03": "MOV between registers",
        "T04": "LDI flag preservation",
        "T05": "NOP execution",
        "T06": "Write-then-read RF",
        "T07": "Same register ALU ports",
        "T08": "rd == rs1 == rs2",
        "T09": "Read unwritten DMEM",
        "T10": "DMEM Store-then-Load",
        "T11": "DMEM rs1 addr routing",
        "T12": "ST [Rx], Rx",
        "T13": "Walking-ones in DMEM",
        "T14": "LD flag preservation",
        "T15": "ADD carry boundary",
        "T16": "SUB borrow convention",
        "T17": "Signed overflow V",
        "T18": "Bitwise logic flags",
        "T19": "SHL/SHR carry shift",
        "T20": "SHR logical shift",
        "T21": "CMP sets flags only",
        "T22": "Arithmetic right shift",
        "T23": "JMP forward/backward",
        "T24": "Branch conditions taken",
        "T25": "Branch conditions fall-thru",
        "T26": "Branch loop escape",
        "T27": "Branch flag preservation",
        "T28": "Unsigned BCS/BCC ordering",
        "T29": "Signed BMI ordering",
        "T30": "256-iteration loop",
        "T31": "LEDS OUT / SWITCHES IN",
        "T32": "Unmapped IO port",
        "T33": "IO / DMEM isolation",
        "T34": "SLOW_ECHO IO handshake",
        "T35": "IO flag preservation",
        "T36": "8-bit Multiply (B.1)",
        "T37": "Population Count (B.2)",
        "T38": "Bubble Sort DMEM (B.3)",
        "T39": "Min/Max block search",
        "T40": "Polled UART transmit",
    }

    for test_hex in tests:
        test_id = os.path.basename(test_hex).split('.')[0]
        dut_trace = os.path.join(SIM_DIR, f"{test_id}_dut.trace")
        gold_trace = os.path.join(TESTS_DIR, f"{test_id}_gold.trace")

        # Run Verilog simulation (with automatic VCD waveform capture)
        sim_cmd = [
            VVP, harness_vvp,
            f"+IMAGE={test_hex.replace('\\', '/')}",
            f"+TRACE={dut_trace.replace('\\', '/')}"
        ]
        if with_waves:
            vcd_out = os.path.join(WAVES_DIR, f"{test_id}.vcd")
            sim_cmd.append(f"+VCD={fwd(os.path.relpath(vcd_out, ROOT_DIR))}")
        code, out, err = run_cmd(sim_cmd)

        # Extract cycle and instruction count
        cycles = "-"
        retired = "-"
        for line in out.splitlines():
            if "Cycles=" in line and "Instructions=" in line:
                parts = line.split(',')
                for p in parts:
                    if "Cycles=" in p:
                        cycles = p.split('=')[1].strip()
                    elif "Instructions=" in p:
                        retired = p.split('=')[1].strip()

        # Compare traces line-by-line
        diff = []
        if os.path.exists(dut_trace) and os.path.exists(gold_trace):
            with open(dut_trace, 'r') as f1, open(gold_trace, 'r') as f2:
                lines_dut = [l.strip().upper() for l in f1 if l.strip()]
                lines_gold = [l.strip().upper() for l in f2 if l.strip()]
            
            if lines_dut == lines_gold:
                status = "PASS"
                passed_tests += 1
            else:
                status = "FAIL"
                diff = [f"Diff at line {i+1}: DUT={d} vs GOLD={g}" 
                        for i, (d, g) in enumerate(zip(lines_dut, lines_gold)) if d != g]
                if not diff and len(lines_dut) != len(lines_gold):
                    diff = [f"Line count mismatch: DUT has {len(lines_dut)} lines, GOLD has {len(lines_gold)} lines"]
        else:
            status = "ERROR"

        desc = descriptions.get(test_id, "Conformance test")
        print(f"{test_id:<8} {desc:<28} {status:<8} {cycles:<8} {retired:<8}")
        if status == "PASS" and with_waves and os.path.isfile(vcd_out) and os.path.getsize(vcd_out) > 0:
            gtkw_view_for("tb_dsd8", vcd_out)
            passed_waves += 1
        if status == "FAIL" and diff:
            print(f"    --> {diff[0]}")

    print("-" * 65)
    print(f"Conformance Suite Score: {passed_tests}/{total_tests} ({passed_tests/total_tests*100:.1f}%)")
    if with_waves:
        print(f"Waveforms: {passed_waves}/{total_tests} VCD + .gtkw views in sim/waves/")
    return passed_tests == total_tests

def main():
    start_time = time.time()
    with_waves = "--no-waves" not in sys.argv   # waves are auto by default
    unit_ok = run_unit_tests(with_waves=with_waves)
    conf_ok = run_conformance_suite(with_waves=with_waves)
    elapsed = time.time() - start_time

    print("=" * 70)
    print(f"REGRESSION COMPLETE IN {elapsed:.2f} SECONDS")
    if with_waves:
        wave_count = len(glob.glob(os.path.join(WAVES_DIR, "*.vcd")))
        print(f"WAVEFORMS AUTO-CREATED: {wave_count} VCD (+ matching .gtkw views)")
        print(f"  -> folder: sim{os.sep}waves")
        print(f'  -> open any: "{GTKWAVE}" sim/waves/T36.vcd')
    if unit_ok and conf_ok:
        print("ALL TESTS PASSED! 100% SPECIFICATION CONFORMANCE ACHIEVED!")
        print("=" * 70)
        sys.exit(0)
    else:
        print("REGRESSION FAILED!")
        print("=" * 70)
        sys.exit(1)

if __name__ == "__main__":
    main()
