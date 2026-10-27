# Timer/Counter Interrupt Add-On for DSD-8
## START HERE — Getting Started Guide

---

## What You're Building

A **polling-based interrupt controller** that adds real-time interrupt handling to DSD-8 without requiring any changes to the frozen CPU.

**In plain English:**
- Two independent timers that count each clock cycle
- When a timer reaches a threshold, it "fires" an interrupt event
- Your software polls for these events and dispatches to handler routines
- Multiple interrupt sources are handled in priority order

**Real-world parallel:** Many embedded microcontrollers work exactly this way — polling for interrupt flags instead of being interrupted by hardware signals.

---

## Key Facts

| Aspect | Detail |
|--------|--------|
| **I/O Ports** | 0x50–0x5F (16 ports, no conflicts) |
| **Interrupt Sources** | 4 (Timer A, Timer B, Event, Manual) |
| **Priority Levels** | Timer A (0) > Timer B (1) > Event (2) > Manual (3) |
| **RTL Size** | ~250 lines of Verilog |
| **Assembly Code** | ~150 lines dispatcher + handlers |
| **Time to Complete** | 6–8 hours total |
| **Difficulty** | Medium (doable, not trivial) |
| **CPU Changes** | Zero (completely orthogonal) |

---

## Three-Step Overview

### Step 1: RTL Design (Week 13 — 3 hours)
Write the hardware controller that:
- Increments two independent 16-bit counters every clock cycle
- Fires interrupt flags when counters match thresholds
- Provides control registers for enable/disable, mode selection, reset
- Implements a priority encoder to select which interrupt to service

**Output:** `interrupt_controller.v` (~250 lines), unit testbench

### Step 2: Assembly & Test (Week 14 — 3 hours)
Write the software that:
- Polls for interrupt flags in a tight dispatcher loop
- Determines which interrupt has highest priority
- Jumps to the appropriate handler routine
- Handler processes the event and clears the flag

**Output:** `interrupt_dispatcher.asm`, three test programs, demo program

### Step 3: Documentation & Demo (Week 15–16 — 2 hours)
- Document the architecture in your design report
- Run impressive demos showing precise LED blinking
- Explain interrupt handling concepts in oral defence

**Output:** Design report section, demonstration, confident explanation

---

## File Structure

Create these files in your repository:

```
dsd8_processor/
├── rtl/
│   ├── dsd8_top.v              (MODIFY: add interrupt controller)
│   ├── interrupt_controller.v  (NEW: ~250 lines)
│   └── ... (other modules)
│
├── tb/
│   ├── tb_dsd8.v               (existing)
│   └── tb_interrupt_controller.v (NEW: unit testbench)
│
├── asm/
│   ├── interrupt_dispatcher.asm (NEW: main dispatcher)
│   ├── test_interrupt_1.asm    (NEW: single timer test)
│   ├── test_interrupt_2.asm    (NEW: dual timer test)
│   ├── test_interrupt_3.asm    (NEW: handler counter test)
│   └── demo_interrupt_blink.asm (NEW: impressive demo)
│
└── doc/
    └── design_report.md         (MODIFY: add interrupt section)
```

---

## Port Map (Your I/O Real Estate)

```
0x50 — Timer A Counter Low        (R/W)
0x51 — Timer A Counter High       (R/W)
0x52 — Timer A Threshold Low      (W)
0x53 — Timer A Threshold High     (W)

0x54 — Timer B Counter Low        (R/W)
0x55 — Timer B Counter High       (R/W)
0x56 — Timer B Threshold Low      (W)
0x57 — Timer B Threshold High     (W)

0x58 — IRQ_STATUS                 (R)  ← Poll this for interrupt flags
0x59 — IRQ_CLEAR                  (W)  ← Write this to clear flags
0x5A — IRQ_PRIORITY               (W)  ← Enable bits + vector base
0x5B — IRQ_SOURCE                 (R)  ← Which interrupt has priority

0x5C — TIMER_CTRL                 (W)  ← Enable/mode/reset timers
0x5D — EVENT_TRIGGER              (W)  ← Software trigger
0x5E — MANUAL_IRQ                 (W)  ← Software interrupt
0x5F — INTERRUPT_CONFIG           (W)  ← Reserved
```

