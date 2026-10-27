# DSD-8 Processor Project

For a complete, beginner-friendly explanation of the frozen processor
architecture and optional timer/interrupt add-on, see
[`final.md`](final.md).

An 8-bit Harvard microprocessor designed in Verilog according to the **DSD-8 Specification v1.0**.

---

## 🚀 Quick Start

### 1. Run the Entire Regression (Unit Tests + 40-Test Conformance Suite)
```bash
python scripts/run_all.py
```
*Or using make:*
```bash
make all
```
> **Waves are automatic:** every run also writes a `.vcd` waveform + `.gtkw` GTKWave
> view per test into `sim/waves/` (9 unit + 40 conformance = 49 pairs).
> Pass `--no-waves` to `scripts/run_all.py` for the old wave-free quick regression.

### 2. Launch the Interactive Web Simulation Dashboard
```bash
python run_dashboard.py
```
Opens an interactive dashboard in your browser (`http://localhost:8080`) where you can:
- Step through CPU micro-cycles (`FETCH` → `EXECUTE` → `WRITEBACK`)
- Inspect registers R0–R7, condition flags (Z, N, C, V), and 256B data memory in real-time
- Simulate FPGA board hardware (Switches, Push-buttons, LEDs, 7-Segment display)
- Assemble and execute custom DSD-8 assembly programs
- View full 40/40 test conformance verification traces and ALU coverage

### 3. View Waveforms (GTKWave + VCD)
The bundled toolchain (`tools/iverilog/app/`) ships **Icarus Verilog 12.0** and **GTKWave 3.3**.
Every testbench carries an opt-in `+VCD=<file>` plusarg, and **the regression runner
(`python scripts/run_all.py` / `make all`) activates it automatically** — so a fresh
`.vcd` + `.gtkw` pair for every test appears in `sim/waves/` after each run.

One-command wave generation + viewer:
```bash
make wave TB=tb_alu                     # ALU unit testbench waves
make wave TB=tb_dsd8 TEST=T36           # conformance test T36 (multiply) waves
make wave TB=tb_dsd8 ASM=bubblesort     # bubble-sort demo waves
```
Or directly:
```bash
python scripts/run_wave.py tb_alu                     # opens GTKWave automatically
python scripts/run_wave.py tb_dsd8 --test T01         # PC/IR/FSM/retire-bus view
python scripts/run_wave.py tb_alu --no-view           # only produce sim/waves/*.vcd
```
Waveforms land in `sim/waves/` together with a `.gtkw` save file that pre-loads the important
signals (`clk`, `rst_n`, `retire` bus, `leds/seg`, plus CPU internals `pc_reg`, `instr_reg`,
`in_fetch`, FSM `state`). Open any `.vcd` manually with:
```bash
tools/iverilog/app/gtkwave/bin/gtkwave.exe sim/waves/tb_dsd8_T01.vcd
```

---

## 📁 Repository Directory Structure

```text
├── rtl/                   – Synthesizable Verilog modules (Frozen interfaces per §5)
│   ├── alu.v              – Purely combinational ALU with single 9-bit adder (R15)
│   ├── control_unit.v     – Multi-cycle FSM control unit and branch sequencer
│   ├── data_memory.v      – 256×8 DMEM with synchronous reset-clear (R16)
│   ├── dsd8_cpu.v         – Top-level processor core with trace interface (§5.2)
│   ├── dsd8_top.v         – System top level with FPGA board peripherals (§5.1)
│   ├── dsd8_interrupt_top.v – Optional system top with timer/interrupt add-on
│   ├── interrupt_controller.v – Polling timer/event peripheral (ports 0x50–0x5F)
│   ├── flags_reg.v        – Architectural Z, N, C, V flag registers
│   ├── instr_decoder.v    – Purely combinational 16-bit instruction decoder
│   ├── instr_memory.v     – 512×16 instruction memory loaded via $readmemh
│   ├── io_bus.v           – I/O bus controller with SLOW_ECHO handshake (§7.2)
│   ├── prog_counter.v     – 9-bit program counter with branch load
│   └── register_file.v    – 8×8 register file with R14 read-during-write semantics
│
├── tb/                    – Self-checking unit and system testbenches
│   ├── tb_alu.v           – Systematic unit test for all 8 ALU operations
│   ├── tb_alu_random.v    – 12,200 constrained-random vectors + corner-case coverage (R24/R25)
│   ├── tb_control_unit.v  – Unit test for FSM states, opcode decodes, and branch conditions
│   ├── tb_data_memory.v   – Unit test for DMEM clear on reset and walking ones
│   ├── tb_dsd8.v          – System testbench harness (§8.3) generating execution traces
│   ├── tb_flags_reg.v     – Unit test for flag register latching and holding
│   ├── tb_instr_decoder.v – Unit test for 5 instruction formats and field overlap
│   ├── tb_io_bus.v        – Unit test for port decoding and io_ready handshake
│   ├── tb_interrupt_controller.v – Unit test for timers, flags, and priority
│   ├── tb_dsd8_interrupt_top.v – CPU-level test of the polling interrupt add-on
│   ├── tb_prog_counter.v  – Unit test for PC reset, increment, load, and 511->0 wrap
│   ├── tb_register_file.v – Unit test for independent writes and R14 semantics
│   └── wave_dump.vh       – Shared opt-in +VCD waveform capture block
│
├── sim/                   – Simulation hex images, test programs, and golden traces
│   ├── multiply.asm       – Worked example B.1 (13 × 7 = 91)
│   ├── popcount.asm       – Worked example B.2 (Population count of 0xB7 = 6)
│   ├── bubblesort.asm     – Worked example B.3 (8-byte bubble sort in DMEM)
│   ├── interrupt_smoke.asm – CPU-level interrupt add-on smoke test
│   └── tests/             – Complete 40-test Conformance Suite (T01 - T40)
│
├── scripts/               – Build, verification, and regression scripts
│   ├── run_all.py         – Master test runner for unit tests and conformance suite
│   ├── run_wave.py        – One-command waveform runner (compile -> +VCD -> GTKWave)
│   └── generate_conformance.py – Generator for all 40 conformance programs and traces
│
├── web/                   – Interactive Web GUI Simulator & Dashboard
│   ├── index.html         – Modern HTML5 interface
│   ├── style.css          – Dark cyberpunk styling system
│   └── app.js             – Client-side DSD-8 emulator, live assembler & test runner
│
├── dsd8asm.py             – Official DSD-8 Assembler (ASM -> HEX)
├── dsd8sim.py             – Official Golden Reference Simulator (§8.2 Trace generator)
├── run_dashboard.py       – Web server launcher with live test API
└── Makefile               – Standard targets: all, test, conformance, lint, clean
```

