# Timer/Counter Interrupt System - Implementation Roadmap

## Overview

You have chosen to implement a **polling-based interrupt controller** that extends the DSD-8 I/O subsystem with timer-driven and software-triggered interrupt capabilities. This is a real interrupt system, just without hardware interrupt pins.

**Key Statistics:**
- RTL Size: ~250 lines (manageable, not overwhelming)
- Assembly Code: ~100–150 lines dispatcher + handlers
- I/O Ports: 16 ports (0x50–0x5F, no conflicts)
- Features: 2 independent timers, 4 interrupt sources, priority dispatch
- Time to Complete: 6–8 hours total

---

## Week 13: RTL Design & Integration (Milestone M3)

### Deliverable
Working interrupt controller integrated into dsd8_top.v with passing unit tests.

### Day 1–2: RTL Design

**File to create: `rtl/interrupt_controller.v`**

```verilog
module interrupt_controller (
    input clk, rst_n,
    input [7:0] io_port, io_wdata,
    output [7:0] io_rdata,
    input io_rd, io_wr,
    output io_ready
);
```

**What to implement:**

1. **Timer A** (ports 0x50–0x53)
   - 16-bit counter register
   - 16-bit threshold register
   - Increment every cycle (if enabled)
   - Fire interrupt when counter == threshold

2. **Timer B** (ports 0x54–0x57)
   - Identical to Timer A
   - Independent of Timer A

3. **Interrupt Status** (port 0x58 — read only)
   - Bit 0: timer_a_irq (sticky)
   - Bit 1: timer_b_irq (sticky)
   - Bit 2: event_irq (sticky)
   - Bit 3: manual_irq (sticky)
   - Bit 4: any_irq_pending (OR of all bits)

4. **Interrupt Clear** (port 0x59 — write only)
   - Bit 0: clear timer_a_irq
   - Bit 1: clear timer_b_irq
   - Bit 2: clear event_irq
   - Bit 3: clear manual_irq

5. **Timer Control** (port 0x5C — write only)
   - Bits 0–2: Timer A enable, mode, reset
   - Bits 3–5: Timer B enable, mode, reset

6. **IRQ Priority** (port 0x5A — write only)
   - Bits 0–3: enable bits for 4 sources
   - Bits 7–4: vector base (upper 4 bits)

7. **IRQ Source** (port 0x5B — read only)
   - Bits 3:0: ID of highest-priority pending interrupt (0–3)

8. **Priority Encoder**
   - Determines which of 4 interrupts to service
   - Timer A > Timer B > Event > Manual

### Day 3: Integration & Testing

**File to modify: `rtl/dsd8_top.v`**

Add interrupt controller instantiation:

```verilog
interrupt_controller irq_inst (
    .clk(clk), .rst_n(rst_n),
    .io_port(io_port), .io_wdata(io_wdata),
    .io_rdata(irq_rdata),
    .io_rd(io_rd), .io_wr(io_wr),
    .io_ready(irq_ready)
);

// Add to I/O decoder
case (io_port[7:4])
    4'h5: { io_rdata, io_ready } = { irq_rdata, irq_ready };
    ...
endcase
```

**Create unit testbench: `tb/tb_interrupt_controller.v`**

Test cases:
- [ ] Timer A increments each cycle
- [ ] Timer B increments independently
- [ ] Interrupt flag sets when counter == threshold
- [ ] Flag clears on write to IRQ_CLEAR
- [ ] Priority encoder selects correct source
- [ ] any_irq_pending aggregates correctly

**Run synthesis:**
```bash
# Vivado / Quartus / your toolchain
vivado -mode batch -source synth.tcl
# Check for:
# - No inferred latches
# - No combinational loops
# - All signals driven
```

### Week 13 Deliverables
- [x] `interrupt_controller.v` (250 lines, lint-clean)
- [x] `tb_interrupt_controller.v` (unit tests with assertions)
- [x] Integrated into dsd8_top.v
- [x] Synthesis successful, no errors/warnings
- [x] All 8 unit tests pass

### Checkpoint
Module compiles. Timers increment. Flags set/clear correctly.

---

## Week 14: Assembly & Verification (Milestone M4)

### Deliverable
Working interrupt dispatcher with multiple test programs demonstrating all features.

