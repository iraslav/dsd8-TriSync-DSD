# Timer/Counter Interrupt System - Quick Reference

## Port Map Summary

```
Ports 0x50–0x5F: Interrupt Controller
├─ 0x50–0x53: Timer A (counter, threshold)
├─ 0x54–0x57: Timer B (counter, threshold)
├─ 0x58: IRQ_STATUS (R) — read interrupt flags
├─ 0x59: IRQ_CLEAR (W) — clear interrupt flags
├─ 0x5A: IRQ_PRIORITY (W) — enable sources + vector base
├─ 0x5B: IRQ_SOURCE (R) — which interrupt has priority
├─ 0x5C: TIMER_CTRL (W) — enable/mode/reset timers
├─ 0x5D: EVENT_TRIGGER (W) — software event
├─ 0x5E: MANUAL_IRQ (W) — software interrupt
└─ 0x5F: INTERRUPT_CONFIG (W) — reserved
```

## Register Bit Layouts

### IRQ_STATUS (0x58) — READ ONLY
```
Bit   Name                 Meaning
───────────────────────────────────────
0     timer_a_irq         Timer A interrupted
1     timer_b_irq         Timer B interrupted
2     event_irq           Event interrupted
3     manual_irq          Manual interrupt
4     any_irq_pending     ANY interrupt active (useful for fast check)
```

### IRQ_CLEAR (0x59) — WRITE ONLY
```
Bit   Name                 Meaning
───────────────────────────────────────
0     clear_timer_a       Write 1 to clear timer_a_irq
1     clear_timer_b       Write 1 to clear timer_b_irq
2     clear_event         Write 1 to clear event_irq
3     clear_manual        Write 1 to clear manual_irq
```

### TIMER_CTRL (0x5C) — WRITE ONLY
```
Bit   Meaning
───────────────────────────────────────
0     timer_a_enable      1 = Timer A increments
1     timer_a_mode        1 = countdown, 0 = free-running
2     timer_a_reset       1 = load Timer A with threshold
3     timer_b_enable      1 = Timer B increments
4     timer_b_mode        1 = countdown, 0 = free-running
5     timer_b_reset       1 = load Timer B with threshold
```

### IRQ_PRIORITY (0x5A) — WRITE ONLY
```
Bit   Meaning
─────────────────────────────────────
0–3   Interrupt enable bits (1 = enable, 0 = mask)
      Bit 0 = Timer A, Bit 1 = Timer B, Bit 2 = Event, Bit 3 = Manual
7–4   Vector base (high 4 bits of handler table base address)
```

### IRQ_SOURCE (0x5B) — READ ONLY
```
Bit   Meaning
──────────────────────────────────
3:0   Active IRQ ID (0=Timer A, 1=Timer B, 2=Event, 3=Manual)
      Returns 0 if no interrupt pending
```

---

## Minimal Assembly Program

```assembly
; ============================================================================
; MINIMAL INTERRUPT DISPATCHER
; ============================================================================

INIT:
    ; Timer A: threshold = 100
    LDI R1, 100
    OUT 0x52, R1        ; TIMER_A_THRESHOLD low
    LDI R2, 0
    OUT 0x53, R2        ; TIMER_A_THRESHOLD high
    
    ; Enable Timer A and its interrupt
    LDI R3, 0x01        ; irq_enable bit 0
    OUT 0x5A, R3        ; IRQ_PRIORITY
    
    LDI R4, 0x01        ; enable bit 0
    OUT 0x5C, R4        ; TIMER_CTRL
    
    JMP CHECK           ; Start checking

CHECK:
    IN R5, 0x58         ; Read IRQ_STATUS
    LDI R6, 0x10        ; Mask for any_irq_pending (bit 4)
    AND R7, R5, R6
    BEQ CHECK           ; If no interrupt, keep waiting
    
    ; An interrupt fired!
    OUT 0x02, 0xFF      ; Light all LEDs
    
    ; Clear the interrupt
    LDI R0, 0x01        ; clear_timer_a (bit 0)
    OUT 0x59, R0        ; IRQ_CLEAR
    
    JMP CHECK           ; Go back to checking

    HLT
```

---

## Implementation Checklist

### RTL Design (Week 13)

- [ ] Create `interrupt_controller.v` module (~250 lines)
  - [ ] Timer A counter + threshold registers
  - [ ] Timer B counter + threshold registers
  - [ ] Interrupt flag latches (sticky, cleared by write)
  - [ ] Priority encoder (determines which interrupt to service)
  - [ ] I/O port read multiplexer
  
- [ ] Integrate into `dsd8_top.v`
  - [ ] Instantiate interrupt controller
  - [ ] Add to I/O address decoder (ports 0x50–0x5F)
  - [ ] Connect io_port, io_wdata, io_rdata, io_rd, io_wr

- [ ] Write unit testbench
  - [ ] Timer increments each cycle when enabled
  - [ ] Interrupt flag sets when threshold is reached
  - [ ] Flag clears when written to IRQ_CLEAR
  - [ ] Priority encoder produces correct source ID

- [ ] Verify synthesis
  - [ ] No inferred latches
  - [ ] No combinational loops
  - [ ] Lint-clean

