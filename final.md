# DSD-8 Microprocessor: Complete Architecture and User Guide

## 1. What this document covers

This guide explains the DSD-8 microprocessor from two perspectives:

- **The frozen baseline**: the original, fixed DSD-8 processor architecture and
  its standard I/O system.
- **The optional timer/interrupt add-on**: an additional I/O peripheral that
  works with the existing CPU without changing its instruction set or RTL.

It is intended for readers with and without a digital-design background. Plain
language introductions are followed by the hardware details. The implementation
and test commands describe the current project files; they are not a proposal
to change the frozen baseline.

> **Important distinction:** DSD-8 does not have hardware interrupt entry,
> interrupt pins, an interrupt stack, or automatic vectoring. The add-on
> produces sticky event flags. The program checks those flags using ordinary
> `IN`, branch, and `OUT` instructions, then runs the appropriate handler in
> software. This is called **polling-based interrupt handling**.

## 2. At a glance

| Property                             | DSD-8 baseline                                       |
| ------------------------------------ | ---------------------------------------------------- |
| Processor/data width                 | 8 bits                                               |
| Instruction width                    | 16 bits                                              |
| Architecture                         | Harvard: separate instruction and data memories      |
| Instruction memory                   | 512 words × 16 bits, addresses `0x000`–`0x1FF` |
| Data memory                          | 256 bytes, addresses `0x00`–`0xFF`              |
| General-purpose registers            | Eight 8-bit registers, `R0`–`R7`                |
| Condition flags                      | `Z`, `N`, `C`, `V`                           |
| Instruction set                      | 16 opcodes, including `NOP` and `HLT`            |
| CPU execution model                  | Multi-cycle finite-state machine                     |
| Standard I/O address space           | 256 8-bit port addresses                             |
| Optional add-on ports                | `0x50`–`0x5F`                                   |
| Baseline CPU modification for add-on | None                                                 |

The small size is intentional: it makes the instruction path, control logic,
memory behavior, and I/O protocol understandable and testable.

## 3. Complete system view

### 3.1 Baseline system

```text
                     +-------------------------+
                     |     Instruction Memory  |
                     |     512 x 16-bit words  |
                     +------------+------------+
                                  | instruction
                                  v
+-------------------+   +---------+----------+   +--------------------------+
| Program Counter   |-->| Decoder / CPU Core |<->| Data Memory 256 x 8-bit  |
| 9-bit address     |   | Control + Datapath |   +--------------------------+
+-------------------+   +----+----------+----+
                             |          |
                   register / ALU    I/O request
                                        |
                                        v
                              +---------+----------+
                              | Standard I/O Bus   |
                              | ports 0x00–0xFF    |
                              +----+----------+----+
                                   |          |
                           switches/buttons  LEDs/display
```

### 3.2 System with the optional add-on

```text
                       +----------------------------+
                       | dsd8_interrupt_top         |
                       |                            |
                       |   unchanged DSD-8 CPU      |
                       |       |                    |
                       |       +---- I/O bus -------+---- standard I/O bus
                       |       |                    |
                       |       +------------------------ interrupt controller
                       +----------------------------+       ports 0x50–0x5F
```

The new top-level wrapper is `rtl/dsd8_interrupt_top.v`. It instantiates the
same CPU, instruction memory, and standard I/O bus as the baseline, and adds
`rtl/interrupt_controller.v`. The original `dsd8_top`, `dsd8_cpu`, and
`io_bus` remain unchanged. The add-on therefore reuses the processor's
existing `IN`/`OUT` mechanism rather than adding a CPU interrupt input.

## 4. How a program runs

Think of the processor as a small workbench:

1. The **program counter** points to the next instruction.
2. The **instruction memory** supplies the 16-bit instruction at that address.
3. The **decoder** identifies its opcode and fields.
4. The **control unit** coordinates the required register, ALU, memory, or I/O
   operation.