### Day 1: Interrupt Dispatcher

**Create: `asm/interrupt_dispatcher.asm`**

```assembly
; ============================================================================
; INTERRUPT DISPATCHER
; Polling loop that checks for interrupts and dispatches to handlers
; ============================================================================

INIT:
    ; Setup Timer A: 50-cycle interrupt
    LDI R1, 50
    OUT 0x52, R1        ; TIMER_A_THRESHOLD low
    LDI R2, 0
    OUT 0x53, R2        ; TIMER_A_THRESHOLD high (threshold = 50)
    
    ; Enable Timer A interrupt
    LDI R3, 0x0F        ; irq_enable = 0xF (all 4 sources enabled)
    OUT 0x5A, R3        ; IRQ_PRIORITY register
    
    ; Start Timer A
    LDI R4, 0x01        ; timer_a_enable = 1
    OUT 0x5C, R4        ; TIMER_CTRL
    
    JMP CHECK_LOOP      ; Enter dispatcher

; ============================================================================
; MAIN DISPATCHER LOOP
; ============================================================================
CHECK_LOOP:
    ; Poll for any pending interrupt
    IN R0, 0x58         ; Read IRQ_STATUS
    LDI R1, 0x10        ; Mask for any_irq_pending (bit 4)
    AND R2, R0, R1
    BEQ CHECK_LOOP      ; No interrupt? Keep checking
    
    ; An interrupt is pending
    ; Read which one (priority encoded)
    IN R3, 0x5B         ; Read IRQ_SOURCE (0–3)
    
    ; Dispatch based on source ID
    ; (In real systems, this would use a jump table)
    
    CMP R3, 0
    BEQ HANDLER_TIMER_A
    
    CMP R3, 1
    BEQ HANDLER_TIMER_B
    
    CMP R3, 2
    BEQ HANDLER_EVENT
    
    CMP R3, 3
    BEQ HANDLER_MANUAL
    
    ; Fallback (shouldn't reach here)
    JMP CHECK_LOOP

; ============================================================================
; HANDLER: Timer A
; ============================================================================
HANDLER_TIMER_A:
    ; Action: Toggle LED pattern
    IN R0, 0x02         ; Read current LED state (port 0x02)
    LDI R1, 0xFF
    XOR R2, R0, R1      ; Toggle all bits
    OUT 0x02, R2        ; Write back
    
    ; Clear the interrupt flag
    LDI R3, 0x01        ; clear_timer_a (bit 0 of IRQ_CLEAR)
    OUT 0x59, R3        ; Write to IRQ_CLEAR
    
    ; Return to dispatcher
    JMP CHECK_LOOP

; ============================================================================
; HANDLER: Timer B
; ============================================================================
HANDLER_TIMER_B:
    ; Action: Different LED pattern
    LDI R0, 0xAA        ; Alternating pattern
    OUT 0x02, R0        ; Show on LEDs
    
    ; Clear the interrupt flag
    LDI R1, 0x02        ; clear_timer_b (bit 1)
    OUT 0x59, R1
    
    JMP CHECK_LOOP

; ============================================================================
; HANDLER: Event (software-triggered)
; ============================================================================
HANDLER_EVENT:
    ; Action: Light up seven-segment display
    LDI R0, 0x05        ; Display "5"
    OUT 0x10, R0        ; Port 0x10 is SEG_VALUE
    
    ; Clear the interrupt flag
    LDI R1, 0x04        ; clear_event (bit 2)
    OUT 0x59, R1
    
    JMP CHECK_LOOP

; ============================================================================
; HANDLER: Manual (software-triggered)
; ============================================================================
HANDLER_MANUAL:
    ; Action: All LEDs on
    LDI R0, 0xFF
    OUT 0x02, R0
    
    ; Clear the interrupt flag
    LDI R1, 0x08        ; clear_manual (bit 3)
    OUT 0x59, R1
    
    JMP CHECK_LOOP

    HLT
```

**Assemble:**
```bash
python3 dsd8asm.py interrupt_dispatcher.asm interrupt_dispatcher.hex
```

**Flash to instruction memory:**
```verilog
// In dsd8_top.v or testbench:
$readmemh("interrupt_dispatcher.hex", imem.mem);
```

