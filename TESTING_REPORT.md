# DSD-8 Processor Testing and Verification Report

**Project:** DSD-8 Processor — TrySync
**Verification date:** 2026-11-03
**Repository state tested:** Current working tree, including pre-existing local changes. No RTL or testbench source was edited for this verification.

## A. Project Overview

This verification exercised the DSD-8 baseline processor, its ALU and datapath/control modules, standard I/O, the 40-program conformance suite, sample assembly programs, and the optional timer/event controller and `dsd8_interrupt_top` wrapper. It also checked RTL syntax, generated VCD/GTKWave save files, and compared the add-on register behavior and documentation with the RTL.

The add-on is polling-based: it exposes sticky event flags to software and does **not** assert a CPU interrupt input or automatically vector execution to a handler.

## B. Environment

| Tool / environment | Version / status |
|---|---|
| Operating system | Windows 11 Pro, 64-bit, build 10.0.26200 |
| Python | 3.14.7 |
| Icarus Verilog (`iverilog`) | Bundled; 12.0 (devel), `s20150603-1539-g2693dd32b` |
| Icarus runtime (`vvp`) | Bundled; same 12.0 (devel) build |
| GNU Make | 4.4.1 |
| GTKWave | Bundled executable present; project documentation identifies it as 3.3. GTKWave was not launched or visually inspected. |
| Simulation flow | Icarus Verilog compile → `vvp`; baseline traces compared with `dsd8sim.py` |

The bundled Icarus executables were not on `PATH`. Direct execution of the project’s hard-coded absolute executable paths failed because this workspace path contains spaces. The passing suite runs used a temporary `R:` drive alias to avoid that tool/path interaction; no project source paths were changed.

## C. Test Results

**Unique test-case totals:** **56 passed, 0 behavioral assertion failures, 1 blocked** (`tb_alu_example.v`, compile failure). Runner-level failures are listed separately below and are not counted as RTL assertion failures.

| Test Name | Execution Status | Result | Details |
|---|---|---|---|
| `tb_alu.v` — ALU directed unit test | Executed | PASS | All eight ALU operations passed. |
| `tb_alu_random.v` — ALU constrained-random test | Executed | PASS | 12,200 vectors; zero mismatches; all documented corner operands covered. |
| `tb_prog_counter.v` — program counter | Executed | PASS | Included in the 9/9 baseline unit suite. |
| `tb_register_file.v` — register file | Executed | PASS | Included in the 9/9 baseline unit suite. |
| `tb_flags_reg.v` — flags register | Executed | PASS | Included in the 9/9 baseline unit suite. |
| `tb_instr_decoder.v` — instruction decoder | Executed | PASS | Included in the 9/9 baseline unit suite. |
| `tb_data_memory.v` — data memory | Executed | PASS | Included in the 9/9 baseline unit suite. |
| `tb_control_unit.v` — control unit | Executed | PASS | Included in the 9/9 baseline unit suite. |
| `tb_io_bus.v` — standard I/O bus | Executed | PASS | Included in the 9/9 baseline unit suite. |
| Baseline module unit suite (`scripts/run_all.py`) | Executed | PASS — 9/9 | All unit tests selected by the master runner passed. |
| Processor conformance T01–T40 | Executed | PASS — 40/40 | DUT retirement traces matched golden traces. T30 completed 772 instructions; T36–T38 exercised multiply, population count, and bubble sort. |
| `tests/conformance/sample01_multiply.asm` | Executed | PASS | Corrected runtime-argument invocation produced an exact RTL/reference trace match; 51 retired instructions. |
| `tests/conformance/sample02_popcount.asm` | Executed | PASS | Corrected runtime-argument invocation produced an exact RTL/reference trace match; 44 retired instructions. |
| `sim/multiply.asm` | Executed | PASS | Assembled, reference-simulated, and RTL trace matched; 51 retired instructions. |
| `sim/popcount.asm` | Executed | PASS | Assembled, reference-simulated, and RTL trace matched; 44 retired instructions. |
| `sim/bubblesort.asm` | Executed | PASS | Assembled, reference-simulated, and RTL trace matched; 478 retired instructions. |
| `tb_interrupt_controller.v` — Timer A/B, flags, masking, priority, event/manual sources | Executed | PASS | Self-checking testbench completed without errors. |
| `sim/interrupt_smoke.asm` + `tb_dsd8_interrupt_top.v` | Executed | PASS | CPU polled Timer A, wrote `0xA5` to LEDs, cleared the flag, and halted; integration test reported 48 cycles. The existing smoke image matched a fresh assembly. |
| `tb_alu_example.v` — worked ALU testbench | Attempted | BLOCKED | Icarus reports a syntax error at line 89 (`expected_result(...)[7]`) in both `-g2005` and `-g2012` modes. No test result was produced. |
| `make lint` | Executed | PASS | All RTL files compiled in Icarus null-target syntax mode; zero errors. |
| `scripts/run_unit_tests.py` as shipped | Executed | FAIL — runner | Reports 0/12 because it requires `TESTBENCH: PASS/FAIL`; 11 launched benches instead print other `PASS`/`STATUS: PASS` forms. The remaining `tb_alu_example.v` fails compilation. The master runner and the focused tests independently verified the applicable testbenches. |
| `scripts/run_conformance.py` as shipped | Executed | FAIL — runner | Both sample programs assembled and reference-simulated, but DUT compilation fails because the script uses `-P...IMAGE` and `-P...TRACE_FILE` parameters that the current `tb_dsd8` does not define. Compiling it and supplying its documented runtime `+IMAGE`/`+TRACE` arguments passed both comparisons. |
| `scripts/run_all.py` using the original absolute workspace path | Executed | FAIL — path/tool interaction | Icarus’s Windows launcher split the path at `E:\University\BE-CSE`. Re-running the same suite from the temporary `R:` alias passed all 9 unit tests and all 40 conformance tests. |

