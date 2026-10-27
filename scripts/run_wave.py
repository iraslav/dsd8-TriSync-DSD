#!/usr/bin/env python3
"""
Waveform Runner for the DSD-8 Processor (scripts/run_wave.py)

One command:  compile testbench -> simulate with VCD capture -> open GTKWave.

Usage:
    python scripts/run_wave.py tb_alu                       # unit testbench
    python scripts/run_wave.py tb_dsd8 --test T01           # conformance test T01
    python scripts/run_wave.py tb_dsd8 --test T36           # multiply demo with waves
    python scripts/run_wave.py tb_dsd8 --asm bubblesort     # bubble sort demo
    python scripts/run_wave.py tb_alu --no-view             # only produce the .vcd

Output (all under sim/waves/):
    <tb>[_<source>].vcd     VCD waveform (open in GTKWave)
    <tb>[_<source>].gtkw    GTKWave save file (pre-loaded signal view)
    <tb>.vvp                compiled simulation image (rebuilt when sources change)

Notes:
    - Wave capture is opt-in (+VCD plusarg), so plain regressions stay untouched.
    - GTKWave is launched from the copy bundled with the project:
        tools/iverilog/app/gtkwave/bin/gtkwave.exe
"""

import os
import re
import glob
import sys
import time
import subprocess

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IVERILOG = os.path.join(ROOT_DIR, "tools", "iverilog", "app", "bin", "iverilog.exe")
VVP      = os.path.join(ROOT_DIR, "tools", "iverilog", "app", "bin", "vvp.exe")
GTKWAVE  = os.path.join(ROOT_DIR, "tools", "iverilog", "app", "gtkwave", "bin", "gtkwave.exe")
TB_DIR   = os.path.join(ROOT_DIR, "tb")
RTL_DIR  = os.path.join(ROOT_DIR, "rtl")
SIM_DIR  = os.path.join(ROOT_DIR, "sim")
TESTS_DIR = os.path.join(SIM_DIR, "tests")

HELPER_VAR = "wave_vcd_file"  # dump-control reg in tb/wave_dump.vh (hide from views)

# Same unit-test mapping as scripts/run_all.py (keeps compilation consistent)
UNIT_TB_RTL = {
    "tb_prog_counter":   ["prog_counter.v"],
    "tb_register_file":  ["register_file.v"],
    "tb_alu":            ["alu.v"],
    "tb_flags_reg":      ["flags_reg.v"],
    "tb_instr_decoder":  ["instr_decoder.v"],
    "tb_data_memory":    ["data_memory.v"],
    "tb_control_unit":   ["control_unit.v"],
    "tb_io_bus":         ["io_bus.v"],
    "tb_alu_random":     ["alu.v"],
}

# Bookkeeping variables in tb_dsd8 that are noise in a waveform view
VIEW_DROPS = {"IMAGE", "image_file", "trace_file", "f", "i", "max_cycles"}
# Signals added to every tb_dsd8 waveform view (frozen trace interface + core state)
SYSTEM_WAVE_EXTRAS = [
    "u_cpu.pc_reg",       # PC of the instruction being retired   (S8.2)
    "u_cpu.instr_reg",    # latched instruction word              (S8.2)
    "u_cpu.in_fetch",     # 0 = EXECUTE phase, 1 = FETCH phase
    "u_cpu.u_ctrl.state", # control-unit FSM state (S_FETCH/S_EXECUTE)
]


def fwd(path):
    """iverilog plusargs want forward slashes."""
    return path.replace("\\", "/")


def rel(path):
    """Path relative to project root (all sim runs use the root as cwd)."""
    return fwd(os.path.relpath(path, ROOT_DIR))


def parse_args(argv):
    if not argv:
        print(__doc__)
        print("ERROR: give a testbench name, e.g.  python scripts/run_wave.py tb_alu")
        sys.exit(2)
    tb = argv[0]
    if tb.endswith(".v"):
        tb = tb[:-2]

    opts = {
        "tb": tb,
        "test": None,        # conformance image, e.g. T01
        "asm": None,         # worked-example hex name, e.g. multiply
        "image": None,       # explicit .hex path
        "no_view": False,    # don't launch GTKWave
    }
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--test":
            opts["test"] = argv[i + 1].upper();            i += 2
        elif a == "--asm":
            opts["asm"] = argv[i + 1];                     i += 2
        elif a == "--image":
            opts["image"] = os.path.abspath(argv[i + 1]);  i += 2
        elif a == "--no-view":
            opts["no_view"] = True;                        i += 1
        else:
            print(f"ERROR: unknown option '{a}'")
            sys.exit(2)
    return opts