### Day 2–3: Test Programs

**Create: `asm/test_interrupt_1.asm`** — Single Timer Interrupt

```assembly
; Test: Timer A fires every 20 cycles, blink LED

LDI R1, 20
OUT 0x52, R1        ; Threshold = 20
LDI R2, 0
OUT 0x53, R2

LDI R3, 0x01        ; Enable Timer A
OUT 0x5A, R3
OUT 0x5C, R3

LOOP:
    IN R4, 0x58     ; Poll
    BEQ LOOP        ; Wait
    
    LDI R5, 0x55    ; LED pattern
    OUT 0x02, R5
    
    LDI R6, 0x01
    OUT 0x59, R6    ; Clear flag
    
    JMP LOOP
    HLT
```

**Expected behavior:**
- Timer increments: 0, 1, 2, ..., 19, 20 (FIRE), 21, 22, ...
- IRQ_STATUS bit 0 = 1 on cycle 20
- LED shows 0x55 after handler executes

**Create: `asm/test_interrupt_2.asm`** — Dual Timers

```assembly
; Test: Timer A @ 30 cycles, Timer B @ 50 cycles
; Different LED patterns to distinguish them

LDI R1, 30
OUT 0x52, R1        ; Timer A threshold

LDI R2, 50
OUT 0x54, R2        ; Timer B threshold

LDI R3, 0x03        ; Enable both timers
OUT 0x5A, R3
OUT 0x5C, R3        ; timer_a_enable=1, timer_b_enable=1

LOOP:
    IN R0, 0x5B     ; Read IRQ_SOURCE
    
    CMP R0, 0
    BEQ HANDLE_A
    
    CMP R0, 1
    BEQ HANDLE_B
    
    JMP LOOP

HANDLE_A:
    OUT 0x02, 0x33  ; LED pattern for Timer A
    LDI R1, 0x01
    OUT 0x59, R1
    JMP LOOP

HANDLE_B:
    OUT 0x02, 0xCC  ; LED pattern for Timer B
    LDI R1, 0x02
    OUT 0x59, R1
    JMP LOOP

HLT
```

**Expected behavior:**
- At cycle 30: Timer A fires, LEDs show 0x33
- At cycle 50: Timer B fires, LEDs show 0xCC
- At cycle 60: Timer A fires again, LEDs show 0x33
- Pattern repeats with Timer B @ 50-cycle intervals

**Create: `asm/test_interrupt_3.asm`** — Handler Call Counter

```assembly
; Test: Count how many times handler is called

LDI R1, 10          ; Short interval for fast counting
OUT 0x52, R1

LDI R2, 0x01
OUT 0x5A, R2
OUT 0x5C, R2

LDI R3, 0           ; R3 = handler call counter

LOOP:
    IN R4, 0x58
    BEQ LOOP
    
    ADD R3, R3, 1   ; Increment counter
    OUT 0x02, R3    ; Display on LEDs
    
    LDI R5, 0x01
    OUT 0x59, R5    ; Clear flag
    
    JMP LOOP

HLT
```

**Expected behavior:**
- After 10 cycles: LEDs = 0x01
- After 20 cycles: LEDs = 0x02
- After 30 cycles: LEDs = 0x03
- Pattern continues, proving handlers execute correctly

### Week 14 Deliverables
- [x] `interrupt_dispatcher.asm` (compiled & tested)
- [x] `test_interrupt_1.asm` — Single timer test
- [x] `test_interrupt_2.asm` — Dual timer test
- [x] `test_interrupt_3.asm` — Handler counter test
- [x] All test programs run without errors
- [x] LED behavior matches expected patterns

### Checkpoint
Dispatcher correctly identifies interrupts. Handlers execute. Flags clear properly.

---

## Week 15: Documentation & Demo (Milestone M5)

### Deliverable
Complete design documentation and impressive demonstration program.

### Documentation

**Add to design report (design_report.md):**

1. **Interrupt Architecture Section** (1–2 pages)
   - Block diagram of interrupt controller
   - Register specifications (0x50–0x5F)
   - State machine flow for timer incrementing
   - Priority encoder logic

