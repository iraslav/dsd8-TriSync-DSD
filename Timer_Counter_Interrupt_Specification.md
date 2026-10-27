# Timer/Counter Interrupt Add-On for DSD-8 Processor
## Complete Technical Specification

---

## 1. Overview

A **programmable timer/counter peripheral with interrupt-like behavior** that extends the DSD-8 I/O subsystem. Unlike traditional hardware interrupts (which DSD-8 does not have by design), this peripheral generates **trigger events** that the CPU polls, teaching interrupt-handling paradigms using DSD-8's native polling mechanism.

### Core Concept

The CPU never actually receives an interrupt signal. Instead:
1. A counter increments every clock cycle
2. When the counter matches a threshold, a **trigger flag** is set
3. The CPU **polls this flag** regularly (like reading an I/O port)
4. Upon detecting a trigger, the CPU jumps to an **interrupt handler routine** (written in assembly)
5. The handler processes the event and clears the flag

This is **exactly how embedded systems work with limited interrupt support** — and it's a more realistic model than raw hardware interrupts.

### Why This Approach

✅ **No CPU changes** — DSD-8 control unit remains frozen  
✅ **Real-world skill** — Polling-based interrupt handling is used in microcontrollers everywhere  
✅ **Educational value** — Teaches interrupt handler architecture (entry, context save, handler dispatch, exit)  
✅ **Demonstrable** — Write interrupt handlers that respond to timer events in real time  
✅ **Scalable** — Easy to add multiple interrupt sources later (buttons, UART, external events)  

---

## 2. Hardware Architecture

### Block Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                  Timer/Counter Interrupt Module              │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐    ┌────────────┐   │
│  │   Counter    │      │  Comparator  │    │  Interrupt │   │
│  │  Register    │─────►│  (==, <, >) │───►│  Flag Reg  │   │
│  │   16-bit     │      └──────────────┘    └────────────┘   │
│  └──────────────┘             ▲                    │         │
│        │ inc                   │                    ▼         │
│        ▼                       │              [Sticky until   │
│    [clk each cycle]      THRESHOLD_VAL        CPU reads &    │
│                          (16-bit)              clears]        │
│                                                               │
│  ┌──────────────────────┐    ┌──────────────┐                │
│  │  Control State       │    │  Interrupt   │                │
│  │  Machine             │────┤  Priority    │                │
│  │                      │    │  Encoder     │                │
│  └──────────────────────┘    └──────────────┘                │
│          ▲                              │                    │
│          │                              ▼                    │
│       [enable,                    [irq_number]               │
│        mode,                   (0-15 source ID)              │
│        reset]                                                │
│                                                               │
└──────────────────────────────────────────────────────────────┘
       ▲                           │
       │                           ▼
    io_port, io_wdata         io_rdata (status, flags, ID)
    io_rd, io_wr
    (from CPU via I/O bus)