5. The **program counter** advances or changes to a branch target.
6. When the instruction completes, the CPU emits a **retire** indication used
   by the verification interface.

The implemented control unit uses these states:

| State         | Purpose                                                               |
| ------------- | --------------------------------------------------------------------- |
| `FETCH`     | Capture the instruction word and its address.                         |
| `EXECUTE`   | Decode the operation and present any required I/O request.            |
| `IO_WAIT`   | Keep an I/O request active while the addressed system is not ready.   |
| `WRITEBACK` | Commit register, memory, flag, and/or PC changes; retire instruction. |
| `HALTED`    | Stop execution after `HLT` until reset.                             |

Ordinary instructions generally take three clock-state steps (`FETCH`,
`EXECUTE`, `WRITEBACK`). An I/O instruction can take longer if `io_ready` is
low. The CPU holds the instruction and its bus request while it waits, and
completes only after the peripheral is ready. `HLT` retires and then leaves the
CPU halted; reset is required to start again.

### 4.1 The main hardware blocks

| Block                               | What it does                                                                                                 |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Program counter (PC)**      | Holds a 9-bit instruction address. It increments to the next word or loads a jump/branch target.             |
| **Instruction memory (IMEM)** | Supplies read-only 16-bit instructions. It contains 512 words and is initialized from a hex image.           |
| **Instruction decoder**       | Splits an instruction into opcode, register numbers, immediate, branch target, or I/O port fields.           |
| **Control unit**              | A finite-state machine that enables the correct datapath actions and handles I/O waits and branch decisions. |
| **Register file**             | Eight 8-bit general-purpose registers with two combinational read ports and one clocked write port.          |
| **ALU**                       | Performs arithmetic, logical, shift, and compare operations and calculates flags.                            |
| **Flags register**            | Saves the ALU condition flags until another flag-setting instruction updates them.                           |
| **Data memory (DMEM)**        | 256 bytes of readable and writable storage.                                                                  |
| **I/O bus**                   | Decodes 8-bit port numbers, returns input data, accepts output data, and supplies the ready handshake.       |
| **Writeback mux**             | Selects which value is written to a register: ALU result, data-memory byte, immediate, or I/O input.         |

The implementation of these blocks is in the `rtl/` folder. `dsd8_cpu.v`
connects the processor-core blocks; `dsd8_top.v` connects the core to memories
and board I/O.

The register file's two read ports are combinational, so source values are
available to the datapath without a separate read instruction. The single
write port commits a selected result on a clock edge. If a location is read
and written on the same edge, the register-file implementation's read signals
represent the old stored value.

## 5. Programmer-visible model

### 5.1 Registers and numbers

The program can directly use eight registers, `R0` through `R7`. Each holds
one unsigned 8-bit pattern (`0x00`–`0xFF`). The same bit pattern can also be
interpreted as a signed two's-complement value (`-128`–`127`), but arithmetic
still wraps to eight bits.

There is no dedicated stack pointer, link register, or hardware call/return
mechanism. The baseline ISA also has no subroutine call, multiply, indexed
addressing, or add-immediate instruction. Software builds larger operations
from the available instructions.

### 5.2 Condition flags

The flags are stored in the order `{Z, N, C, V}`:

| Flag                       | Meaning                                                                                                  |
| -------------------------- | -------------------------------------------------------------------------------------------------------- |
| `Z` — Zero              | The 8-bit result is zero.                                                                                |
| `N` — Negative          | Bit 7 of the result is 1. This is the sign bit for a signed interpretation.                              |
| `C` — Carry / no borrow | For addition, the ninth carry bit. For subtraction and compare, 1 means no borrow (`a >= b` unsigned). |
| `V` — Overflow          | The signed two's-complement result cannot be represented in 8 bits.                                      |

Only `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SHL`, `SHR`, and `CMP` update flags.
Other instructions—including loads, stores, I/O, and branches—leave the
previous flags unchanged.