The 56 passing cases comprise 9 module tests, 40 baseline conformance programs, 2 add-on tests, 2 additional conformance samples, and 3 repository worked examples. Repeated executions through the discovery runner are not counted again.

## D. Errors and Warnings

- **Workspace path with spaces:** The first `scripts/run_all.py` invocation failed at Icarus compilation because of the absolute Windows path. The alias-based rerun completed successfully; this was not an RTL failure.
- **Unit-test discovery mismatch:** `scripts/run_unit_tests.py` expects output markers documented in [tb/README.md](./tb/README.md), but most current benches use different PASS strings. The runner consequently labels successful simulations as errors. It also discovers `tb_alu_example.v`, which does not compile under the bundled Icarus in either tested language mode.
- **Conformance runner mismatch:** `scripts/run_conformance.py` still uses compile-time parameter overrides, while [tb/tb_dsd8.v](./tb/tb_dsd8.v) reads the image and trace paths from `+IMAGE` and `+TRACE` runtime plusargs. The manual runtime-argument flow passed both sample comparisons.
- **Non-fatal simulator warnings:** The short assembled images produce `$readmemh` “Not enough words” warnings because the harness has 512 instruction slots; the harness initializes the remaining slots before loading each image. Add-on waveform runs also emit Icarus’s non-fatal “Package ($unit) is not dumpable with VCD” warning.
- **GTKWave:** VCDs and `.gtkw` save files were generated. GTKWave was not launched, and no visual waveform inspection is claimed.
- **Interrupt test launcher:** `run_interrupt_tests.py` was not launched as a wrapper because it automatically starts GTKWave. Its assembly, controller test, integration test, and waveform-generation steps were run directly without opening the GUI.
- **Missing dependencies:** None for the executed tests. No software was installed.

## E. Integration Verification

The [dsd8_interrupt_top RTL](./rtl/dsd8_interrupt_top.v) connects the CPU and instruction memory to the existing standard I/O bus and the interrupt controller. It selects the controller for ports `0x50`–`0x5F`, routes reads through the controller-data mux, and combines the bus-ready signals. The [interrupt controller RTL](./rtl/interrupt_controller.v) exposes the documented counter, threshold, status, clear, enable/vector-base, priority-source, timer-control, event, and manual-trigger registers.