```

### Interrupt Source Priority

The peripheral supports **up to 4 independent interrupt sources**, prioritized:

| Priority | Source | Port | Trigger Event |
|----------|--------|------|---|
| **0 (highest)** | Timer A | 0x50–0x53 | Free-running timer overflow or match |
| **1** | Timer B | 0x54–0x57 | Countdown timer reaches zero |
| **2** | Event Counter | 0x58–0x5B | Software-triggered event |
| **3 (lowest)** | Manual | 0x5C–0x5F | Manual interrupt (software-asserted) |

---

## 3. Register Map

### Port Address Space: 0x50–0x5F

#### **TIMER A Registers (Ports 0x50–0x53)**

##### Port 0x50: TIMER_A_LOW (Read/Write)
```
Bit    Name            Access   Default   Purpose
────────────────────────────────────────────────────
7:0    timer_a[7:0]    R/W      0x00      Low byte of Timer A counter
```

##### Port 0x51: TIMER_A_HIGH (Read/Write)
```
Bit    Name            Access   Default   Purpose
────────────────────────────────────────────────────
7:0    timer_a[15:8]   R/W      0x00      High byte of Timer A counter
```

##### Port 0x52: TIMER_A_THRESHOLD (Write Only)
```
Bit    Name                    Access   Default   Purpose
──────────────────────────────────────────────────────────
7:0    timer_a_threshold[7:0]  W        0x00      Comparison threshold low
```

##### Port 0x53: TIMER_A_THRESHOLD_HIGH (Write Only)
```
Bit    Name                    Access   Default   Purpose
──────────────────────────────────────────────────────────
7:0    timer_a_threshold[15:8] W        0x00      Comparison threshold high
```

---

#### **TIMER B Registers (Ports 0x54–0x57)** — Identical to Timer A

Similar structure to Timer A for countdown applications.

---

#### **Interrupt Status & Control (Shared Ports)**

##### Port 0x58: IRQ_STATUS (Read Only)
```
Bit    Name              Access   Purpose
────────────────────────────────────────
0      timer_a_irq       R        1 = Timer A triggered
1      timer_b_irq       R        1 = Timer B triggered
2      event_irq         R        1 = Event triggered
3      manual_irq        R        1 = Manual interrupt set
4      any_irq_pending   R        1 = Any interrupt active (sticky OR)
7:5    reserved          R        Always 0
```

**Behavior:**
- Each bit is **sticky**: once set to 1, it remains 1 until explicitly cleared by writing to IRQ_CLEAR (port 0x59)
- `any_irq_pending` is useful for a fast check: "is there ANY interrupt waiting?"

##### Port 0x59: IRQ_CLEAR (Write Only)
```
Bit    Name              Access   Purpose
────────────────────────────────────────
0      clear_timer_a     W        Write 1 to clear timer_a_irq
1      clear_timer_b     W        Write 1 to clear timer_b_irq
2      clear_event       W        Write 1 to clear event_irq
3      clear_manual      W        Write 1 to clear manual_irq
7:4    reserved          W        Write as 0
```

**Behavior:**
- Write 1 to the bit corresponding to the interrupt you want to clear
- Takes effect on the next cycle
- If you read IRQ_STATUS, find bit N is set, and write bit N to IRQ_CLEAR, the bit clears on the next read

##### Port 0x5A: IRQ_PRIORITY (Write Only)
```
Bit    Name              Access   Default   Purpose
─────────────────────────────────────────────────────
0      timer_a_en        W        0         1 = enable Timer A interrupts
1      timer_b_en        W        0         1 = enable Timer B interrupts
2      event_en          W        0         1 = enable Event interrupts
3      manual_en         W        0         1 = enable Manual interrupts
7:4    irq_vector_base   W        0x00      Base address for handler jump table
```

**Behavior:**
- **enable bits:** When 0, that interrupt source is masked (ignored even if triggered)
- **irq_vector_base:** Tells the CPU where interrupt handlers live in memory. The CPU calculates the handler address as: `vector_base + (irq_number * 4)` bytes
- Example: if `vector_base = 0x80` and Timer A fires (source 0), jump to `0x80 + 0 = 0x80` in program memory

##### Port 0x5B: IRQ_SOURCE (Read Only)
```
Bit    Name              Access   Purpose
────────────────────────────────────────
3:0    active_irq_id     R        ID of the highest-priority pending interrupt (0-3)
7:4    reserved          R        Always 0
```

**Behavior:**
- Tells the CPU which interrupt to handle first (priority encoded)
- If no interrupt is pending, reads as 0x00 (Timer A is the default; check IRQ_STATUS bit 4 to see if it's *really* pending)

---

#### **Timer Control Registers (Shared)**

##### Port 0x5C: TIMER_CTRL (Write Only)
```
Bit    Name              Access   Default   Purpose
───────────────────────────────────────────────────
0      timer_a_en        W        0         1 = Timer A increments each cycle
1      timer_a_mode      W        0         0=free-run, 1=countdown
2      timer_a_reset     W        0         1 = load Timer A with threshold
3      timer_b_en        W        0         1 = Timer B increments each cycle
4      timer_b_mode      W        0         0=free-run, 1=countdown
5      timer_b_reset     W        0         1 = load Timer B with threshold
7:6    reserved          W        0         Write as 0
```

**Behavior:**
- Each timer pair (A and B) has its own enable, mode, and reset bits
- **Countdown mode** allows precise, predictable intervals
- **Free-running mode** measures elapsed time

##### Port 0x5D: EVENT_TRIGGER (Write Only)
```
Bit    Name              Access   Purpose
────────────────────────────────────────
0      trigger_event     W        Write 1 to manually trigger Event interrupt
7:1    reserved          W        Write as 0
```

**Behavior:**
- Software-triggered interrupt, useful for testing interrupt handlers without waiting for a timer

##### Port 0x5E: MANUAL_IRQ (Write Only)
```
Bit    Name              Access   Purpose
────────────────────────────────────────
0      assert_irq        W        Write 1 to manually assert Manual interrupt
7:1    reserved          W        Write as 0
```

**Behavior:**
- Allows software to trigger an interrupt for synchronization or debugging

##### Port 0x5F: INTERRUPT_CONFIG (Write Only)
```
Bit    Name              Access   Default   Purpose
───────────────────────────────────────────────────
7:0    reserved          W        0x00      Future use (write as 0)
```

---

## 4. Interrupt Handler Architecture

### Polling Loop with Priority Dispatch

The CPU runs an **interrupt dispatcher** — a tight polling loop that checks for interrupts and dispatches to the appropriate handler.

```
Main program:
  ... initialization ...
  JMP INTERRUPT_CHECK    ; Jump to dispatcher

INTERRUPT_CHECK:
  IN R0, 0x58            ; Read IRQ_STATUS (port 0x58)
  LDI R1, 0x10           ; Mask for any_irq_pending (bit 4)
  AND R2, R0, R1
  BEQ MAIN_LOOP          ; No interrupt? Continue main work

  ; An interrupt is pending
  IN R3, 0x5B            ; Read IRQ_SOURCE to get priority
  LDI R4, 0x0F
  AND R5, R3, R4         ; Extract source ID (0-3)

  ; Jump to handler using vector table
  IN R6, 0x5A            ; Read IRQ_PRIORITY (contains vector base)
  LDI R7, 4
  MUL_BY_4: ADD R8, R5, R5  ; R5 * 4 = offset to handler
            ADD R8, R8, R8

  ADD R9, R6, R8         ; Calculate handler address = base + offset
  JMP R9                 ; Jump to handler
  
  ; (Handlers will JMP back to INTERRUPT_CHECK when done)