---

## Minimal Assembly Example

This is literally all you need to understand the system:

```assembly
; Setup Timer A to fire every 100 cycles
INIT:
    LDI R1, 100
    OUT 0x52, R1        ; Set threshold = 100
    LDI R2, 0
    OUT 0x53, R2        ; (high byte)
    
    LDI R3, 0x01        ; Enable Timer A
    OUT 0x5A, R3        ; (IRQ_PRIORITY: enable bit 0)
    OUT 0x5C, R3        ; (TIMER_CTRL: enable bit 0)

; Main loop: check for interrupts
LOOP:
    IN R4, 0x58         ; Read IRQ_STATUS
    LDI R5, 0x10        ; Check bit 4 (any_irq_pending)
    AND R6, R4, R5
    BEQ LOOP            ; No interrupt? Keep waiting
    
    ; Interrupt fired! Do something
    OUT 0x02, 0xFF      ; Light up LEDs
    
    ; Clear the interrupt flag
    LDI R7, 0x01        ; Clear bit 0 (Timer A)
    OUT 0x59, R7        ; Write to IRQ_CLEAR
    
    JMP LOOP            ; Check again

HLT
```

**That's the entire pattern.** Poll → Identify → Handle → Clear → Repeat.

---

## What Each Timer Does

### Timer A (Ports 0x50–0x53)
- **Counter:** Starts at 0 or whatever you load
- **Behavior:** Increments every clock cycle (if enabled)
- **Threshold:** When counter reaches this value, interrupt fires
- **Use case:** Measure elapsed time, generate periodic events

### Timer B (Ports 0x54–0x57)
- Identical to Timer A
- Independent of Timer A
- Useful for different time intervals (e.g., Timer A @ 50 cycles, Timer B @ 100 cycles)

### Interrupt Flags (Port 0x58)
```
Bit 0: timer_a_irq       (Timer A fired)
Bit 1: timer_b_irq       (Timer B fired)
Bit 2: event_irq         (Software event)
Bit 3: manual_irq        (Manual software interrupt)
Bit 4: any_irq_pending   (ANY of above is set) ← Use this for fast polling
```

All flags are **sticky**: once set, they stay set until you explicitly clear them.

---

## Hardware Checklist (Week 13)

Your RTL module needs:

- [ ] Two independent 16-bit counters (Timer A, Timer B)
- [ ] Increment logic (each cycle, if enabled)
- [ ] Threshold comparison (== check every cycle)
- [ ] Four interrupt flag latches (sticky, set on match)
- [ ] I/O read multiplexer (decode port 0x50–0x5F)
- [ ] Control registers (TIMER_CTRL, IRQ_CLEAR, IRQ_PRIORITY)
- [ ] Priority encoder (determine which interrupt to service)

**Important:** No complex state machines. Just:
1. Increment/decrement on clock
2. Compare on clock
3. Set flag on clock
4. Read/write on I/O port writes

---

## Software Checklist (Week 14)

Your assembly needs:

- [ ] Main dispatcher loop (continuously poll IRQ_STATUS)
- [ ] Decision logic (which interrupt fired?)
- [ ] Handler jumps (one for each interrupt source)
- [ ] Handler code (do something useful)
- [ ] Flag clearing (OUT to IRQ_CLEAR)
- [ ] Return to dispatcher

**Keep it simple:** No fancy jumps, just CMP and conditional branches.

---

## Common Questions

**Q: Do I need to modify the CPU?**  
A: **No.** Zero changes. The interrupt controller is purely an I/O peripheral.

**Q: Will this break conformance tests?**  
A: **No.** Conformance tests run at ports 0x00–0x3F. Your interrupt controller is at 0x50–0x5F. Completely isolated.

