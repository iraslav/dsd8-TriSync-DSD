#!/usr/bin/env python3
"""Assemble and run the timer/interrupt add-on tests."""

import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SIM = ROOT / "sim"
RTL = ROOT / "rtl"
TB = ROOT / "tb"
BUNDLED_BIN = ROOT / "tools" / "iverilog" / "app" / "bin"
BUNDLED_GTKWAVE = ROOT / "tools" / "iverilog" / "app" / "gtkwave" / "bin" / "gtkwave.exe"
WAVES = SIM / "waves"


def find_tool(name):
    bundled = BUNDLED_BIN / f"{name}.exe"
    if bundled.is_file():
        return str(bundled)
    return shutil.which(name)


def run_step(label, command):
    print(f"\n== {label} ==", flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        print(f"FAILED: {label} (exit code {result.returncode})", file=sys.stderr)
        return False
    return True


def main():
    iverilog = find_tool("iverilog")
    vvp = find_tool("vvp")
    gtkwave = str(BUNDLED_GTKWAVE) if BUNDLED_GTKWAVE.is_file() else shutil.which("gtkwave")
    if not iverilog or not vvp:
        print(
            "Icarus Verilog was not found. Install iverilog and vvp, add them "
            "to PATH, or place the bundled tools in tools/iverilog/app/bin/.",
            file=sys.stderr,
        )
        return 1

    smoke_asm = SIM / "interrupt_smoke.asm"
    smoke_hex = SIM / "interrupt_smoke.hex"
    if not run_step(
        "Assemble CPU interrupt smoke test",
        [
            sys.executable,
            str(ROOT / "dsd8asm.py"),
            str(smoke_asm),
            "-o",
            str(smoke_hex),
        ],
    ):
        return 1

    unit_image = SIM / "tb_interrupt_controller.vvp"
    unit_vcd = WAVES / "GTKwave_interrupt_controller.vcd"
    unit_sources = [
        TB / "tb_interrupt_controller.v",
        RTL / "interrupt_controller.v",
    ]
    WAVES.mkdir(parents=True, exist_ok=True)
    if not run_step(
        "Compile interrupt controller test",
        [iverilog, "-g2012", "-s", "tb_interrupt_controller", "-o",
         str(unit_image), *map(str, unit_sources)],
    ):
        return 1
    if not run_step(
        "Run interrupt controller test",
        [vvp, str(unit_image), f"+VCD={unit_vcd.relative_to(ROOT).as_posix()}"],
    ):
        return 1

    integration_image = SIM / "tb_dsd8_interrupt_top.vvp"
    integration_vcd = WAVES / "GTKwave.vcd"
    rtl_sources = sorted(RTL.glob("*.v"))
    if not run_step(
        "Compile CPU-level interrupt integration test",
        [
            iverilog,
            "-g2012",
            "-s",
            "tb_dsd8_interrupt_top",
            "-o",
            str(integration_image),
            *map(str, rtl_sources),
            str(TB / "tb_dsd8_interrupt_top.v"),
        ],
    ):
        return 1
    if not run_step(
        "Run CPU-level interrupt integration test",
        [
            vvp,
            str(integration_image),
            f"+VCD={integration_vcd.relative_to(ROOT).as_posix()}",
        ],
    ):
        return 1

    if not unit_vcd.is_file() or unit_vcd.stat().st_size == 0:
        print(f"FAILED: interrupt controller waveform was not created: {unit_vcd}", file=sys.stderr)
        return 1
    if not integration_vcd.is_file() or integration_vcd.stat().st_size == 0:
        print(f"FAILED: integration waveform was not created: {integration_vcd}", file=sys.stderr)
        return 1

    scripts_dir = str(ROOT / "scripts")
    sys.path.insert(0, scripts_dir)
    import run_wave

    unit_gtkw = Path(run_wave.make_savefile_for(str(unit_vcd), "tb_interrupt_controller"))
    integration_gtkw = Path(
        run_wave.make_savefile_for(str(integration_vcd), "tb_dsd8_interrupt_top")
    )
    print(f"\nWaveform: {integration_vcd.relative_to(ROOT)}")
    print(f"GTKWave view: {integration_gtkw.relative_to(ROOT)}")
    print(f"Controller waveform: {unit_vcd.relative_to(ROOT)}")
    print(f"Controller GTKWave view: {unit_gtkw.relative_to(ROOT)}")

    if gtkwave:
        print("\nOpening GTKWave with the integration waveform...", flush=True)
        try:
            subprocess.Popen(
                [gtkwave, str(integration_vcd), str(integration_gtkw)],
                cwd=ROOT,
            )
        except OSError as exc:
            print(f"Could not launch GTKWave: {exc}", file=sys.stderr)
            print(f"Open this view manually: {integration_gtkw}", file=sys.stderr)
            return 1
    else:
        print(
            "\nGTKWave was not found. The waveform and GTKWave view were saved; "
            "install GTKWave or add it to PATH to open them automatically.",
            file=sys.stderr,
        )

    print("\nAll interrupt add-on tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
