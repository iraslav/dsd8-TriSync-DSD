# DSD-8 Processor Testing and Verification Report

**Project:** DSD-8 Processor — TrySync
**Verification date:** 2026-11-03
**Verification update:** Testing infrastructure fixes were verified on 2026-11-03. Processor RTL, expected results, and golden traces were not modified.

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

**This verification run:** **54 passed, 0 failed, 0 blocked** (12 module/testbench tests, 40 baseline conformance cases, and 2 additional conformance programs). RTL lint also passed.

| Test Name | Execution Status | Result | Details |
|---|---|---|---|
| `tb_alu.v` — directed ALU test | Executed | PASS | All directed ALU checks passed. |
| `tb_alu_random.v` — ALU random test | Executed | PASS | 12,200 vectors; zero mismatches and all documented corner operands covered. |
| `tb_alu_example.v` — worked ALU example | Executed | PASS | Compiled with `-g2012`; direct function-result indexing was replaced with a local 8-bit value and bit-select. Original vectors and expected results are unchanged. |
| `tb_control_unit.v` | Executed | PASS | Control and branch checks passed. |
| `tb_data_memory.v` | Executed | PASS | Data memory checks passed. |
| `tb_dsd8_interrupt_top.v` | Executed | PASS | Polling add-on integration test passed. |
| `tb_flags_reg.v` | Executed | PASS | Flag register checks passed. |
| `tb_instr_decoder.v` | Executed | PASS | Instruction decode checks passed. |
| `tb_interrupt_controller.v` | Executed | PASS | Timer, flags, masking, and priority checks passed. |
| `tb_io_bus.v` | Executed | PASS | Standard I/O checks passed. |
| `tb_prog_counter.v` | Executed | PASS | Program counter checks passed. |
| `tb_register_file.v` | Executed | PASS | Register file checks passed. |
| Unit runner (`scripts/run_unit_tests.py`) | Executed | PASS — 12/12 | Correctly recognized the different bench verdict formats; zero compilation/runtime failures or blocked benches. |
| Baseline conformance T01–T40 | Executed | PASS — 40/40 | DUT traces matched the baseline suite’s golden traces. |
| `sample01_multiply.asm` | Executed | PASS | DUT trace matched the generated golden reference trace; 51 retired instructions. |
| `sample02_popcount.asm` | Executed | PASS | DUT trace matched the generated golden reference trace; 44 retired instructions. |
| Conformance runner (`scripts/run_conformance.py`) | Executed | PASS — 2/2 | Uses the testbench’s `+IMAGE` and `+TRACE` runtime plusargs and compares traces. |
| `make lint` | Executed | PASS | Icarus syntax check of all RTL modules; zero errors. |

Test-case totals count each bench/program once: 12 unit/integration benches + 40 baseline cases + 2 additional sample programs = **54 PASS, 0 FAIL, 0 BLOCKED**. `make lint` is a separate successful check.

## D. Errors and Warnings

- **Initial syntax issue fixed:** Icarus does not accept a bit-select applied directly to a function-call result in this context. `expected_overflow` now stores the function result in a local `reg [7:0]` before selecting bit 7.
- **Path with spaces:** The bundled Windows Icarus launcher does not accept this workspace’s original spaced absolute path. Tests were run from a temporary `R:` `subst` alias; both Python runners preserve that alias when locating the repository root.
- **Test runner fixes:** The unit runner recognizes `PASS: <testbench>`, `STATUS: PASS`, and `TESTBENCH: PASS`; it reports compilation/no-verdict cases as BLOCKED, runtime/assertion errors as FAIL, and returns nonzero for either. The conformance runner now supplies `+IMAGE` and `+TRACE` at simulation time and compares DUT and golden traces.
- **Warnings/errors in requested verification:** None after the fixes. No dependencies were installed. Waveform GUI inspection and synthesis were not part of this infrastructure-fix verification.

## E. Integration Verification

The [dsd8_interrupt_top RTL](./rtl/dsd8_interrupt_top.v) connects the CPU and instruction memory to the existing standard I/O bus and the interrupt controller. It selects the controller for ports `0x50`–`0x5F`, routes reads through the controller-data mux, and combines the bus-ready signals. The [interrupt controller RTL](./rtl/interrupt_controller.v) exposes the documented counter, threshold, status, clear, enable/vector-base, priority-source, timer-control, event, and manual-trigger registers.

The standalone controller test passed for Timer A count-up, Timer B countdown, flag clearing, enable masking, priority selection, and event/manual flags. The CPU-level wrapper test passed through the documented I/O interface: the program configured Timer A, polled status at `0x58`, wrote LEDs at `0x02`, cleared the flag through `0x59`, and halted.

**Interrupt behavior is polling, not automatic hardware interrupt entry.** No interrupt pin is connected to the CPU. `0x5A` stores and reads back the vector-base nibble, but the CPU does not use it to calculate a handler address or vector automatically. The integration test demonstrates software polling and clearing, not hardware preemption or a full multi-source dispatcher.