### Optional Timer/Interrupt Add-on

The frozen CPU, standard I/O bus, and `dsd8_top` remain unchanged. To include
the polling-based timer/event peripheral, instantiate `dsd8_interrupt_top`
instead. It retains the standard board I/O and adds ports `0x50`–`0x5F`.
The CPU does not receive a hardware interrupt signal; software polls the IRQ
status and dispatches to handlers.

| Port(s) | Purpose |
|---|---|
| `0x50`–`0x51`, `0x54`–`0x55` | Timer A/B 16-bit counters (low byte, high byte) |
| `0x52`–`0x53`, `0x56`–`0x57` | Timer A/B 16-bit thresholds |
| `0x58` | IRQ flags in bits 0–3; bit 4 indicates an enabled pending source |
| `0x59` | Write 1 to clear IRQ flags |
| `0x5A`–`0x5B` | IRQ enables/vector-base readback and priority-encoded source |
| `0x5C` | Timer enable, count mode, and load/reset controls |
| `0x5D`–`0x5E` | Software event and manual IRQ triggers |

Timer mode 0 counts up to a threshold; mode 1 counts down from the threshold
and stops at zero. IRQ flags are sticky until cleared. See
[`doc/interrupt_addon.md`](doc/interrupt_addon.md) for bit-level definitions,
semantics, and the complete test procedure.

#### Build and test the add-on

Assemble the CPU-level smoke-test program, compile both add-on testbenches, and
run them with the bundled Icarus Verilog tools:

```powershell
python dsd8asm.py sim\interrupt_smoke.asm -o sim\interrupt_smoke.hex
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_interrupt_controller -o sim\tb_interrupt_controller.vvp tb\tb_interrupt_controller.v rtl\interrupt_controller.v
tools\iverilog\app\bin\vvp.exe sim\tb_interrupt_controller.vvp
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_dsd8_interrupt_top -o sim\tb_dsd8_interrupt_top.vvp rtl\*.v tb\tb_dsd8_interrupt_top.v
tools\iverilog\app\bin\vvp.exe sim\tb_dsd8_interrupt_top.vvp
```

The first test covers timers, flags, masking, and priority. The integration
test runs an assembled program that polls Timer A, updates the LEDs, clears the
IRQ flag, and halts.

---

## 🛠 Command Line Tools

### 1. Assembler (`dsd8asm.py`)
Assembles assembly files into 16-bit hex machine code:
```bash
python dsd8asm.py sim/multiply.asm -o sim/multiply.hex -v
```

### 2. Golden Reference Simulator (`dsd8sim.py`)
Simulates machine code and generates the official Section 8.2 execution trace:
```bash
python dsd8sim.py sim/multiply.hex -t sim/multiply_gold.trace
```

### 3. Run Individual Testbench via Icarus Verilog
```bash
tools/iverilog/app/bin/iverilog.exe -g2012 -o sim/tb_alu.vvp tb/tb_alu.v rtl/alu.v
tools/iverilog/app/bin/vvp.exe sim/tb_alu.vvp
```

---

## 📊 Verification & Conformance Score

- **Frozen-baseline self-checking unit testbenches:** 9 / 9 PASSED (100%)
- **Constrained-Random ALU Test (R24/R25):** 12,200 vectors, 0 errors, 100% coverage on all corner cases (`0x00`, `0x01`, `0x7F`, `0x80`, `0xFF`)
- **Conformance Suite (T01 – T40):** 40 / 40 PASSED (100.0% match with Golden Reference Model)
- **Interrupt add-on:** controller unit test and CPU-level polling integration test both pass