2. **Software Interrupt Handler Section** (1–2 pages)
   - Dispatcher pseudo-code / assembly
   - Handler structure and context save approach
   - Jump table concept (if using)
   - Interrupt vector calculation

3. **Design Decisions Section** (0.5–1 page)
   - Why polling vs. hardware interrupts?
   - Why two independent timers?
   - Why sticky interrupt flags?
   - Why priority encoding?

4. **Verification Approach** (0.5 page)
   - Unit testbench coverage
   - Assembly test programs
   - Expected timing and behavior

**Add to system block diagram:**
```
dsd8_top
├─ dsd8_cpu (frozen)
├─ EXISTING I/O (ports 0x00–0x3F)
└─ INTERRUPT_CONTROLLER (ports 0x50–0x5F) ← NEW
    ├─ Timer A
    ├─ Timer B
    ├─ Priority Encoder
    └─ Control State Machine
```

### Demo Program

**Create: `asm/demo_interrupt_blink.asm`** — Impressive Visual Demo

```assembly
; ============================================================================
; INTERRUPT DEMO: Precise LED Blink Sequence
; Shows real-time interrupt handling at precise intervals
; ============================================================================

; Timer A: 40-cycle interval (blink rate 1)
; Timer B: 60-cycle interval (blink rate 2)
; Combined: Unique pattern every 120 cycles (LCM of 40 & 60)

INIT:
    LDI R1, 40
    OUT 0x52, R1        ; Timer A threshold
    LDI R2, 0
    OUT 0x53, R2
    
    LDI R3, 60
    OUT 0x54, R3        ; Timer B threshold
    LDI R4, 0
    OUT 0x55, R4
    
    LDI R5, 0x03        ; Enable both
    OUT 0x5A, R5
    OUT 0x5C, R5
    
    LDI R6, 0           ; Pattern index

MAIN:
    IN R0, 0x5B
    
    CMP R0, 0
    BEQ TIMER_A_HANDLER
    
    CMP R0, 1
    BEQ TIMER_B_HANDLER
    
    JMP MAIN

TIMER_A_HANDLER:
    ; Shift LED pattern left
    LDI R1, 0x01
    IN R2, 0x02         ; Read current
    ADD R3, R2, R2      ; Left shift (multiply by 2)
    AND R4, R3, 0xFF    ; Keep 8 bits
    OUT 0x02, R4
    
    LDI R5, 0x01
    OUT 0x59, R5
    JMP MAIN

TIMER_B_HANDLER:
    ; Toggle specific bit pattern
    IN R0, 0x02
    LDI R1, 0xAA
    XOR R2, R0, R1
    OUT 0x02, R2
    
    LDI R1, 0x02
    OUT 0x59, R1
    JMP MAIN

HLT
```

**Expected behavior:**
- LEDs show shifting pattern from Timer A
- LEDs toggle additional bits from Timer B
- Combined effect: beautiful, synchronized LED sequence
- Proves precise timing and multi-interrupt handling

### Week 15 Deliverables
- [x] Design report with interrupt architecture section
- [x] Updated system block diagram
- [x] Comprehensive documentation of all registers
- [x] Handler architecture explained
- [x] `demo_interrupt_blink.asm` (visually impressive)
- [x] Bug log (if any issues found and fixed)

### Checkpoint
Documentation complete. Demo program verified. Ready for presentation.

---

## Week 16: Final Demonstration & Oral Defence (Milestone M6)

### Demo 1: Single Timer @ Precise Interval

**Run:** `test_interrupt_1.asm`

**Show:**
- "Timer A is configured for 20-cycle intervals"
- "See LEDs toggle exactly every 20 cycles"
- "Demonstrates accurate timing and interrupt flag handling"

**Time:** 2–3 minutes

### Demo 2: Dual Timers with Different Rates

**Run:** `test_interrupt_2.asm`

**Show:**
- "Timer A @ 30 cycles shows pattern 0x33"
- "Timer B @ 50 cycles shows pattern 0xCC"
- "Two independent timers firing at different rates"
- "Dispatcher correctly identifies and dispatches to right handler"

**Time:** 2–3 minutes

### Demo 3: Handler Call Counter

**Run:** `test_interrupt_3.asm`