`CMP a, b` calculates the flags as if it subtracted `b` from `a`, but discards
the numeric result and does not change a general-purpose register. After a
compare, `C=1` means `a >= b` as unsigned values, and `Z=1` means equality.

### 5.3 Memory and reset

**Instruction memory** is 512 words of 16 bits. The PC is 9 bits wide, so it
can address every word. Instructions are read-only to the program and are
loaded from the image selected by the `IMAGE` parameter.

**Data memory** is 256 bytes. An 8-bit register supplies its address. Reads
are combinational and writes occur on a clock edge. On reset, every data-memory
byte is cleared to zero.

The baseline reset is synchronous and active-low (`rst_n`). During reset the
PC is cleared to zero, all eight registers and flags are cleared, DMEM is
cleared, and the processor is made ready to run. Execution begins at
instruction address `0x000`.

## 6. Instruction set

Every instruction is a 16-bit word. Bits `[15:12]` always contain the 4-bit
opcode. The remaining fields are interpreted according to the instruction
format.

### 6.1 Instruction reference

|  Opcode | Assembly form                      | Operation                                                                   |
| ------: | ---------------------------------- | --------------------------------------------------------------------------- |
| `0x0` | `NOP`                            | Do nothing; flags unchanged.                                                |
| `0x1` | `LDI Rd, imm8`                   | Load an 8-bit constant into a register.                                     |
| `0x2` | `LD Rd, [Rs1]`                   | Load a byte from data memory at the address in `Rs1`.                     |
| `0x3` | `ST [Rs1], Rs2`                  | Store the byte in `Rs2` to data memory at the address in `Rs1`.         |
| `0x4` | `ADD Rd, Rs1, Rs2`               | Add two register values and set flags.                                      |
| `0x5` | `SUB Rd, Rs1, Rs2`               | Subtract `Rs2` from `Rs1`, save result in `Rd`, set flags.            |
| `0x6` | `AND Rd, Rs1, Rs2`               | Bitwise AND and set flags.                                                  |
| `0x7` | `OR Rd, Rs1, Rs2`                | Bitwise OR and set flags.                                                   |
| `0x8` | `XOR Rd, Rs1, Rs2`               | Bitwise exclusive OR and set flags.                                         |
| `0x9` | `SHL Rd, Rs1`                    | Shift `Rs1` left one bit; old bit 7 goes to carry.                        |
| `0xA` | `SHR Rd, Rs1`                    | Logical shift right one bit; old bit 0 goes to carry and zero enters bit 7. |
| `0xB` | `CMP Rs1, Rs2`                   | Compare by subtraction; update flags only.                                  |
| `0xC` | `JMP addr9`                      | Unconditionally jump to an absolute 9-bit instruction address.              |
| `0xD` | `Bcc addr9`                      | Branch to an absolute address when the selected condition holds.            |
| `0xE` | `IN Rd, port` / `OUT port, Rs` | Read a port into a register or write a register to a port.                  |
| `0xF` | `HLT`                            | Stop the processor until reset.                                             |

### 6.2 Branch conditions

`Bcc` uses the 3-bit condition field and the current flags:

| Branch  | Condition                                               |
| ------- | ------------------------------------------------------- |
| `BEQ` | `Z = 1`, equal                                        |
| `BNE` | `Z = 0`, not equal                                    |
| `BCS` | `C = 1`, unsigned greater-than-or-equal after compare |
| `BCC` | `C = 0`, unsigned less-than after compare             |
| `BMI` | `N = 1`                                               |
| `BPL` | `N = 0`                                               |
| `BVS` | `V = 1`                                               |
| `BVC` | `V = 0`                                               |

All branch targets are absolute instruction addresses between `0x000` and
`0x1FF`. The PC wraps within its 9-bit range.

### 6.3 Assembly and encoding