**Q: How accurate is the timing?**  
A: **Exact.** Timer matches threshold and fires immediately. No jitter.

**Q: Can I add more interrupt sources later?**  
A: **Yes, easily.** Add more flags, expand the priority encoder, add more handlers.

**Q: What if multiple interrupts happen simultaneously?**  
A: **Priority encoder handles it.** Timer A (priority 0) is always served first, then Timer B, then Event, then Manual.

**Q: Why not use a hardware interrupt signal to the CPU?**  
A: **DSD-8 doesn't have one, by design.** Keeps the CPU simple. Real microcontrollers often use polling anyway.

---

## Getting Started This Week

### Today
1. Read the complete specification: `Timer_Counter_Interrupt_Specification.md`
2. Review the quick reference: `Interrupt_Quick_Reference.md`
3. Understand the dispatcher flow (see diagram earlier)

### This Week (Design)
1. Sketch the RTL block diagram on paper
2. Write the Verilog module (copy template from spec)
3. Write unit testbench (5 test cases)
4. Integrate into dsd8_top.v
5. Run synthesis, verify no warnings

### Next Week (Assembly)
1. Write dispatcher in assembly
2. Write 3 test programs
3. Test with simulation
4. Verify LED behavior matches expected

### Week 15–16 (Demo)
1. Polish demo program
2. Write documentation
3. Prepare oral defence answers
4. Practice explaining architecture

---

## Success Looks Like

**Week 13 end:** Module compiles, timers increment, interrupts fire at correct times

**Week 14 end:** Dispatcher correctly identifies interrupts, handlers execute, flags clear

**Week 15 end:** Documentation complete, demo program impresses viewers

**Week 16 end:** Confident oral defence, impressive demonstration, perfect score

---

## Why This Addon Rocks

✅ **Professional:** Real-world interrupt-handling patterns  
✅ **Educational:** Teaches timing, polling, priority dispatch, state machines  
✅ **Impressive:** LEDs blinking at precise intervals looks great  
✅ **Safe:** Orthogonal to CPU — can't break anything  
✅ **Scalable:** Easy to add more sources (buttons, UART, sensors)  
✅ **Defensible:** Every design choice has a clear rationale  

---

## Documents to Reference

| Document | Purpose |
|----------|---------|
| `Timer_Counter_Interrupt_Specification.md` | Complete technical details (250+ lines) |
| `Interrupt_Quick_Reference.md` | Port map, register bits, quick lookup |
| `Interrupt_Implementation_Roadmap.md` | Week-by-week breakdown with code examples |
| `DSD-8 Processor Specification.pdf` | Original project definition (for I/O protocol) |

---

## Next Steps

1. **Read** the full specification document completely
2. **Understand** the interrupt dispatcher flow (review the diagram)
3. **Design** your RTL module (pencil sketch first)
4. **Code** the Verilog in one afternoon
5. **Test** with unit testbench
6. **Verify** synthesis is clean

**You've got this.** 🎯

---

## Questions? Common Pitfalls

**"My testbench doesn't show interrupts firing"**  
→ Did you enable the timer? Check TIMER_CTRL bit 0.

**"Interrupt fires but handler doesn't run"**  
→ Is dispatcher polling IRQ_STATUS correctly? Did you read IRQ_SOURCE to get the ID?

**"Interrupt fires every cycle"**  
→ You forgot to clear the flag. Write to IRQ_CLEAR at the end of your handler.

**"Synthesis fails with 'inferred latch' warning"**  
→ Check your `always @(posedge clk)` blocks. Make sure all signals are assigned on every path.

---

## You're Ready

You have:
- ✅ Complete technical specification
- ✅ Week-by-week implementation guide
- ✅ Example code for RTL and assembly
- ✅ Test programs to verify behavior
- ✅ Documentation templates

**Start coding. Questions? Reference the full specification.** 

You're building a real interrupt system. This is professional hardware design. Enjoy it! 🚀