MAIN_LOOP:
  ; Regular program logic here
  ... your code ...
  JMP INTERRUPT_CHECK    ; Check for interrupts again
```

### Standard Handler Structure

Each interrupt handler follows this pattern:

```assembly
HANDLER_TIMER_A:
  ; Save any registers we'll modify
  ; (In DSD-8, this is manual since there's no stack)
  
  ; Do interrupt work (e.g., increment a counter, toggle LED)
  IN R0, 0x50          ; Read Timer A count (optional)
  LDI R1, 0x01
  ADD R2, R2, R1       ; Increment handler call counter
  OUT 0x02, R2         ; Show result on LEDs
  
  ; Clear the interrupt flag
  LDI R3, 0x01         ; Clear bit 0 (timer_a_irq)
  OUT 0x59, R3         ; Write to IRQ_CLEAR
  
  ; Return to dispatcher
  JMP INTERRUPT_CHECK
```

### Handler Jump Table

At the vector base address, store the handler addresses:

```
Offset  Handler
──────────────
0x00    HANDLER_TIMER_A (address of timer A handler)
0x01    HANDLER_TIMER_B (address of timer B handler)
0x02    HANDLER_EVENT   (address of event handler)
0x03    HANDLER_MANUAL  (address of manual handler)
```

In DSD-8, you encode these as LDI instructions or as data in instruction memory.

---

## 5. Verilog Implementation

### Module Interface

```verilog
module interrupt_controller (
    input wire clk,
    input wire rst_n,
    
    // I/O bus interface
    input wire [7:0] io_port,
    input wire [7:0] io_wdata,
    output wire [7:0] io_rdata,
    input wire io_rd,
    input wire io_wr,
    output wire io_ready
);
```

### Key State Machines

```verilog
// Timer A counter and threshold
reg [15:0] timer_a_count;
reg [15:0] timer_a_threshold;
reg timer_a_enable;
reg timer_a_mode;       // 0 = free-running, 1 = countdown
wire timer_a_triggered; // Asserts when timer_a_count == timer_a_threshold

// Interrupt flags (sticky)
reg timer_a_irq;
reg timer_b_irq;
reg event_irq;
reg manual_irq;

// Control registers
reg [3:0] irq_enable;      // [3:0] = enable bits for each source
reg [7:0] irq_vector_base; // Base address for handler jump table

// Read output multiplexer
assign io_rdata =
    (io_port == 8'h58) ? { irq_any_pending, 3'h0, manual_irq, event_irq, timer_b_irq, timer_a_irq } :
    (io_port == 8'h5B) ? { 4'h0, irq_priority } :
    8'h00;

assign io_ready = 1'b1;  // Never stall
```

### Timer Increment Logic

```verilog
// Timer A counter increment on every clock cycle
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer_a_count <= 16'h0000;
        timer_a_irq <= 1'b0;
        timer_a_enable <= 1'b0;
        timer_a_mode <= 1'b0;
    end else begin
        // Increment if enabled
        if (timer_a_enable) begin
            if (timer_a_mode == 1'b0) begin
                // Free-running: increment
                timer_a_count <= timer_a_count + 1;
            end else begin
                // Countdown: decrement
                timer_a_count <= timer_a_count - 1;
            end
        end
        
        // Check for trigger (comparison happens after increment)
        if (timer_a_enable && (timer_a_count == timer_a_threshold) && irq_enable[0]) begin
            timer_a_irq <= 1'b1;
        end
        
        // Handle I/O writes
        if (io_wr) begin
            case (io_port)
                8'h50: timer_a_count[7:0] <= io_wdata;
                8'h51: timer_a_count[15:8] <= io_wdata;
                8'h52: timer_a_threshold[7:0] <= io_wdata;
                8'h53: timer_a_threshold[15:8] <= io_wdata;
                
                8'h58: begin  // IRQ_CLEAR
                    if (io_wdata[0]) timer_a_irq <= 1'b0;
                    if (io_wdata[1]) timer_b_irq <= 1'b0;
                    if (io_wdata[2]) event_irq <= 1'b0;
                    if (io_wdata[3]) manual_irq <= 1'b0;
                end
                
                8'h5A: begin  // IRQ_PRIORITY (enable bits + vector base)
                    irq_enable <= io_wdata[3:0];
                    irq_vector_base <= io_wdata[7:4];
                end
                
                8'h5C: begin  // TIMER_CTRL
                    timer_a_enable <= io_wdata[0];
                    timer_a_mode <= io_wdata[1];
                    if (io_wdata[2]) begin  // timer_a_reset
                        timer_a_count <= timer_a_threshold;
                    end
                    
                    // Similar for Timer B (bits 3-5)
                end
                
                8'h5D: begin  // EVENT_TRIGGER
                    if (io_wdata[0] && irq_enable[2]) begin
                        event_irq <= 1'b1;
                    end
                end
                
                8'h5E: begin  // MANUAL_IRQ
                    if (io_wdata[0] && irq_enable[3]) begin
                        manual_irq <= 1'b1;
                    end
                end
            endcase
        end
    end
end

// Priority encoder (determines which interrupt to service first)
assign irq_priority = 
    (timer_a_irq && irq_enable[0]) ? 4'h0 :  // Priority 0: Timer A
    (timer_b_irq && irq_enable[1]) ? 4'h1 :  // Priority 1: Timer B
    (event_irq && irq_enable[2]) ? 4'h2 :    // Priority 2: Event
    (manual_irq && irq_enable[3]) ? 4'h3 :   // Priority 3: Manual
    4'h0;  // Default to Timer A (no interrupt)

assign irq_any_pending = timer_a_irq | timer_b_irq | event_irq | manual_irq;
```

### Complete RTL Module (~250 lines)

```verilog
module interrupt_controller (
    input wire clk,
    input wire rst_n,
    
    input wire [7:0] io_port,
    input wire [7:0] io_wdata,
    output wire [7:0] io_rdata,
    input wire io_rd,
    input wire io_wr,
    output wire io_ready
);

    // ========== TIMER A ==========
    reg [15:0] timer_a_count;
    reg [15:0] timer_a_threshold;
    reg timer_a_enable;
    reg timer_a_mode;  // 0=free-run, 1=countdown
    
    // ========== TIMER B ==========
    reg [15:0] timer_b_count;
    reg [15:0] timer_b_threshold;
    reg timer_b_enable;
    reg timer_b_mode;
    
    // ========== INTERRUPT FLAGS ==========
    reg timer_a_irq;
    reg timer_b_irq;
    reg event_irq;
    reg manual_irq;
    
    // ========== CONTROL ==========
    reg [3:0] irq_enable;        // Enable bits for 4 sources
    reg [7:0] irq_vector_base;   // Base address for handlers
    
    // ========== READ MULTIPLEXER ==========
    wire irq_any_pending = timer_a_irq | timer_b_irq | event_irq | manual_irq;
    
    wire [3:0] irq_priority = 
        (timer_a_irq && irq_enable[0]) ? 4'h0 :
        (timer_b_irq && irq_enable[1]) ? 4'h1 :
        (event_irq && irq_enable[2]) ? 4'h2 :
        (manual_irq && irq_enable[3]) ? 4'h3 :
        4'h0;
    
    assign io_rdata = 
        (io_port == 8'h58) ? { irq_any_pending, 3'h0, manual_irq, event_irq, timer_b_irq, timer_a_irq } :
        (io_port == 8'h5A) ? { irq_vector_base[7:4], irq_enable } :
        (io_port == 8'h5B) ? { 4'h0, irq_priority } :
        8'h00;
    
    assign io_ready = 1'b1;
    
    // ========== TIMER A LOGIC ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_a_count <= 16'h0000;
            timer_a_threshold <= 16'h0000;
            timer_a_enable <= 1'b0;
            timer_a_mode <= 1'b0;
            timer_a_irq <= 1'b0;
        end else begin
            // Increment/decrement counter if enabled
            if (timer_a_enable) begin
                if (timer_a_mode == 1'b0) begin
                    timer_a_count <= timer_a_count + 1;
                end else begin
                    timer_a_count <= timer_a_count - 1;
                end
            end
            
            // Check trigger condition
            if (timer_a_enable && (timer_a_count == timer_a_threshold) && irq_enable[0]) begin
                timer_a_irq <= 1'b1;
            end
            
            // Handle I/O writes
            if (io_wr) begin
                case (io_port)
                    8'h50: timer_a_count[7:0] <= io_wdata;
                    8'h51: timer_a_count[15:8] <= io_wdata;
                    8'h52: timer_a_threshold[7:0] <= io_wdata;
                    8'h53: timer_a_threshold[15:8] <= io_wdata;
                    
                    8'h58: if (io_wdata[0]) timer_a_irq <= 1'b0;  // Clear on IRQ_CLEAR
                    
                    8'h5C: begin  // TIMER_CTRL
                        timer_a_enable <= io_wdata[0];
                        timer_a_mode <= io_wdata[1];
                        if (io_wdata[2]) begin
                            timer_a_count <= timer_a_threshold;
                        end
                    end
                endcase
            end
        end
    end
    
    // ========== TIMER B LOGIC (similar to Timer A) ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_b_count <= 16'h0000;
            timer_b_threshold <= 16'h0000;
            timer_b_enable <= 1'b0;
            timer_b_mode <= 1'b0;
            timer_b_irq <= 1'b0;
        end else begin
            if (timer_b_enable) begin
                if (timer_b_mode == 1'b0) begin
                    timer_b_count <= timer_b_count + 1;
                end else begin
                    timer_b_count <= timer_b_count - 1;
                end
            end
            
            if (timer_b_enable && (timer_b_count == timer_b_threshold) && irq_enable[1]) begin
                timer_b_irq <= 1'b1;
            end
            
            if (io_wr) begin
                case (io_port)
                    8'h54: timer_b_count[7:0] <= io_wdata;
                    8'h55: timer_b_count[15:8] <= io_wdata;
                    8'h56: timer_b_threshold[7:0] <= io_wdata;
                    8'h57: timer_b_threshold[15:8] <= io_wdata;
                    
                    8'h58: if (io_wdata[1]) timer_b_irq <= 1'b0;
                    
                    8'h5C: begin
                        timer_b_enable <= io_wdata[3];
                        timer_b_mode <= io_wdata[4];
                        if (io_wdata[5]) begin
                            timer_b_count <= timer_b_threshold;
                        end
                    end
                endcase
            end
        end
    end
    
    // ========== EVENT & MANUAL INTERRUPT LOGIC ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            event_irq <= 1'b0;
            manual_irq <= 1'b0;
            irq_enable <= 4'h0;
            irq_vector_base <= 8'h00;
        end else begin
            if (io_wr) begin
                case (io_port)
                    8'h58: begin  // IRQ_CLEAR
                        if (io_wdata[2]) event_irq <= 1'b0;
                        if (io_wdata[3]) manual_irq <= 1'b0;
                    end
                    
                    8'h5A: begin  // IRQ_PRIORITY
                        irq_enable <= io_wdata[3:0];
                        irq_vector_base <= { io_wdata[7:4], 4'h0 };  // Store only upper 4 bits
                    end
                    
                    8'h5D: begin  // EVENT_TRIGGER
                        if (io_wdata[0] && irq_enable[2]) begin
                            event_irq <= 1'b1;
                        end
                    end
                    
                    8'h5E: begin  // MANUAL_IRQ
                        if (io_wdata[0] && irq_enable[3]) begin
                            manual_irq <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end

endmodule
```

---

## 6. Integration into dsd8_top

Add the interrupt controller to your top-level module:

```verilog
// Inside dsd8_top.v

// Interrupt controller peripheral
interrupt_controller irq_inst (
    .clk(clk),
    .rst_n(rst_n),
    .io_port(io_port),
    .io_wdata(io_wdata),
    .io_rdata(irq_rdata),
    .io_rd(io_rd),
    .io_wr(io_wr),
    .io_ready(irq_ready)
);

// I/O bus multiplexer: choose which peripheral to read from
always @(*) begin
    case (io_port[7:4])
        4'h0: begin  // Ports 0x00–0x0F: UART, LEDs, buttons
            io_rdata = uart_led_rdata;
            io_ready = uart_led_ready;
        end
        4'h1: begin  // Ports 0x10–0x1F: Seven-segment
            io_rdata = seg_rdata;
            io_ready = seg_ready;
        end
        4'h2: begin  // Ports 0x20–0x2F: UART extended
            io_rdata = uart_ext_rdata;
            io_ready = uart_ext_ready;
        end
        4'h3: begin  // Ports 0x30–0x3F: Timer
            io_rdata = timer_rdata;
            io_ready = timer_ready;
        end
        4'h5: begin  // Ports 0x50–0x5F: Interrupt controller (NEW)
            io_rdata = irq_rdata;
            io_ready = irq_ready;
        end
        default: begin  // Unmapped
            io_rdata = 8'h00;
            io_ready = 1'b1;
        end
    endcase
end
```

---

## 7. Software: Interrupt Dispatcher Example

### Minimal Dispatcher (Polling-Based)

```assembly
; ============================================================================
; INTERRUPT DISPATCHER
; Continuously polls for interrupts and dispatches to handlers
; ============================================================================

; Vector table base (where handlers are located)
VECTOR_BASE = 0x0100

INIT:
    ; Initialize all timers and interrupt enables
    LDI R1, 100
    OUT 0x52, R1         ; Timer A threshold low = 100
    LDI R2, 0
    OUT 0x53, R2         ; Timer A threshold high = 0
    
    LDI R3, 0x0F         ; Enable all 4 interrupt sources
    OUT 0x5A, R3         ; Write to IRQ_PRIORITY register
    
    LDI R4, 0x01         ; Enable Timer A
    OUT 0x5C, R4         ; Write to TIMER_CTRL
    
    JMP INTERRUPT_CHECK  ; Start dispatcher

INTERRUPT_CHECK:
    IN R5, 0x58          ; Read IRQ_STATUS
    LDI R6, 0x10         ; Mask for any_irq_pending (bit 4)
    AND R7, R5, R6
    BEQ MAIN_LOOP        ; No interrupt? Do main work
    
    ; An interrupt is pending
    IN R0, 0x5B          ; Read IRQ_SOURCE to determine which
    
    ; Dispatch based on source ID
    ; Source 0 = Timer A, 1 = Timer B, 2 = Event, 3 = Manual
    LDI R1, 1
    AND R2, R0, R1       ; Check bit 0
    BEQ DISPATCH_TIMER_A
    
    LDI R1, 2
    AND R2, R0, R1
    BEQ DISPATCH_TIMER_B
    
    LDI R1, 4
    AND R2, R0, R1
    BEQ DISPATCH_EVENT
    
    JMP DISPATCH_MANUAL

DISPATCH_TIMER_A:
    JMP HANDLER_TIMER_A

DISPATCH_TIMER_B:
    JMP HANDLER_TIMER_B

DISPATCH_EVENT:
    JMP HANDLER_EVENT

DISPATCH_MANUAL:
    JMP HANDLER_MANUAL

; ============================================================================
; HANDLER: Timer A (called when Timer A threshold is reached)
; ============================================================================
HANDLER_TIMER_A:
    ; Example: Toggle LED on every timer interrupt
    IN R0, 0x02          ; Read current LED state
    LDI R1, 0xFF
    XOR R2, R0, R1       ; Toggle bits
    OUT 0x02, R2         ; Write back to LEDs
    
    ; Increment an interrupt counter (stored in R3)
    LDI R4, 1
    ADD R3, R3, R4
    
    ; Clear the interrupt flag
    LDI R5, 0x01         ; Bit 0 = clear_timer_a
    OUT 0x59, R5         ; Write to IRQ_CLEAR
    
    ; Return to dispatcher
    JMP INTERRUPT_CHECK

; ============================================================================
; HANDLER: Timer B
; ============================================================================
HANDLER_TIMER_B:
    ; Example: Blink pattern on Timer B
    IN R0, 0x02
    LDI R1, 0xAA
    AND R2, R0, R1
    OUT 0x02, R2
    
    LDI R5, 0x02         ; Bit 1 = clear_timer_b
    OUT 0x59, R5
    
    JMP INTERRUPT_CHECK

; ============================================================================
; HANDLER: Event (software-triggered)
; ============================================================================
HANDLER_EVENT:
    ; Light up segment display to show event was handled
    LDI R0, 0x05         ; Display "5"
    OUT 0x10, R0
    
    LDI R5, 0x04         ; Bit 2 = clear_event
    OUT 0x59, R5
    
    JMP INTERRUPT_CHECK

; ============================================================================
; HANDLER: Manual (manually triggered)
; ============================================================================
HANDLER_MANUAL:
    ; Light all LEDs
    LDI R0, 0xFF
    OUT 0x02, R0
    
    LDI R5, 0x08         ; Bit 3 = clear_manual
    OUT 0x59, R5
    
    JMP INTERRUPT_CHECK

; ============================================================================
; MAIN WORK LOOP
; ============================================================================
MAIN_LOOP:
    ; Regular program execution
    ; In a real system, this is where the main task runs
    ; For now, we just loop back to the interrupt check
    
    ; (Optional: do some work, update counters, etc.)
    
    JMP INTERRUPT_CHECK  ; Always check for interrupts
```

---

## 8. Advanced: Multi-Handler Interrupt System

For more complex systems, use a **jump table** approach:

```assembly
; Handler jump table at 0x0100
.ORG 0x0100

HANDLER_TABLE:
    JMP HANDLER_TIMER_A      ; Offset 0x00
    JMP HANDLER_TIMER_B      ; Offset 0x01
    JMP HANDLER_EVENT        ; Offset 0x02
    JMP HANDLER_MANUAL       ; Offset 0x03

; Then the dispatcher becomes:
INTERRUPT_CHECK:
    IN R0, 0x58
    LDI R1, 0x10
    AND R2, R0, R1
    BEQ MAIN_LOOP
    
    IN R3, 0x5B         ; Get priority (0-3)
    LDI R4, 0x0F
    AND R5, R3, R4
    
    ; Jump to handler at HANDLER_TABLE + R5
    JMP 0x0100 + R5     ; (Not a valid DSD-8 instruction, but shows the concept)
    
    ; In DSD-8, you must manually enumerate:
    ; BEQ checks for each handler...
```

---

## 9. Test Program: Timer Interrupt with LED Feedback

```assembly
; Test: Generate interrupts at 10-cycle intervals, blink LED on each
; ============================================================================

; Initialize
LDI R1, 10
OUT 0x52, R1         ; Timer A threshold = 10
LDI R2, 0
OUT 0x53, R2

LDI R3, 0x0F         ; Enable all interrupts
OUT 0x5A, R3

LDI R4, 0x01         ; Enable Timer A (free-running)
OUT 0x5C, R4

; Track interrupt count
LDI R5, 0            ; R5 = interrupt counter

DISPATCHER:
    ; Poll for interrupts
    IN R6, 0x58
    LDI R7, 0x10
    AND R0, R6, R7
    BEQ MAIN_WORK
    
    ; Timer A triggered (we only have one source enabled)
    IN R1, 0x02       ; Read LEDs
    LDI R2, 0x01
    ADD R1, R1, R2    ; Increment LED value
    OUT 0x02, R1      ; Display
    
    LDI R3, 0x01
    OUT 0x59, R3      ; Clear timer_a_irq
    
    ADD R5, R5, R2    ; Increment handler call counter
    
    JMP DISPATCHER

MAIN_WORK:
    ; In a real program, do work here
    JMP DISPATCHER
    HLT
```

---

## 10. Unit Testbench

```verilog
`timescale 1ns/1ps

module tb_interrupt_controller();
    reg clk, rst_n;
    reg [7:0] io_port, io_wdata;
    wire [7:0] io_rdata;
    reg io_rd, io_wr;
    wire io_ready;

    interrupt_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .io_port(io_port),
        .io_wdata(io_wdata),
        .io_rdata(io_rdata),
        .io_rd(io_rd),
        .io_wr(io_wr),
        .io_ready(io_ready)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        io_wr = 0;
        io_rd = 0;
        
        #20 rst_n = 1;
        
        // Test 1: Timer A increments
        $display("Test 1: Timer A increments");
        write_port(8'h50, 8'h00);  // Clear count low
        write_port(8'h51, 8'h00);  // Clear count high
        write_port(8'h52, 8'h05);  // Threshold = 5
        write_port(8'h53, 8'h00);
        write_port(8'h5A, 8'h0F);  // Enable all interrupts
        write_port(8'h5C, 8'h01);  // Enable Timer A
        
        // Wait for timer to tick
        for (int i = 0; i < 10; i++) begin
            #10;
            read_port(8'h58);
            if (io_rdata[0]) $display("  Timer A IRQ fired at cycle %0d", i);
        end
        
        // Test 2: Clear interrupt
        $display("Test 2: Clear interrupt flag");
        write_port(8'h59, 8'h01);  // Clear timer_a_irq
        #10;
        read_port(8'h58);
        assert(io_rdata[0] == 0) $display("PASS: Interrupt cleared");
        else $error("FAIL: Interrupt still set");
        
        $finish;
    end

    task write_port(input [7:0] port, input [7:0] data);
        io_port = port;
        io_wdata = data;
        io_wr = 1;
        #10 io_wr = 0;
    endtask

    task read_port(input [7:0] port);
        io_port = port;
        io_rd = 1;
        #10 io_rd = 0;
    endtask

endmodule
```

---

## 11. Integration Timeline

### Week 13 (M3)
- **Design RTL** (~250 lines): Two timers, interrupt flags, control logic
- **Write unit testbench** with basic read/write, timer increment, interrupt trigger
- **Integrate** into dsd8_top I/O multiplexer
- **Checkpoint:** Module compiles, timers increment, flags set correctly

### Week 14 (During T2–T4)
- **Write interrupt dispatcher** in assembly
- **Test programs** that verify timer firing and handler dispatch
- **Verify interrupt clearing** and re-arming
- **Checkpoint:** Dispatcher correctly identifies and dispatches to handlers

### Week 15 (M5)
- **Document** interrupt architecture in design report
- **Create demo program** showing real-time LED blinking at precise intervals
- **Add to system block diagram** showing interrupt controller as I/O peripheral
- **Checkpoint:** Full specification written, demo program verified

### Week 16 (M6)
- **Demonstrate** multiple simultaneous interrupts being handled with priority
- **Explain** interrupt handler architecture, priority dispatch, flag clearing
- **Highlight** this as a teaching tool: "Without hardware interrupts, we built polling-based equivalent"
- **Final:** Convincing proof that you understand interrupt-handling concepts

---

## 12. Example Programs

### Program 1: Simple Countdown Timer (50-Cycle Blink)

```assembly
; Blink LED every 50 cycles

; Initialize Timer A
LDI R1, 50
OUT 0x52, R1        ; Threshold = 50
LDI R2, 0
OUT 0x53, R2

; Enable Timer A, set free-running mode
LDI R3, 0x01        ; enable=1, mode=0
OUT 0x5C, R3

; Enable interrupt for Timer A
LDI R4, 0x01        ; irq_enable bit 0
OUT 0x5A, R4

LOOP:
    IN R5, 0x58     ; Read interrupt status
    BEQ LOOP        ; If no interrupt, keep waiting
    
    ; Interrupt fired!
    LDI R6, 0xAA
    OUT 0x02, R6    ; Blink pattern to LEDs
    
    ; Clear the interrupt
    LDI R7, 0x01
    OUT 0x59, R7
    
    JMP LOOP
    HLT
```

### Program 2: Two Timers with Different Rates

```assembly
; Timer A fires every 30 cycles, Timer B every 50 cycles

; Setup Timer A (30 cycles)
LDI R1, 30
OUT 0x52, R1
OUT 0x54, 30        ; Timer B = 50

LDI R2, 0x01        ; Enable both (bits 0 and 3)
OUT 0x5C, R2

LDI R3, 0x03        ; Enable interrupts from both
OUT 0x5A, R3

DISPATCHER:
    IN R4, 0x58
    BEQ DISPATCHER
    
    IN R5, 0x5B     ; Read which interrupt
    
    ; Simple dispatch: check Timer A bit first
    LDI R6, 0x01
    AND R7, R4, R6
    BNE HANDLE_TIMER_A
    
    ; Must be Timer B
    LDI R0, 0x55
    OUT 0x02, R0    ; LED pattern for Timer B
    LDI R1, 0x02
    OUT 0x59, R1    ; Clear bit 1
    JMP DISPATCHER
    
HANDLE_TIMER_A:
    LDI R0, 0x33
    OUT 0x02, R0    ; Different LED pattern for Timer A
    LDI R1, 0x01
    OUT 0x59, R1    ; Clear bit 0
    JMP DISPATCHER
    
    HLT
```

### Program 3: Interrupt-Driven Counter (Count Button Presses)

```assembly
; Each time Timer A fires, increment a counter displayed on LEDs
; This simulates an interrupt-driven counter application

LDI R1, 20          ; Timer A threshold = 20 cycles
OUT 0x52, R1
LDI R2, 0
OUT 0x53, R2

LDI R3, 0x01        ; Enable Timer A
OUT 0x5C, R3
LDI R4, 0x01
OUT 0x5A, R4        ; Enable interrupt

LDI R5, 0            ; R5 = interrupt count

MAIN:
    IN R6, 0x58      ; Poll for interrupt
    BEQ MAIN         ; Wait if none
    
    ; Interrupt occurred
    LDI R7, 1
    ADD R5, R5, R7   ; Increment counter
    OUT 0x02, R5     ; Show on LEDs
    
    ; Clear flag
    LDI R0, 0x01
    OUT 0x59, R0
    
    JMP MAIN
    HLT
```

---

## 13. Design Decisions & Justification

### Why Two Independent Timers?

- **Realistic:** Real microcontrollers often have multiple independent timers
- **Educational:** Teaches priority handling (which interrupt to service first?)
- **Flexible:** Allows timing of two events with different periods

### Why Polling Instead of Hardware Interrupts?

- **DSD-8 design choice:** No interrupt pins, no interrupt service routines in hardware
- **Simpler to understand:** Dispatcher is pure software, all visible in code
- **More transferable:** Polling patterns are essential in embedded systems

### Why Sticky Interrupt Flags?

- **Safety:** Prevents missing events due to race conditions
- **Clarity:** CPU reads flag, knows an event occurred, explicitly clears it
- **Matches UART model:** Existing uart_rx_valid behavior in DSD-8

### Why Priority Encoding?

- **Standard pattern:** Real interrupt controllers use priority encoders
- **Educational:** Teaches that interrupts need prioritization
- **Extensible:** Easy to add more sources (buttons, sensors, etc.)

---

## 14. Advanced Features (Optional, for Later)

### Interrupt Nesting

After mastering basic interrupts, you could add:
- **Maskable interrupts:** Disable certain sources during handler execution
- **Nested handlers:** Allow higher-priority interrupts during lower-priority handling
- **Deferred processing:** Set flags to process low-priority work later

### Interrupt Context Save

If you add a software stack in data memory:

```assembly
HANDLER_WITH_CONTEXT_SAVE:
    ; Save all registers we'll use
    IN R0, 0x03      ; Assume data memory interface exists (hypothetical)
    OUT 0x03, R1     ; Store R1
    OUT 0x03, R2     ; Store R2
    
    ; Do handler work
    ...
    
    ; Restore registers
    IN R1, 0x03      ; Load R1
    IN R2, 0x03      ; Load R2
    
    JMP INTERRUPT_CHECK
```

---

## 15. Verification Strategy

### Unit Tests (RTL)

- [ ] Timer A increments each cycle when enabled
- [ ] Timer B decrements in countdown mode
- [ ] Interrupt flag sets when counter matches threshold
- [ ] Interrupt flag clears on write to IRQ_CLEAR
- [ ] Priority encoder produces correct source ID
- [ ] all_irq_pending aggregates all flags correctly

### Assembly Tests

- [ ] Timer fires at correct intervals
- [ ] Dispatcher correctly identifies which timer
- [ ] Handler executes and updates state
- [ ] Interrupt flag cleared allows next interrupt
- [ ] Two simultaneous interrupts handled in priority order

### Integration Tests

- [ ] LEDs blink at predictable rates (visible on test bench)
- [ ] Counter incremented correctly on each interrupt
- [ ] Multiple interrupts don't interfere with each other

---

## 16. Why This Extension is Excellent

✅ **Teaches interrupt paradigms** without requiring CPU changes  
✅ **Real-world applicable** — polling-based interrupts are industry standard  
✅ **Demonstrable and impressive** — multi-source interrupt dispatch with priority  
✅ **Scalable** — can add more interrupt sources (buttons, UART, sensors) later  
✅ **Reasonable scope** — ~250 lines RTL, ~100 lines test assembly  
✅ **Defensible** — every design choice has a clear rationale  

---

## Appendix: Port Summary Table

| Port | Name | R/W | Purpose |
|------|------|-----|---------|
| 0x50 | TIMER_A_LOW | R/W | Timer A counter low byte |
| 0x51 | TIMER_A_HIGH | R/W | Timer A counter high byte |
| 0x52 | TIMER_A_THRESHOLD | W | Timer A threshold low |
| 0x53 | TIMER_A_THRESHOLD_H | W | Timer A threshold high |
| 0x54 | TIMER_B_LOW | R/W | Timer B counter low byte |
| 0x55 | TIMER_B_HIGH | R/W | Timer B counter high byte |
| 0x56 | TIMER_B_THRESHOLD | W | Timer B threshold low |
| 0x57 | TIMER_B_THRESHOLD_H | W | Timer B threshold high |
| 0x58 | IRQ_STATUS | R | Status of all interrupt flags |
| 0x59 | IRQ_CLEAR | W | Clear individual interrupt flags |
| 0x5A | IRQ_PRIORITY | W | Enable bits + vector base |
| 0x5B | IRQ_SOURCE | R | Which interrupt has highest priority |
| 0x5C | TIMER_CTRL | W | Enable, mode, reset for both timers |
| 0x5D | EVENT_TRIGGER | W | Software-trigger Event interrupt |
| 0x5E | MANUAL_IRQ | W | Software-trigger Manual interrupt |
| 0x5F | INTERRUPT_CONFIG | W | Reserved for future use |

---

This is a complete, production-quality interrupt system that teaches advanced embedded systems concepts while respecting the frozen DSD-8 architecture.