The assembler accepts one instruction per line, labels ending with `:`, and
comments starting with `;`. Register names are `R0`–`R7`. Numeric values may
be decimal, hexadecimal (`0x`), or binary (`0b`). Labels can be used as jump
and branch targets.

For orientation, `LDI R2, 13` is encoded as `0x140D`: opcode `1`, destination
register `R2`, and immediate byte `13`. `OUT 0x02, R3` writes the value in
`R3` to port `0x02`.

The assembler also supports convenience forms:

- `MOV Rd, Rs` expands to `OR Rd, Rs, Rs`.
- `NOT Rd, Rs, Rmask` expands to `XOR Rd, Rs, Rmask`; `Rmask` must contain the
  desired inversion mask, commonly `0xFF`.

These are assembler conveniences, not extra CPU opcodes. Since the expansion
uses `OR` or `XOR`, these convenience forms also update flags as those ALU
instructions do.

### 6.4 Instruction word formats

The opcode is always bits `[15:12]`. The remaining fields depend on the opcode:

| Format          | Bit fields, from most significant to least significant                                                  | Used by                                                               |
| --------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Register (R)    | `opcode[15:12]`, `rd[11:9]`, `rs1[8:6]`, `rs2[5:3]`, reserved `[2:0]`                         | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SHL`, `SHR`, `CMP` |
| Immediate (I)   | `opcode[15:12]`, `rd[11:9]`, reserved bit `[8]`, `imm8[7:0]`                                    | `LDI`                                                               |
| Memory (M)      | `opcode[15:12]`, destination/data register `[11:9]`, address register `[8:6]`, reserved `[5:0]` | `LD`, `ST`                                                        |
| Jump/branch (J) | `opcode[15:12]`, `cond[11:9]`, absolute `addr9[8:0]`                                              | `JMP`, conditional branches                                         |
| Port (P)        | `opcode[15:12]`, register `[11:9]`, direction bit `[8]`, port `[7:0]`                           | `IN`, `OUT`                                                       |

For port instructions, direction bit 0 means input (`IN`) and 1 means output
(`OUT`). The register field is the destination for `IN` and the source for
`OUT`. `CMP` does not use a destination register; `SHL` and `SHR` do not use
`rs2`. Bits designated reserved by the ISA should be zero in assembled
instructions.

### 6.5 ALU calculation details

The implemented ALU uses one 9-bit adder for addition, subtraction, and
comparison:

- Addition: `a + b`
- Subtraction/comparison: `a + (~b) + 1`

The low eight bits are the result. The ninth bit becomes carry. For subtraction,
carry 1 means no borrow. Signed overflow is derived from the operand and result
sign bits. Logical operations clear carry and overflow; shifts put the shifted
out bit into carry and clear overflow. `SHR` is strictly logical: zero is
shifted into bit 7.

## 7. Baseline I/O subsystem

The I/O instruction address is an 8-bit port number (`0x00`–`0xFF`). I/O is
separate from data memory: `IN`/`OUT` access the port bus, while `LD`/`ST`
access DMEM.

- `IN Rd, port` reads the value presented by the selected peripheral.
- `OUT port, Rs` presents the selected register's value to the peripheral.
- An unmapped read returns `0x00`; an unmapped write is discarded.
- The CPU holds the I/O request and waits if `io_ready` is low.
- I/O instructions do not change the condition flags.

### 7.1 Standard port map

|     Port | Direction  | Function                                                          |
| -------: | ---------- | ----------------------------------------------------------------- |
| `0x00` | Read       | Eight slide switches.                                             |
| `0x01` | Read       | Five push buttons in bits `[4:0]`; bits `[7:5]` read as zero. |
| `0x02` | Write      | Eight latched board LEDs.                                         |
| `0x10` | Write      | Seven-segment segment value; only the low seven bits are latched. |
| `0x11` | Write      | Seven-segment digit enables; only the low four bits are latched.  |
| `0x40` | Read/write | `SLOW_ECHO` test peripheral.                                    |

The segment port supplies segment bits; it does not itself implement a
software-to-digit conversion routine. The board wiring and display scanning
are the responsibility of the system that connects these outputs.

### 7.2 Ready handshake and `SLOW_ECHO`

For a normal mapped port, the baseline bus is ready immediately. `SLOW_ECHO`
is a test peripheral used to prove that the CPU can wait for a slower device.
It stores the written byte and uses the low three bits as a short delay. A
write starts that delay; a read starts a delay based on the stored value. While
it is busy, `io_ready` is low and the CPU remains in its I/O wait behavior
until ready returns high.

The `io_ready` signal is a bus-level signal from the baseline I/O bus. In the
interrupt-enabled wrapper, the add-on is additionally qualified by the
baseline ready signal, preserving the existing wait protocol.

## 8. Frozen baseline: what stays fixed

The term **frozen baseline** refers to the original processor requirements and
interfaces. The baseline ISA, instruction encodings, register model, memories,
CPU module interface, baseline I/O module, and `dsd8_top` are not modified by
the timer/interrupt add-on.

The key frozen RTL files are:

| File                    | Baseline responsibility                                       |
| ----------------------- | ------------------------------------------------------------- |
| `rtl/dsd8_cpu.v`      | Processor-core datapath, instruction flow, and trace outputs. |
| `rtl/control_unit.v`  | Multi-cycle execution control, branches, I/O wait, and halt.  |
| `rtl/instr_decoder.v` | Instruction field extraction.                                 |
| `rtl/prog_counter.v`  | 9-bit program address.                                        |
| `rtl/instr_memory.v`  | 512 × 16-bit program image.                                  |
| `rtl/register_file.v` | Eight general-purpose 8-bit registers.                        |
| `rtl/alu.v`           | Arithmetic, logic, shift, compare, and flag calculations.     |
| `rtl/flags_reg.v`     | Architectural flag storage.                                   |
| `rtl/data_memory.v`   | 256 × 8-bit data memory.                                     |
| `rtl/io_bus.v`        | Standard ports and ready-handshake behavior.                  |
| `rtl/dsd8_top.v`      | Original system-level integration and board interface.        |

The optional system does not replace these files or change the CPU's
instruction set. It uses a separate top-level module, described next.

## 9. Optional timer and polling-interrupt add-on

### 9.1 What it adds

The add-on provides two independent 16-bit timer counters and four sticky
event sources:

1. Timer A
2. Timer B
3. Software-triggered Event
4. Software-triggered Manual IRQ

The event sources are **not asynchronous CPU interrupts**. A timer or software
trigger sets a status flag in the peripheral. The running program must poll
the status port, decide what action to take, perform it, and clear the flag.
The add-on demonstrates the software organization of interrupt handling
without changing the processor.

### 9.2 Register map

|     Port | Access | Register and behavior                                                                               |
| -------: | :----: | --------------------------------------------------------------------------------------------------- |
| `0x50` |  R/W  | Timer A counter bits `[7:0]`.                                                                     |
| `0x51` |  R/W  | Timer A counter bits `[15:8]`.                                                                    |
| `0x52` |   W   | Timer A threshold bits `[7:0]`.                                                                   |
| `0x53` |   W   | Timer A threshold bits `[15:8]`.                                                                  |
| `0x54` |  R/W  | Timer B counter bits `[7:0]`.                                                                     |
| `0x55` |  R/W  | Timer B counter bits `[15:8]`.                                                                    |
| `0x56` |   W   | Timer B threshold bits `[7:0]`.                                                                   |
| `0x57` |   W   | Timer B threshold bits `[15:8]`.                                                                  |
| `0x58` |   R   | IRQ status: bits 0–3 are raw sticky flags; bit 4 is enabled-pending OR.                            |
| `0x59` |   W   | Write 1 in bits 0–3 to clear the matching sticky flag.                                             |
| `0x5A` |  R/W  | Write source enables in bits 0–3 and vector-base nibble in bits 7–4; read back the stored fields. |
| `0x5B` |   R   | Priority-encoded source ID in bits 3–0; upper bits read zero.                                      |
| `0x5C` |   W   | Timer controls: A enable/mode/load in bits 0/1/2; B in bits 3/4/5.                                  |
| `0x5D` |   W   | Write bit 0 to trigger Event if its source is enabled.                                              |
| `0x5E` |   W   | Write bit 0 to trigger Manual IRQ if its source is enabled.                                         |
| `0x5F` |   W   | Reserved; no implemented function.                                                                  |

The counters and thresholds are 16-bit values split into low and high byte
ports. To program a 16-bit value, software writes its low byte and then high
byte. Counter reads likewise require reading the two bytes separately.

### 9.3 Timer operation

Each timer has a 16-bit count, a 16-bit threshold, an enable state, and a mode.

- **Mode 0 (count up):** while enabled, the counter increments each clock.
  When the next count equals the threshold and that timer's IRQ source is
  enabled, its sticky flag is set. The timer continues counting. A later
  match can set the flag again after it has been cleared.
- **Mode 1 (count down):** the timer control's load bit copies the threshold
  into the counter. While enabled, it counts down. At terminal count (zero),
  its flag is set if enabled and the timer is stopped.
- **Enable bits:** The timer control register controls whether the timer
  advances.
- **Counter writes:** Software may also write the counter bytes directly.
- **Reset:** System reset clears counters, thresholds, enables, flags, and
  controller configuration.

In the current implementation, a threshold match sets an interrupt flag only
when the corresponding source-enable bit in `0x5A` is set at the time of the
match. Timer mode 0 is an incrementing match counter; do not assume it
automatically reloads the threshold or produces periodic events without
software clearing/reconfiguring as needed.

### 9.4 Status flags and source priority

At port `0x58`:

|  Bit | Meaning                                                     |
| ---: | ----------------------------------------------------------- |
|    0 | Timer A sticky flag                                         |
|    1 | Timer B sticky flag                                         |
|    2 | Event sticky flag                                           |
|    3 | Manual IRQ sticky flag                                      |
|    4 | At least one **enabled** source has a sticky flag set |
| 7–5 | Zero                                                        |

Flags in bits 0–3 remain visible even if a source is later masked. Masked flags
do not contribute to bit 4 and are not selected by the priority encoder until
the source is enabled again. Writing a 1 to the corresponding bit at `0x59`
clears the flag.

When multiple enabled sources are pending, `0x5B` chooses the first set source
in this order:

| Priority | Source ID | Source     |
| -------: | --------: | ---------- |
|  Highest |         0 | Timer A    |
|          |         1 | Timer B    |
|          |         2 | Event      |
|   Lowest |         3 | Manual IRQ |

If no enabled source is pending, the source port reads `0`. Therefore software
must check status bit 4 before treating source ID zero as a real Timer A
request.

The vector-base nibble at `0x5A` is stored for software readback. The current
CPU does not calculate an interrupt vector from it and does not jump to a
handler automatically.

### 9.5 Software handling pattern

The standard polling pattern is:

1. Configure the timer/event and enable its source.
2. Read `0x58`.
3. If bit 4 is clear, return to the polling loop or perform other work.
4. Read `0x5B` to identify the highest-priority enabled pending source.
5. Run the corresponding handler code.
6. Write the source's clear bit to `0x59`.
7. Poll again.

Simplified assembly shape:

```assembly
POLL:
    IN   R0, 0x58       ; Read status
    LDI  R1, 0x10       ; Mask enabled-pending bit
    AND  R2, R0, R1
    BEQ  POLL           ; No enabled event: keep polling

    IN   R3, 0x5B       ; Read priority-encoded source
    ; Compare R3 and branch to the matching software handler.
    ; Each handler performs its task and clears its flag:
    LDI  R4, 0x01       ; Example: clear Timer A
    OUT  0x59, R4
    JMP  POLL