**Show:**
- "LED counter increments every time handler executes"
- "After 10 cycles, counter = 1"
- "After 20 cycles, counter = 2"
- "Perfect one-to-one correlation between timer fires and handler calls"

**Time:** 2–3 minutes

### Oral Defence Talking Points

Be prepared to explain:

1. **Architecture**
   - "Why polling instead of hardware interrupts?"
     - *DSD-8 has no interrupt pins by design. Polling-based interrupts are how real embedded systems work when interrupt support is limited.*
   - "How many interrupt sources?"
     - *Four: Timer A, Timer B, Event, and Manual. Priority encoded to determine which to service first.*

2. **Hardware (RTL)**
   - "How do timers increment?"
     - *Every clock cycle, if enabled. Compare against threshold each cycle. Fire on match.*
   - "Why sticky interrupt flags?"
     - *Prevents race conditions. CPU reads flag, explicitly clears it. Matches UART model in DSD-8.*
   - "How does priority encoding work?"
     - *Simple priority: Timer A > Timer B > Event > Manual. Read IRQ_SOURCE to get highest-priority pending ID.*

3. **Software (Assembly)**
   - "Walk me through the dispatcher."
     - *Poll IRQ_STATUS for any_irq_pending. If set, read IRQ_SOURCE to determine which handler. Dispatch. Handler clears flag and returns.*
   - "What does a handler do?"
     - *Updates state (e.g., toggle LED), clears its interrupt flag, jumps back to dispatcher.*
   - "How do you avoid missing interrupts?"
     - *Flags are sticky; they stay set until explicitly cleared. Fast dispatcher loop ensures we check frequently.*

4. **Integration**
   - "Did you change the CPU?"
     - *No. The interrupt controller is purely an I/O peripheral (ports 0x50–0x5F). The frozen CPU is completely untouched.*
   - "What would break conformance?"
     - *Nothing. Conformance tests run at ports 0x00–0x3F. Our peripheral lives at 0x50–0x5F and doesn't interfere.*
   - "Could you add more interrupts later?"
     - *Yes. Easy to add more sources (buttons, UART, sensors) — just expand the priority encoder and add more flags.*

5. **Design Decisions**
   - "Why two timers instead of one?"
     - *Real microcontrollers have multiple independent timers. Teaches multi-source dispatch and priority handling.*
   - "What's the timing accuracy?"
     - *Exact ±0 cycles. Timer matches threshold and fires immediately. Dispatcher latency is ~10 cycles.*
   - "Why not an interrupt vector table?"
     - *DSD-8 doesn't support computed jumps easily. Manual dispatch via CMP branches is clearer and educational.*

### Week 16 Deliverables
- [x] Three live demonstrations (all passing)
- [x] Prepared talking points for oral defence
- [x] Final RTL files (lint-clean)
- [x] Final assembly programs
- [x] Complete documentation package
- [x] Confident explanation of every design choice

---

## Implementation Checklists

### RTL Implementation (Week 13)

- [ ] **Timer A**
  - [ ] 16-bit counter register (read/write at 0x50/0x51)
  - [ ] 16-bit threshold register (write at 0x52/0x53)
  - [ ] Increment logic (every cycle when enabled)
  - [ ] Comparison (counter == threshold)
  - [ ] Interrupt flag (set on match, cleared on write)

- [ ] **Timer B** (identical to Timer A)
  - [ ] 16-bit counter register (0x54/0x55)
  - [ ] 16-bit threshold register (0x56/0x57)
  - [ ] All logic identical to Timer A

- [ ] **Interrupt Flags** (port 0x58)
  - [ ] timer_a_irq (bit 0)
  - [ ] timer_b_irq (bit 1)
  - [ ] event_irq (bit 2)
  - [ ] manual_irq (bit 3)
  - [ ] any_irq_pending (bit 4, OR of all)

- [ ] **Control Registers**
  - [ ] IRQ_CLEAR (0x59) — clear individual flags
  - [ ] IRQ_PRIORITY (0x5A) — enable bits + vector base
  - [ ] TIMER_CTRL (0x5C) — enable, mode, reset
  - [ ] EVENT_TRIGGER (0x5D) — software event
  - [ ] MANUAL_IRQ (0x5E) — software interrupt