def resolve_image(opts):
    """Choose the .hex program image and a short suffix for output filenames."""
    if opts["image"]:
        return opts["image"], os.path.splitext(os.path.basename(opts["image"]))[0]
    if opts["test"]:
        return os.path.join(TESTS_DIR, opts["test"] + ".hex"), opts["test"]
    if opts["asm"]:
        return os.path.join(SIM_DIR, opts["asm"] + ".hex"), opts["asm"]
    if opts["tb"] == "tb_dsd8":
        return os.path.join(SIM_DIR, "multiply.hex"), "multiply"
    return None, ""


def collect_rtl(opts):
    if opts["tb"] == "tb_dsd8":
        return sorted(glob.glob(os.path.join(RTL_DIR, "*.v")))
    if opts["tb"] in UNIT_TB_RTL:
        return [os.path.join(RTL_DIR, r) for r in UNIT_TB_RTL[opts["tb"]]]
    print(f"WARNING: '{opts['tb']}' is not a known testbench - linking against all RTL")
    return sorted(glob.glob(os.path.join(RTL_DIR, "*.v")))


def scan_vcd_scopes(vcd_path, prefer_top):
    """Walk the VCD header ($scope/$var/$upscope/$enddefinitions only).

    Icarus writes one root scope per top-level module in the compiled design
    (e.g. both dsd8_top and tb_dsd8). We collect top-level variables strictly
    from the root scope that matches the requested testbench.

    Returns:
        top_vars: ordered top-level var names of the chosen root
        all_paths: set of ALL hierarchical var paths in the file
        roots: list of root scope names in file order
    """
    chosen = None
    top_vars, all_paths, roots = [], set(), []
    stack = []
    var_re = re.compile(r"\$var\s+\S+\s+\d+\s+\S+\s+(\S+)(?:\s+\[[^\]]*\])?\s+\$end")
    with open(vcd_path, "r", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("$scope"):
                parts = line.split()
                name = parts[2]
                stack.append(name)
                if len(stack) == 1:
                    roots.append(name)
                    if chosen is None and name == prefer_top:
                        chosen = name
                        top_vars = []
            elif line.startswith("$upscope"):
                if stack:
                    stack.pop()
            elif line.startswith("$var"):
                m = var_re.match(line)
                if not m:
                    continue
                name = m.group(1)
                if stack:
                    all_paths.add(".".join(stack + [name]))
                if chosen and len(stack) == 1 and stack[0] == chosen and name != HELPER_VAR:
                    top_vars.append(name)
            elif line.startswith("$enddefinitions"):
                break
    return top_vars, all_paths, roots


def build_view_signals(tb, top_scope, top_vars, all_paths):
    """Signal lines for the GTKWave save file: top-level wires + system extras."""
    priority = {"clk": 0, "rst_n": 1, "halted": 2, "retire": 3,
                "retire_pc": 4, "retire_ir": 5, "retire_flags": 6,
                "leds": 7, "result": 0, "op": 2}
    drops = VIEW_DROPS if tb == "tb_dsd8" else set()
    ordered = sorted(set(top_vars) - drops, key=lambda s: (priority.get(s, 50), s))

    lines = [f"{top_scope}.{s}" for s in ordered]
    if tb == "tb_dsd8":
        for extra in SYSTEM_WAVE_EXTRAS:
            path = f"{top_scope}.{extra}" if not extra.startswith(top_scope + ".") else extra
            if path in all_paths:
                lines.append(path)
    return lines


def make_savefile_for(vcd_path, tb):
    """Generate the paired .gtkw view for any already-produced VCD.

    Used by scripts/run_all.py so every automatically generated waveform also
    opens with the same curated signal selection in GTKWave.
    """
    gtkw_path = os.path.splitext(vcd_path)[0] + ".gtkw"
    top_vars, all_paths, roots = scan_vcd_scopes(vcd_path, tb)
    top_scope = tb if tb in roots else (roots[0] if roots else tb)
    signals = build_view_signals(tb, top_scope, top_vars, all_paths)
    write_gtkw(gtkw_path, vcd_path, top_scope, signals)
    return gtkw_path


def write_gtkw(gtkw_path, vcd_path, top_scope, signals):
    """Minimal GTKWave save file so the interesting signals load pre-drawn."""
    try:
        mtime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(os.path.getmtime(vcd_path)))
    except OSError:
        mtime = ""
    lines = [
        f'[dumpfile] "{rel(vcd_path)}"',
        f'[dumpfile_mtime] "{mtime}"',
        f"[dumpfile_size] {os.path.getsize(vcd_path)}",
        f'[savefile] "{rel(gtkw_path)}"',
        "[timestart] 0",
        "[size] 1600 900",
        "[pos] -1 -1",
        "*-28.000000 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1",
        "[sst_width] 260",
        "[signals_length] 300",
        "[sst_height] 520",
        "[sst_spacing] 80",
        "[cycle_master] 1",
        f"[treeopen] {top_scope}.",
    ]
    if signals:
        lines.append(f"[signals] {signals[0]} c 1")
        lines += [f"{s} c 1" for s in signals[1:]]
    with open(gtkw_path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def main():
    opts = parse_args(sys.argv[1:])
    hex_path, suffix = resolve_image(opts)
    if hex_path and not os.path.isfile(hex_path):
        print(f"ERROR: program image not found: {hex_path}")
        sys.exit(1)

    tb_path   = os.path.join(TB_DIR, opts["tb"] + ".v")
    waves_dir = os.path.join(SIM_DIR, "waves")
    os.makedirs(waves_dir, exist_ok=True)
    if not os.path.isfile(tb_path):
        print(f"ERROR: testbench not found: {tb_path}")
        sys.exit(1)

    base      = opts["tb"] + (f"_{suffix}" if suffix else "")
    vvp_file  = os.path.join(waves_dir, opts["tb"] + ".vvp")
    vcd_file  = os.path.join(waves_dir, base + ".vcd")
    gtkw_file = os.path.join(waves_dir, base + ".gtkw")

    # Rebuild only when the testbench or RTL is newer than the compiled image
    src_times = [os.path.getmtime(tb_path)] + [os.path.getmtime(r) for r in collect_rtl(opts)]
    fresh = os.path.isfile(vvp_file) and os.path.getmtime(vvp_file) > max(src_times)

    if fresh:
        print(f"{opts['tb']}.vvp is up to date - reusing compiled image")
    else:
        print(f"Compiling {opts['tb']}.v ...")
        compile_cmd = [IVERILOG, "-g2012", "-o", fwd(rel(vvp_file)), fwd(rel(tb_path))]
        compile_cmd += [fwd(rel(r)) for r in collect_rtl(opts)]
        res = subprocess.run(compile_cmd, cwd=ROOT_DIR, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode != 0:
            print("COMPILATION FAILED:")
            print(res.stderr)
            sys.exit(1)

    # ---------------------------------------------------------------- simulate
    run_cmd = [VVP, fwd(rel(vvp_file)), f"+VCD={rel(vcd_file)}"]
    if hex_path:
        run_cmd.append(f"+IMAGE={rel(hex_path)}")
    print(f"Simulating -> {rel(vcd_file)} ...")
    t0 = time.time()
    res = subprocess.run(run_cmd, cwd=ROOT_DIR, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = (res.stdout or ""), (res.stderr or "")

    if not os.path.isfile(vcd_file) or os.path.getsize(vcd_file) == 0:
        print("ERROR: no VCD waveform was produced!")
        print(out)
        print(err)
        sys.exit(1)

    fails = [l for l in out.splitlines() if l.startswith("FAIL") or "ERROR" in l]

    # ---------------------------------------------------- GTKWave save file
    top_vars, all_paths, roots = scan_vcd_scopes(vcd_file, opts["tb"])
    top_scope = opts["tb"] if opts["tb"] in roots else (roots[0] if roots else opts["tb"])
    signals = build_view_signals(opts["tb"], top_scope, top_vars, all_paths)
    write_gtkw(gtkw_file, vcd_file, top_scope, signals)

    print(f"  Waveform (VCD):    {rel(vcd_file)}  ({os.path.getsize(vcd_file)/1024:.1f} KB, {time.time()-t0:.2f}s)")
    print(f"  GTKWave save file: {rel(gtkw_file)}")
    if fails:
        print("\nSimulation reported failures:")
        for l in fails[:10]:
            print("  " + l)
    else:
        print("  No FAIL lines in simulation output.")

    # ------------------------------------------------------------------ GTKWave
    if opts["no_view"]:
        print("\n--no-view: waveform saved. Open it later with:")
        print(f'  "{GTKWAVE}" "{vcd_file}" "{gtkw_file}"')
        return 0
    if not os.path.isfile(GTKWAVE):
        print(f"ERROR: GTKWave not found at {GTKWAVE}")
        print("Open the .vcd manually with any waveform viewer.")
        return 1
    print("\nOpening GTKWave ...")
    subprocess.Popen([GTKWAVE, rel(vcd_file), rel(gtkw_file)], cwd=ROOT_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