```

This example shows the pattern, not a full dispatcher for all four sources.
Because DSD-8 has no call stack or automatic interrupt entry, software must
organize handler code and register use explicitly.

### 9.6 Add-on integration files

| File                             | Purpose                                                                                      |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| `rtl/interrupt_controller.v`   | Timer counters, flags, enables, triggers, and priority readback.                             |
| `rtl/dsd8_interrupt_top.v`     | Optional system top that joins the unchanged processor and standard I/O with the controller. |
| `tb/tb_interrupt_controller.v` | Standalone tests for timer operation, sticky flags, mask behavior, and priority.             |
| `sim/interrupt_smoke.asm`      | Small assembled program that polls Timer A, updates LEDs, clears the flag, and halts.        |
| `tb/tb_dsd8_interrupt_top.v`   | CPU-level test of the smoke program and add-on integration.                                  |
| `doc/interrupt_addon.md`       | Short add-on register and test reference.                                                    |

The add-on uses the available `0x50`–`0x5F` range, which does not overlap the
standard board ports or the baseline `SLOW_ECHO` port `0x40`.

## 10. Building, running, and observing the design

### 10.1 Assemble a program

```powershell
python dsd8asm.py sim\multiply.asm -o sim\multiply.hex -v
```

The assembler writes a 512-word hex image, filling unused locations with
`NOP` (`0x0000`). `instr_memory` loads the selected image through its `IMAGE`
parameter at simulation start.

### 10.2 Run the baseline regression

```powershell
python scripts\run_all.py --no-waves
```

This runs the existing self-checking RTL unit testbenches and the 40-program
conformance suite. The suite compares the hardware execution trace with the
golden reference behavior.

### 10.3 Test the interrupt add-on

From the project root, assemble the smoke program, then compile and run each
add-on testbench:

```powershell
python dsd8asm.py sim\interrupt_smoke.asm -o sim\interrupt_smoke.hex

tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_interrupt_controller -o sim\tb_interrupt_controller.vvp tb\tb_interrupt_controller.v rtl\interrupt_controller.v
tools\iverilog\app\bin\vvp.exe sim\tb_interrupt_controller.vvp

tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_dsd8_interrupt_top -o sim\tb_dsd8_interrupt_top.vvp rtl\*.v tb\tb_dsd8_interrupt_top.v
tools\iverilog\app\bin\vvp.exe sim\tb_dsd8_interrupt_top.vvp
```

The standalone test exercises peripheral registers. The CPU-level test checks
that a real DSD-8 program can configure a timer, poll the flag, write to the
standard LED port, clear the flag, and halt.

### 10.4 Inspect waveforms and interact with the processor

The project bundles Icarus Verilog and GTKWave. Existing unit and conformance
tests can emit VCD waveform files for cycle-by-cycle inspection. The web
dashboard, launched with `python run_dashboard.py`, provides a visual
simulator for stepping through programs and observing CPU state, memory, flags,
and board I/O.

## 11. Verification approach and current evidence

Verification is performed at several levels:

1. **Module unit tests** isolate hardware blocks such as the ALU, control unit,
   register file, memories, and I/O bus.
2. **Constrained-random ALU tests** check a broad set of arithmetic and logic
   cases in addition to directed examples.
3. **Conformance tests** run complete programs and compare retired-instruction
   traces with the golden reference simulator.
4. **Add-on unit test** checks its own timer, status, clear, mask, and priority
   behavior.
5. **Add-on integration test** runs an assembled program on the optional top,
   ensuring the processor, bus, timer, and standard LEDs work together.

The CPU exposes a retirement trace interface for verification. On instruction
completion, it reports the instruction's PC and 16-bit word, whether a
register or data-memory write occurred and the associated address/data, and
the architectural flags after the instruction. A write-enable of zero has
zeroed address/data trace fields. This makes a mismatch diagnosable at the
instruction that caused it, rather than only by observing a final LED value.

The latest recorded baseline run passed **9/9 baseline unit tests** and
**40/40 conformance tests**. The interrupt-controller test and the CPU-level
interrupt smoke test also passed. The system RTL compiled successfully with
the bundled Icarus Verilog compiler.

The baseline conformance suite validates the frozen processor behavior; it
does not replace the two separate add-on tests. Run both test classes when
checking the complete extended system.

## 12. Design boundaries and limitations

- DSD-8 is an educational, small processor design; it is not intended as a
  general-purpose PC or a drop-in commercial CPU.
- Arithmetic results are 8 bits and wrap around. Signed interpretation is a
  software convention indicated by flags, not a separate data type.
- The ISA has no multiply instruction, immediate arithmetic, stack, call/return,
  or hardware interrupt entry.
- The add-on's events are polled. A long-running program that does not poll
  can leave a sticky event unserviced.
- A sticky flag records that at least one event occurred; it is not an event
  counter. Multiple occurrences before software clears a flag are represented
  by the same set bit.
- Priority identifies which enabled pending source to service first; it does
  not preempt the current instruction or handler.
- Vector-base bits are storage/readback only in this implementation. Software
  dispatches with ordinary branches.
- The original `dsd8_top` does not contain the add-on. Use
  `dsd8_interrupt_top` when building or simulating the extended system.
- Ports `0x5F` and currently unimplemented reads in the add-on range return no
  useful configured value; reserved port `0x5F` is for future extension.

## 13. Glossary

| Term                                 | Plain-language meaning                                                                                                          |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| **ALU**                        | Arithmetic Logic Unit; the calculator that performs operations such as addition and AND.                                        |
| **Assembler**                  | A program that translates readable assembly instructions into machine-code words.                                               |
| **Branch**                     | A conditional change to the next instruction address.                                                                           |
| **Clock edge**                 | The active transition of the system clock when sequential hardware updates its stored values.                                   |
| **Combinational logic**        | Logic whose outputs follow its current inputs without waiting for a clock edge.                                                 |
| **Datapath**                   | The registers, ALU, buses, and selection logic that move and process values.                                                    |
| **Finite-state machine (FSM)** | Control logic that moves through named states such as fetch and execute.                                                        |
| **Flag**                       | A one-bit result summary such as zero, carry, or overflow.                                                                      |
| **Harvard architecture**       | A design with separate instruction and data memories.                                                                           |
| **I/O port**                   | An address used by the CPU to communicate with a peripheral.                                                                    |
| **Memory-mapped / port I/O**   | A software-visible address-based interface to hardware devices. In DSD-8, I/O ports are a separate port space from data memory. |
| **Peripheral**                 | A device connected to the processor system, such as a timer, LED bank, or switch input.                                         |
| **Polling**                    | Repeatedly reading a status register to see whether a device needs attention.                                                   |
| **Retire**                     | The point at which an instruction completes and its effects become architectural state.                                         |
| **Sticky flag**                | A status bit that remains set until software explicitly clears it.                                                              |
| **Two's complement**           | The conventional binary representation of signed integers.                                                                      |
| **RTL**                        | Register-transfer-level hardware description; here, Verilog that describes the processor circuitry.                             |

## 14. Project references

- `README.md` — project setup, command-line tools, regression, and add-on quick
  start.
- `DSD8-Processor-Project-Specification.pdf` — frozen baseline requirements
  and architecture specification.
- `Timer_Counter_Interrupt_Specification.md` — detailed add-on design
  specification and rationale.
- `Interrupt_Quick_Reference.md` — compact add-on port map and usage notes.
- `Interrupt_Implementation_Roadmap.md` — proposed implementation and
  verification roadmap.
- `rtl/` — baseline and add-on Verilog source.
- `tb/` and `sim/` — testbenches and example programs.