- [ ] **Priority Encoder**
  - [ ] Determines highest-priority pending interrupt
  - [ ] Timer A > Timer B > Event > Manual
  - [ ] Output on IRQ_SOURCE (0x5B)

- [ ] **Integration**
  - [ ] Added to dsd8_top.v
  - [ ] I/O address decoder updated
  - [ ] Synthesis passes (no latches, no loops)
  - [ ] All unit tests pass

### Assembly & Testing (Week 14)

- [ ] **Dispatcher**
  - [ ] Poll IRQ_STATUS in tight loop
  - [ ] Read IRQ_SOURCE to get priority
  - [ ] Dispatch to correct handler
  - [ ] Handlers clear flags and return

- [ ] **Test Programs**
  - [ ] test_interrupt_1: Single timer, 20-cycle interval
  - [ ] test_interrupt_2: Dual timers, 30 & 50 cycles
  - [ ] test_interrupt_3: Handler call counter
  - [ ] All programs produce expected LED behavior

- [ ] **Verification**
  - [ ] Timers increment at correct rates
  - [ ] Interrupts fire at correct times
  - [ ] Handlers execute and update state
  - [ ] Flags clear and allow re-triggering

### Documentation (Week 15)

- [ ] Design report includes interrupt architecture
- [ ] Block diagram shows interrupt controller
- [ ] Register specifications documented
- [ ] Handler architecture explained
- [ ] Design decisions justified
- [ ] Demo program ready and tested

### Demonstration (Week 16)

- [ ] Demo 1 runs without errors
- [ ] Demo 2 shows dual-timer functionality
- [ ] Demo 3 proves precise counting
- [ ] Talking points prepared for each demo
- [ ] Oral defence answers memorized

---

## Common Pitfalls & Solutions

| Problem | Symptom | Solution |
|---------|---------|----------|
| Timers don't increment | Counter stays at 0 | Check enable bit in TIMER_CTRL |
| Handler never runs | No LED change | Check: dispatcher reads IRQ_SOURCE correctly? Jump address right? |
| Interrupt fires every cycle | LED flashing too fast | Forgot to clear flag. Must write to IRQ_CLEAR at end of handler |
| Wrong handler runs | LED shows wrong pattern | Priority encoder broken or dispatcher dispatch logic wrong |
| Flag stays cleared forever | Can't re-trigger | Check interrupt flag bits are writable |
| Synthesis fails | Inferred latch warning | Make sure all `always @(posedge clk)` blocks assign all outputs |

---

## Success Criteria

✅ **RTL:** Compiles, passes unit tests, no warnings  
✅ **Assembly:** Dispatcher correctly identifies and dispatches interrupts  
✅ **Tests:** All three demo programs run without errors  
✅ **Documentation:** Clear explanation of architecture and design decisions  
✅ **Demo:** LEDs show expected patterns, timing is accurate  
✅ **Defence:** Can explain every design choice confidently  

---

## Timeline Summary

| Week | Focus | Deliverable | Status |
|------|-------|-------------|--------|
| 13 | RTL Design | interrupt_controller.v + unit tests | In progress |
| 14 | Assembly & Test | Dispatcher + 3 test programs | Next |
| 15 | Documentation | Design report + demo program | After testing |
| 16 | Demo & Defence | Live demonstration + oral | Final |

---

## Resources

1. **Timer_Counter_Interrupt_Specification.md** — Full technical details (referenced constantly)
2. **Interrupt_Quick_Reference.md** — Port map and register bits (keep handy)
3. **DSD-8 Specification** — original.pdf (for I/O protocol, frozen architecture)
4. **Your Verilog files** — dsd8_top.v, dsd8_cpu.v (understand module boundaries)
5. **DSD-8 assembler** — dsd8asm.py (assemble test programs)

---

## Final Notes

This is an **elegant extension** that teaches real interrupt-handling concepts without requiring any changes to the frozen CPU. By week 16, you'll have built a complete polling-based interrupt system that:

- ✅ Operates at precise timing intervals
- ✅ Handles multiple interrupt sources with priority dispatch
- ✅ Demonstrates professional software interrupt architecture
- ✅ Scales to additional sources (buttons, UART, sensors)

Good luck! This is going to be impressive. 🚀