### Assembly & Verification (Week 14)

- [ ] Write dispatcher loop (`INTERRUPT_CHECK`)
  - [ ] Poll IRQ_STATUS
  - [ ] Read IRQ_SOURCE to determine which handler
  - [ ] Dispatch to correct handler

- [ ] Write timer handlers
  - [ ] Timer A handler (e.g., toggle LED)
  - [ ] Timer B handler (e.g., different LED pattern)
  - [ ] Event handler (software-triggered)

- [ ] Write test programs
  - [ ] Test 1: Single timer interrupt at N-cycle interval
  - [ ] Test 2: Two timers with different periods
  - [ ] Test 3: Software-triggered event interrupt
  - [ ] Test 4: Multiple interrupts in quick succession

- [ ] Verify interrupt behavior
  - [ ] Timers fire at correct intervals
  - [ ] Handlers execute correctly
  - [ ] Flags clear and allow re-triggering
  - [ ] Priority dispatch works correctly

### Documentation (Week 15)

- [ ] Update system block diagram
  - [ ] Show interrupt controller as I/O peripheral
  - [ ] Show port assignments (0x50–0x5F)

- [ ] Design report additions
  - [ ] Interrupt architecture section
  - [ ] Dispatcher flow (pseudo-code or assembly)
  - [ ] Handler structure and context save approach
  - [ ] Design decisions (why polling vs. hardware interrupts)

- [ ] Verification report
  - [ ] Unit testbench coverage
  - [ ] Test programs and results
  - [ ] Timing measurements (confirm intervals)
  - [ ] Bug log (what went wrong and how you found it)

### Demonstration (Week 16)

- [ ] Demo 1: Single timer blinking LED at precise interval
- [ ] Demo 2: Two timers with different rates, different LED patterns
- [ ] Demo 3: Multiple simultaneous interrupts, correct priority handling

---

## Common Pitfalls & Solutions

| Problem | Symptom | Solution |
|---------|---------|----------|
| Interrupt flag never sets | Timer runs but flag stays 0 | Check: (1) Enable bit set? (2) Threshold correct? (3) Counter actually incrementing? |
| Handler never executes | No LED change after interrupt | Check: (1) Dispatcher correctly reads IRQ_SOURCE? (2) Jump address calculated right? (3) Handler address correct? |
| Interrupt fires multiple times on one threshold match | LED toggles too many times | Check: Flag is sticky; MUST clear with IRQ_CLEAR between firings |
| Priority dispatch broken | Wrong handler executes | Check: IRQ_SOURCE reads correct ID; branch on that ID, not IRQ_STATUS bits |
| Timer only increments once | Counter stalls after first cycle | Check: enable bit logic; should increment EVERY cycle while enabled |
| Countdown never fires | Countdown mode selected but no interrupt | Check: Counter decrements (not increments); fire on ==0, not on overflow |

---

## Hardware Verification Strategy

### Quick Sanity Checks

1. **Timer increments?**
   ```assembly
   ; Setup and enable Timer A
   LDI R1, 0x00
   OUT 0x50, R1        ; Clear count
   OUT 0x51, R1
   LDI R2, 0x01
   OUT 0x5C, R2        ; Enable
   
   ; Wait a few cycles
   #20
   
   ; Read count
   IN R3, 0x50         ; Should be > 0
   ```

2. **Interrupt fires at right time?**
   ```assembly
   ; Set threshold = 10
   LDI R1, 10
   OUT 0x52, R1
   LDI R2, 0x01
   OUT 0x5A, R2        ; Enable interrupt
   OUT 0x5C, R2        ; Enable Timer A
   
   ; Wait exactly 10 cycles
   #50
   
   ; Check IRQ_STATUS
   IN R3, 0x58
   ; Bit 0 should be 1
   ```

3. **Clear works?**
   ```assembly
   IN R3, 0x58         ; Read status
   # Should show timer_a_irq = 1
   
   LDI R4, 0x01
   OUT 0x59, R4        ; Clear
   #10
   
   IN R5, 0x58         ; Read again
   # Should show timer_a_irq = 0
   ```

---

## Software Implementation Tips

### Efficient Dispatcher

**Avoid this (slow):**
```assembly
; Checking every bit individually
IN R0, 0x58
AND R1, R0, 0x01
BNE TIMER_A
AND R2, R0, 0x02
BNE TIMER_B
; ...
```

**Do this instead (fast):**
```assembly
; Use IRQ_SOURCE directly
IN R0, 0x5B        ; Get priority-encoded source ID
CMP R0, 0          ; Quick comparison (if only one source)
BEQ TIMER_A
CMP R0, 1
BEQ TIMER_B
; ...
```

### Handler Context Save

If handlers use registers, save them:

```assembly
HANDLER_TIMER_A:
    ; Save R0, R1 (assume others were using them before)
    ; In DSD-8, no stack, so use dedicated "saved" register locations
    
    ; Example: use R7 as a temporary saved value
    MOV R7, R0          ; Save R0 to R7
    
    ; Do handler work
    IN R0, 0x02         ; Read LEDs
    ADD R0, R0, 1       ; Increment
    OUT 0x02, R0        ; Write back
    
    ; Restore R0
    MOV R0, R7          ; Restore R0 from R7
    
    ; Clear interrupt and return
    LDI R1, 0x01
    OUT 0x59, R1
    JMP INTERRUPT_CHECK
```