The standalone controller test passed for Timer A count-up, Timer B countdown, flag clearing, enable masking, priority selection, and event/manual flags. The CPU-level wrapper test passed through the documented I/O interface: the program configured Timer A, polled status at `0x58`, wrote LEDs at `0x02`, cleared the flag through `0x59`, and halted.

**Interrupt behavior is polling, not automatic hardware interrupt entry.** No interrupt pin is connected to the CPU. `0x5A` stores and reads back the vector-base nibble, but the CPU does not use it to calculate a handler address or vector automatically. The integration test demonstrates software polling and clearing, not hardware preemption or a full multi-source dispatcher.

The standard I/O, data memory, register file, control unit, ALU, and processor execution paths are exercised by the unit and conformance tests. `instr_memory` is exercised by the wrapper integration test, but it has no standalone unit testbench. The baseline `dsd8_top` board wrapper also lacks a direct top-level testbench.

## F. Waveform Results

Waveform generation succeeded. The full regression generated/updated **49 baseline pairs** (9 unit testbenches and T01–T40). Additional focused pairs were generated for the controller, CPU/add-on integration, and the three worked programs. The current [sim/waves/](./sim/waves/) directory contains 57 VCD files and 57 GTKWave save files, including pairs that were already present before this verification.

New focused waveform names:

- `verified_interrupt_controller.vcd` / `.gtkw`
- `verified_dsd8_interrupt_top.vcd` / `.gtkw`
- `sample_multiply.vcd` / `.gtkw`
- `sample_popcount.vcd` / `.gtkw`
- `sample_bubblesort.vcd` / `.gtkw`

Baseline waveform names are `tb_<unit>.vcd` and `T01.vcd` through `T40.vcd`, each paired with a `.gtkw` save file.

The VCD headers include useful signals:

- **CPU/conformance:** `pc_reg`, `pc_out`, `instr_reg`, `imem_data`, `alu_result`, ALU flags, `retire`, `retire_rf_we`, `retire_rf_addr`, `retire_rf_data`, memory writeback, I/O ports/data, and control state.
- **Timer/controller:** `timer_a_count`, `timer_b_count`, thresholds, enables, `timer_a_irq`, `timer_b_irq`, event/manual flags, `irq_enable`, `irq_source`, `irq_any_pending`, and I/O status/data.
- **Wrapper integration:** CPU internals plus `irq_port_selected`, controller I/O signals, LEDs, and `halted`.

The generated add-on `.gtkw` files select top-level testbench signals by default; for a detailed view, add the hierarchical CPU and controller signals from the VCD in GTKWave. Useful presentation captures are the multiply or bubble-sort CPU waveforms and the interrupt integration waveform showing the Timer A count, pending flag, CPU polling I/O, LED write, and flag clear. GTKWave GUI inspection remains outstanding.

## G. Remaining Work

### Critical issues

- None identified by the executed tests. This is not a claim of exhaustive formal or hardware verification.

### Important improvements

- Align `scripts/run_unit_tests.py` with the PASS formats actually emitted by the current benches, and resolve or replace the uncompilable `tb_alu_example.v`.
- Update `scripts/run_conformance.py` to use the current `tb_dsd8` runtime plusargs.
- Reconcile older interrupt documents with the RTL: [Timer_Counter_Interrupt_Specification.md](./Timer_Counter_Interrupt_Specification.md) describes the vector base as driving CPU handler-address calculation and labels `0x5A` write-only; [Interrupt_Quick_Reference.md](./Interrupt_Quick_Reference.md) also labels `0x5A` write-only and describes status bit 4 as any active flag. In RTL, `0x5A` is read/write, bit 4 means an **enabled** pending source, and the CPU does not vector. [Interrupt_Implementation_Roadmap.md](./Interrupt_Implementation_Roadmap.md) describes integration into `dsd8_top`, while the implementation uses the separate `dsd8_interrupt_top` wrapper. The newer [final.md](./final.md) and [doc/interrupt_addon.md](./doc/interrupt_addon.md) describe the polling behavior accurately.
- Add direct coverage for the baseline `dsd8_top` and `instr_memory`, timer 16-bit boundary/wrap behavior, additional mode/configuration combinations, and a multi-source software dispatcher if that is a project requirement.
- Run synthesis or FPGA implementation checks in the intended hardware toolchain; this verification covered simulation and RTL syntax only.