The standard I/O, data memory, register file, control unit, ALU, and processor execution paths are exercised by the unit and conformance tests. `instr_memory` is exercised by the wrapper integration test, but it has no standalone unit testbench. The baseline `dsd8_top` board wrapper also lacks a direct top-level testbench.

## F. Waveform Results

Earlier verification generated the waveform pairs listed below. This testing-infrastructure run did not regenerate waveforms or open GTKWave; it ran the unit suite without VCD capture and baseline conformance with waves disabled. Existing [sim/waves/](./sim/waves/) files were left unchanged.

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

- Reconcile older interrupt documents with the RTL: [Timer_Counter_Interrupt_Specification.md](./Timer_Counter_Interrupt_Specification.md) describes the vector base as driving CPU handler-address calculation and labels `0x5A` write-only; [Interrupt_Quick_Reference.md](./Interrupt_Quick_Reference.md) also labels `0x5A` write-only and describes status bit 4 as any active flag. In RTL, `0x5A` is read/write, bit 4 means an **enabled** pending source, and the CPU does not vector. [Interrupt_Implementation_Roadmap.md](./Interrupt_Implementation_Roadmap.md) describes integration into `dsd8_top`, while the implementation uses the separate `dsd8_interrupt_top` wrapper. The newer [final.md](./final.md) and [doc/interrupt_addon.md](./doc/interrupt_addon.md) describe the polling behavior accurately.
- Add direct coverage for the baseline `dsd8_top` and `instr_memory`, timer 16-bit boundary/wrap behavior, additional mode/configuration combinations, and a multi-source software dispatcher if that is a project requirement.
- Run synthesis or FPGA implementation checks in the intended hardware toolchain; this verification covered simulation and RTL syntax only.

### Optional improvements

- Open the generated waveforms in GTKWave and visually validate the signal groups intended for the presentation.
- Update historical planning documents and test instructions so they distinguish implemented behavior from proposed or unimplemented features.

## H. Final Assessment

**The requested testing-infrastructure verification passed:** 12/12 unit/integration benches, 40/40 baseline conformance cases, and 2/2 additional conformance samples passed; `make lint` passed. No processor RTL, architecture, expected result, or golden trace was changed. Remaining work includes the documentation/coverage items above and verification outside this task, such as synthesis or visual GTKWave inspection.

## Commands Executed

The bundled Windows Icarus launcher does not work with this repository’s original absolute path containing spaces. Commands were run from a temporary `R:` alias. From PowerShell:

```powershell
subst R: "E:\University\BE-CSE Vll\DSD\Project DSD"
Push-Location R:\
New-Item -ItemType Directory -Force -Path build\unit | Out-Null
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_alu_example -o build\unit\tb_alu_example_explicit.vvp tb\tb_alu_example.v rtl\alu.v
tools\iverilog\app\bin\vvp.exe build\unit\tb_alu_example_explicit.vvp
python scripts/run_unit_tests.py
python scripts/run_conformance.py
python -c "import sys; sys.path.insert(0,'.'); from scripts.run_all import run_conformance_suite; sys.exit(0 if run_conformance_suite(with_waves=False) else 1)"
make lint
python -m py_compile scripts\run_unit_tests.py scripts\run_conformance.py
python -c "import sys; sys.path.insert(0,'scripts'); from run_unit_tests import classify_output; cases=[('PASS: tb_alu passed all unit checks!','tb_alu',0,'PASS'),('STATUS: PASS (vectors verified)','tb_alu_random',0,'PASS'),('FAIL R21: mismatch','tb_io_bus',0,'FAIL'),('TESTBENCH: PASS','tb_alu_example',1,'FAIL'),('simulator emitted no verdict','tb_alu',0,'BLOCKED')]; results=[classify_output(out,name,code)[0] for out,name,code,_ in cases]; print(list(zip(results,[expected for _,_,_,expected in cases]))); raise SystemExit(0 if results==[expected for _,_,_,expected in cases] else 1)"
Pop-Location
subst R: /d
```

The unit runner executed the directed, random, and example ALU tests along with every other `tb_*.v` unit/integration bench. The additional sample runner assembled both samples and compared their DUT traces with generated golden traces. The baseline suite was run through `run_conformance_suite(with_waves=False)` to avoid modifying waveforms.

## Generated Files

- Modified files: `tb/tb_alu_example.v`, `scripts/run_unit_tests.py`, `scripts/run_conformance.py`, and `TESTING_REPORT.md`.
- The runners created temporary `.vvp`, `.hex`, and trace files under `build/`; these outputs were removed after verification.
- No waveform files were generated or changed during this run. Existing waveform outputs from earlier project verification were retained.

No RTL, processor architecture, expected result, golden trace, or unrelated worktree file was modified.