### Avoiding Missed Interrupts

Always clear the flag BEFORE returning to dispatcher:

**WRONG:**
```assembly
HANDLER:
    ... do work ...
    JMP INTERRUPT_CHECK
    ; Flag never cleared! Will fire again immediately
```

**RIGHT:**
```assembly
HANDLER:
    ... do work ...
    LDI R0, 0x01        ; Bit for Timer A
    OUT 0x59, R0        ; Clear BEFORE returning
    JMP INTERRUPT_CHECK
```

---

## Performance Expectations

### Timing Accuracy

- **Timer accuracy:** ±0 cycles (exact match comparison)
- **Handler latency:** ~10 cycles (dispatcher loop overhead)
- **Interrupt overhead:** ~5–10 instructions to read status, dispatch, execute handler

### Example Timeline

```
Cycle 0:    Timer A = 0, enabled
Cycle 1:    Timer A = 1
...
Cycle 99:   Timer A = 99
Cycle 100:  Timer A = 100 (matches threshold)
            IRQ_STATUS bit 0 set = 1
Cycle 101:  Dispatcher reads IRQ_STATUS (bit 0 = 1)
Cycle 102:  Dispatcher reads IRQ_SOURCE (returns 0 = Timer A)
Cycle 103:  Jump to HANDLER_TIMER_A
Cycle 104:  Execute handler (toggle LED, etc.)
Cycle 105:  Clear flag with OUT 0x59
Cycle 106:  Jump back to INTERRUPT_CHECK
```

**Total latency:** ~5–6 cycles from interrupt event to handler execution

---

## Testing Strategy

### Unit Test (RTL)

```verilog
// Test: Timer A increments and triggers
write_port(0x52, 10);      // Threshold = 10
write_port(0x5A, 0x01);    // Enable Timer A interrupt
write_port(0x5C, 0x01);    // Enable Timer A

for (int i = 0; i < 20; i++) begin
    #10 clk pulse;
    if (i == 10) begin
        read_port(0x58);
        assert(io_rdata[0] == 1) $display("PASS: Timer A fired at cycle 10");
    end
end
```

### Assembly Test

```assembly
; Test: Timer fires and handler executes

LDI R1, 10
OUT 0x52, R1        ; Threshold = 10

LDI R2, 0x01
OUT 0x5A, R2        ; Enable
OUT 0x5C, R2        ; Start

LDI R3, 0            ; Handler call counter

LOOP:
    IN R4, 0x58     ; Poll
    BEQ LOOP        ; Wait
    
    ADD R3, R3, 1   ; Increment counter
    OUT 0x02, R3    ; Display on LEDs
    
    LDI R5, 0x01
    OUT 0x59, R5    ; Clear
    
    JMP LOOP
    
; After 10 cycles, LEDs should show 0x01
; After 20 cycles, LEDs should show 0x02
; etc.
```

---

## Design Justification Quick Answers

**Q: Why polling instead of hardware interrupts?**  
A: DSD-8 has no interrupt pins by design. Polling-based handling is how real embedded systems work with limited interrupt support.

**Q: Why two timers?**  
A: Teaches priority handling and multi-source interrupt dispatch. Real microcontrollers have multiple timers.

**Q: Why sticky flags?**  
A: Prevents race conditions. CPU reads flag, explicitly clears it. Matches UART model in DSD-8.

**Q: Why priority encoder?**  
A: Standard pattern. Teaches that multiple interrupts need prioritization. Scalable.

**Q: Why software context save, not automatic?**  
A: DSD-8 has no hardware stack. Software context save teaches how embedded systems really work.

---

## Milestones

| Milestone | Week | Deliverable | Status |
|-----------|------|-------------|--------|
| M1 | 11 | Module ownership, block diagram, control signal table | — |
| M2 | 12 | ALU, register file, decoder (not interrupt system) | — |
| M3 | 13 | **Interrupt controller RTL** + unit tests | ← Start here |
| M4 | 14 | Dispatcher + handlers + test programs | — |
| M5 | 15 | Documentation, demo program, design review | — |
| M6 | 16 | Final demo, oral defence | — |

---

## Resources You'll Need

1. **Timer/Counter Interrupt Specification.md** — Full technical details (250+ pages)
2. **Your DSD-8 Verilog template** — Already have dsd8_top.v
3. **DSD-8 assembler** — dsd8asm.py (supplied)
4. **Simulation environment** — Vivado, Quartus, or your simulator

---

## Next Steps

1. **This week:** Design RTL, write unit testbench, integrate into dsd8_top
2. **Next week:** Assembly dispatcher and handlers, test with example programs
3. **Final week:** Polish documentation, create impressive demo

**Time estimate:** 3–4 hours RTL design, 2–3 hours assembly/test, 2 hours documentation

Good luck! This interrupt system is going to be the standout feature of your design. 🎯