### Optional improvements

- Open the generated waveforms in GTKWave and visually validate the signal groups intended for the presentation.
- Update historical planning documents and test instructions so they distinguish implemented behavior from proposed or unimplemented features.

## H. Final Assessment

**Partially verified.** The baseline module suite and all 40 processor conformance tests passed, and the timer controller, polling integration, sample programs, and RTL syntax check passed. However, the generic test runner and sample conformance runner are inconsistent with current testbench interfaces, one available example testbench does not compile, several older documents overstate vectoring behavior, and neither GTKWave visual inspection nor synthesis/hardware verification was performed.

## Commands Executed

Commands below are shown relative to the repository root unless noted. Icarus-dependent commands were run from a temporary `R:` alias for the workspace to avoid the path-with-spaces launcher issue.

```powershell
python scripts/run_all.py
subst R: "E:\University\BE-CSE Vll\DSD\Project DSD"
# From R:\, with the bundled Icarus bin directory added to PATH:
$env:PATH = "R:\tools\iverilog\app\bin;$env:PATH"
python scripts/run_all.py
python scripts/run_unit_tests.py
python scripts/run_conformance.py
make lint
```

The following focused commands were also run from `R:\`:

```powershell
python dsd8asm.py sim\interrupt_smoke.asm -o sim\interrupt_smoke_verified.hex
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_interrupt_controller -o sim\verified_tb_interrupt_controller.vvp tb\tb_interrupt_controller.v rtl\interrupt_controller.v
tools\iverilog\app\bin\vvp.exe sim\verified_tb_interrupt_controller.vvp +VCD=sim/waves/verified_interrupt_controller.vcd
$rtl = Get-ChildItem rtl -Filter '*.v' -File | Sort-Object Name | ForEach-Object { $_.FullName }
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_dsd8_interrupt_top -o sim\verified_tb_dsd8_interrupt_top.vvp @rtl tb\tb_dsd8_interrupt_top.v
tools\iverilog\app\bin\vvp.exe sim\verified_tb_dsd8_interrupt_top.vvp +VCD=sim/waves/verified_dsd8_interrupt_top.vcd
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_alu_example -o sim\verified_tb_alu_example.vvp tb\tb_alu_example.v rtl\alu.v
```

For the two `tests\conformance` programs, `tb/tb_dsd8.v` was compiled with the following RTL dependencies and then run with its runtime arguments:

```powershell
python tools\dsd8asm.py tests\conformance\sample01_multiply.asm -o build\conformance\sample01_multiply.hex
python tools\dsd8sim.py build\conformance\sample01_multiply.hex --trace build\conformance\sample01_multiply.gold.trace
python tools\dsd8asm.py tests\conformance\sample02_popcount.asm -o build\conformance\sample02_popcount.hex
python tools\dsd8sim.py build\conformance\sample02_popcount.hex --trace build\conformance\sample02_popcount.gold.trace
$sources = @('rtl/dsd8_cpu.v','rtl/prog_counter.v','rtl/instr_memory.v','rtl/instr_decoder.v','rtl/register_file.v','rtl/alu.v','rtl/flags_reg.v','rtl/data_memory.v','rtl/control_unit.v','rtl/io_bus.v','sim/peripherals.v','tb/tb_dsd8.v')
tools\iverilog\app\bin\iverilog.exe -g2005 -o build\conformance\sample_harness.vvp @sources
tools\iverilog\app\bin\vvp.exe build\conformance\sample_harness.vvp +IMAGE=build/conformance/sample01_multiply.hex +TRACE=build/conformance/sample01_multiply.dut.trace
tools\iverilog\app\bin\vvp.exe build\conformance\sample_harness.vvp +IMAGE=build/conformance/sample02_popcount.hex +TRACE=build/conformance/sample02_popcount.dut.trace
```

Each DUT trace was compared with its `.gold.trace` using this normalization and equality check (with the corresponding sample name substituted):

```powershell
python -c "from pathlib import Path; a=[x.strip().upper() for x in Path('build/conformance/sample01_multiply.dut.trace').read_text().splitlines() if x.strip()]; b=[x.strip().upper() for x in Path('build/conformance/sample01_multiply.gold.trace').read_text().splitlines() if x.strip()]; print('sample01_multiply RTL trace comparison:', 'PASS' if a==b else 'FAIL', 'DUT lines=',len(a),'gold lines=',len(b)); raise SystemExit(0 if a==b else 1)"
python -c "from pathlib import Path; a=[x.strip().upper() for x in Path('build/conformance/sample02_popcount.dut.trace').read_text().splitlines() if x.strip()]; b=[x.strip().upper() for x in Path('build/conformance/sample02_popcount.gold.trace').read_text().splitlines() if x.strip()]; print('sample02_popcount RTL trace comparison:', 'PASS' if a==b else 'FAIL', 'DUT lines=',len(a),'gold lines=',len(b)); raise SystemExit(0 if a==b else 1)"
```

The three `sim\` worked examples were run in a PowerShell loop, assembling, reference-simulating, executing against the same `tb_dsd8` harness, producing a VCD, and comparing DUT/golden traces:

```powershell
foreach ($name in @('multiply','popcount','bubblesort')) {
    python tools\dsd8asm.py "sim\$name.asm" -o "build\verification_samples_20261103\$name.hex"
    python tools\dsd8sim.py "build\verification_samples_20261103\$name.hex" --trace "build\verification_samples_20261103\$name.gold.trace"
    tools\iverilog\app\bin\vvp.exe "build\verification_samples_20261103\sample_harness.vvp" "+IMAGE=build/verification_samples_20261103/$name.hex" "+TRACE=build/verification_samples_20261103/$name.dut.trace" "+VCD=sim/waves/sample_$name.vcd"
}
```

Before that loop, the shared worked-example harness was compiled with:

```powershell
$sources = @('rtl/dsd8_cpu.v','rtl/prog_counter.v','rtl/instr_memory.v','rtl/instr_decoder.v','rtl/register_file.v','rtl/alu.v','rtl/flags_reg.v','rtl/data_memory.v','rtl/control_unit.v','rtl/io_bus.v','sim/peripherals.v','tb/tb_dsd8.v')
tools\iverilog\app\bin\iverilog.exe -g2005 -o build\verification_samples_20261103\sample_harness.vvp @sources
```

The traces were compared after each run using normalized line equality:

```powershell
python -c "from pathlib import Path; import sys; a=[x.strip().upper() for x in Path('$outdir/$name.dut.trace').read_text().splitlines() if x.strip()]; b=[x.strip().upper() for x in Path('$outdir/$name.gold.trace').read_text().splitlines() if x.strip()]; print('$name trace comparison:', 'PASS' if a==b else 'FAIL', 'retired instructions=',len(a)); raise SystemExit(0 if a==b else 1)"
python -c "import sys; sys.path.insert(0,'scripts'); import run_wave; run_wave.make_savefile_for('sim/waves/sample_$name.vcd','tb_dsd8')"
```

The add-on `.gtkw` files were generated with:

```powershell
python -c "import sys; sys.path.insert(0,'scripts'); import run_wave; print(run_wave.make_savefile_for('sim/waves/verified_interrupt_controller.vcd','tb_interrupt_controller')); print(run_wave.make_savefile_for('sim/waves/verified_dsd8_interrupt_top.vcd','tb_dsd8_interrupt_top'))"
```

GTKWave itself was not opened.

## Generated Files

- `TESTING_REPORT.md`
- Baseline waveform outputs under `sim/waves/`: 9 unit-test VCD/GTKWave pairs and 40 conformance VCD/GTKWave pairs.
- Focused waveform outputs listed in Section F.
- Test-runner build products and traces were written under `build/` and `sim/`. Temporary `build/` products, the duplicate `sim/interrupt_smoke_verified.hex`, and focused `.vvp` files were removed after verification; the waveforms were retained.

The pre-existing `sim/interrupt_smoke.hex` was not overwritten; it was compared with a freshly assembled image and matched. No project RTL, testbench, assembler, or documentation source was modified for this task.
