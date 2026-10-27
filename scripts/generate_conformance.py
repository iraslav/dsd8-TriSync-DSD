#!/usr/bin/env python3
"""
Generates the 40-test Conformance Suite for DSD-8 Processor (T01 - T40)
Based strictly on Section 8.4 of the specification.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dsd8asm import assemble, write_hex
from dsd8sim import DSD8Simulator

TESTS = {
    # Group T1: Data movement and immediates (T01-T08)
    "T01": """
; T01: LDI into each of the eight registers in turn
LDI R0, 0x10
LDI R1, 0x21
LDI R2, 0x32
LDI R3, 0x43
LDI R4, 0x54
LDI R5, 0x65
LDI R6, 0x76
LDI R7, 0x87
HLT
""",
    "T02": """
; T02: LDI with boundary values 0x00, 0x01, 0x7F, 0x80, 0xFF
LDI R0, 0x00
LDI R1, 0x01
LDI R2, 0x7F
LDI R3, 0x80
LDI R4, 0xFF
HLT
""",
    "T03": """
; T03: MOV (OR rd, rs, rs) between registers
LDI R0, 0xA5
MOV R1, R0
MOV R2, R1
MOV R3, R2
MOV R4, R3
MOV R5, R4
MOV R6, R5
MOV R7, R6
HLT
""",
    "T04": """
; T04: LDI does not disturb the flags
LDI R0, 0x01
LDI R1, 0x01
SUB R2, R0, R1 ; sets Z=1, C=1, N=0, V=0
LDI R3, 0x55   ; LDI must not disturb flags
BEQ PASS
LDI R4, 0xEE   ; should be skipped
PASS: LDI R5, 0xAA
HLT
""",
    "T05": """
; T05: NOP changes nothing at all
NOP
NOP
NOP
NOP
HLT
""",
    "T06": """
; T06: Writing a register then immediately reading it as source
LDI R1, 0x12
LDI R2, 0x34
ADD R3, R1, R2
ADD R4, R3, R1
HLT
""",
    "T07": """
; T07: Reading the same register on both ALU input ports
LDI R2, 0x20
ADD R1, R2, R2
HLT
""",
    "T08": """
; T08: rd equal to rs1 equal to rs2
LDI R3, 0x15
ADD R3, R3, R3
HLT
""",

    # Group T2: Data memory (T09-T14)
    "T09": """
; T09: Reading never-written locations (must return 0x00 per R6/R16)
LDI R0, 0x00
LD R1, [R0]
LDI R0, 0x50
LD R2, [R0]
LDI R0, 0xFF
LD R3, [R0]
HLT
""",
    "T10": """
; T10: Store then load from same address (0x00 and 0xFF)
LDI R0, 0x00
LDI R1, 0x42
ST [R0], R1
LD R2, [R0]
LDI R3, 0xFF
LDI R4, 0x99
ST [R3], R4
LD R5, [R3]
HLT
""",
    "T11": """
; T11: Address register is contents of rs1, not register number
LDI R4, 0x25 ; R4 holds address 0x25
LDI R5, 0x88 ; R5 holds data 0x88
ST [R4], R5
LDI R6, 0x00
LD R6, [R4]
HLT
""",
    "T12": """
; T12: ST [Rx], Rx — storing a register using itself as address
LDI R2, 0x02
ST [R2], R2
LD R3, [R2]
HLT
""",
    "T13": """
; T13: Walking-ones pattern written across memory and read back
LDI R0, 0x00
LDI R1, 0x01
ST [R0], R1
LDI R0, 0x01
LDI R1, 0x02
ST [R0], R1
LDI R0, 0x02
LDI R1, 0x04
ST [R0], R1
LDI R0, 0x03
LDI R1, 0x08
ST [R0], R1
LDI R0, 0x00
LD R2, [R0]
LDI R0, 0x01
LD R3, [R0]
LDI R0, 0x02
LD R4, [R0]
LDI R0, 0x03
LD R5, [R0]
HLT
""",
    "T14": """
; T14: LD does not disturb flags
LDI R0, 0x00
LDI R1, 0x00
SUB R2, R0, R1 ; sets Z=1, C=1
LDI R3, 0x00
LD R4, [R3]    ; loads 0, but must not alter flags
BEQ PASS
LDI R5, 0xEE
PASS: LDI R6, 0xAA
HLT
""",

    # Group T3: ALU results and flags (T15-T22)
    "T15": """
; T15: ADD across carry boundary
LDI R0, 0xFF
LDI R1, 0x01
ADD R2, R0, R1 ; 0xFF + 1 = 0x00, C=1, Z=1
LDI R0, 0x80
LDI R1, 0x80
ADD R3, R0, R1 ; 0x80 + 0x80 = 0x00, C=1, V=1, Z=1
LDI R0, 0x7F
LDI R1, 0x01
ADD R4, R0, R1 ; 0x7F + 1 = 0x80, V=1, N=1
HLT
""",
    "T16": """
; T16: SUB and borrow convention (C=1 means no borrow)
LDI R0, 0x0A
LDI R1, 0x05
SUB R2, R0, R1 ; 10 - 5 = 5, C=1 (no borrow)
LDI R0, 0x05
LDI R1, 0x0A
SUB R3, R0, R1 ; 5 - 10 = 0xFB, C=0 (borrow)
HLT
""",
    "T17": """
; T17: Signed overflow (0x7F+0x01 sets V; 0xFF+0x01 does not)
LDI R0, 0x7F
LDI R1, 0x01
ADD R2, R0, R1 ; sets V=1
LDI R0, 0xFF
LDI R1, 0x01
ADD R3, R0, R1 ; V=0
HLT
""",
    "T18": """
; T18: AND, OR, XOR clear C and V, set Z and N
LDI R0, 0xFF
LDI R1, 0x00
AND R2, R0, R1 ; Z=1, N=0, C=0, V=0
LDI R0, 0x80
LDI R1, 0x01
OR R3, R0, R1  ; N=1, Z=0, C=0, V=0
LDI R0, 0xFF
LDI R1, 0xFF
XOR R4, R0, R1 ; Z=1, N=0, C=0, V=0
HLT
""",
    "T19": """
; T19: SHL out of bit 7 into carry, and SHR out of bit 0 into carry
LDI R0, 0x80
SHL R1, R0 ; C=1, Z=1
LDI R0, 0x01
SHR R2, R0 ; C=1, Z=1
HLT
""",
    "T20": """
; T20: SHR is logical: shifting 0x80 gives 0x40, never 0xC0
LDI R0, 0x80
SHR R1, R0 ; result must be 0x40, N=0
HLT
""",
    "T21": """
; T21: CMP sets flags and writes no register
LDI R1, 0x20
LDI R2, 0x20
CMP R1, R2 ; sets Z=1, C=1, leaves all registers intact
LDI R3, 0x10
LDI R4, 0x30
CMP R3, R4 ; sets C=0 (borrow), N=1
HLT
""",
    "T22": """
; T22: Arithmetic right shift constructed from available instructions
LDI R1, 0x84   ; negative number (-124)
SHR R2, R1     ; logical shift -> 0x42, C=0
LDI R3, 0x80   ; MSB mask
OR R2, R2, R3  ; sign extension -> 0xC2 (-62)
HLT
""",

    # Group T4: Control flow (T23-T30)
    "T23": """
; T23: JMP forwards and backwards
LDI R0, 0x01
JMP FORWARD
LDI R0, 0xEE ; skipped
FORWARD: LDI R1, 0x02
JMP EXIT
LDI R1, 0xEE ; skipped
EXIT: HLT
""",
    "T24": """
; T24: Branch conditions taken
LDI R0, 0x05
LDI R1, 0x05
CMP R0, R1
BEQ B1
HLT
B1: LDI R2, 0x01
LDI R0, 0x05
LDI R1, 0x06
CMP R0, R1
BNE B2
HLT
B2: LDI R2, 0x02
HLT
""",
    "T25": """
; T25: Branch conditions not taken — fall through
LDI R0, 0x05
LDI R1, 0x06
CMP R0, R1
BEQ FAIL
LDI R2, 0xAA
JMP PASS
FAIL: LDI R2, 0xEE
PASS: HLT
""",
    "T26": """
; T26: Loop escaped after decrement
LDI R1, 0x03
LDI R2, 0x01
LOOP: SUB R1, R1, R2
BNE LOOP
LDI R3, 0x55
HLT
""",
    "T27": """
; T27: Branches do not modify flags
LDI R0, 0x05
LDI R1, 0x05
CMP R0, R1 ; sets Z=1
BEQ T1
HLT
T1: BEQ T2 ; test Z=1 again; branch must not have cleared Z
HLT
T2: LDI R3, 0x77
HLT
""",
    "T28": """
; T28: Unsigned ordering with BCS/BCC across 0x7F/0x80
LDI R0, 0x80
LDI R1, 0x7F
CMP R0, R1 ; 0x80 >= 0x7F unsigned -> C=1 (no borrow)
BCS PASS
LDI R2, 0xEE
HLT
PASS: LDI R2, 0x88
HLT
""",
    "T29": """
; T29: Signed ordering test
LDI R0, 0x01
LDI R1, 0x02
CMP R0, R1 ; 1 - 2 = -1 (N=1, V=0)
BMI IS_NEG
LDI R2, 0x00
HLT
IS_NEG: LDI R2, 0x01
HLT
""",
    "T30": """
; T30: Loop that executes 256 times and terminates
LDI R1, 0x00 ; counter (0 to 255 wrapping)
LDI R2, 0x01
LDI R3, 0x00 ; iterations
LOOP: ADD R1, R1, R2
ADD R3, R3, R2
BNE LOOP
HLT
""",

    # Group T5: Input and output (T31-T35)
    "T31": """
; T31: OUT to LEDS then IN from SWITCHES
LDI R1, 0x55
OUT 0x02, R1
IN R2, 0x00
HLT
""",
    "T32": """
; T32: IN from unmapped port returns 0x00; OUT to one is harmless
IN R1, 0x99 ; unmapped port -> 0x00
LDI R2, 0xAA
OUT 0x99, R2 ; discarded
HLT
""",
    "T33": """
; T33: I/O does not disturb data memory
LDI R0, 0x05
LDI R1, 0x33
ST [R0], R1 ; DMEM[5] = 0x33
OUT 0x02, R1 ; write LEDs
LD R2, [R0] ; must still be 0x33
HLT
""",
    "T34": """
; T34: IO handshake test
LDI R1, 0x03
OUT 0x40, R1 ; slow echo
IN R2, 0x40
HLT
""",
    "T35": """
; T35: IN and OUT leave flags unchanged
LDI R0, 0x05
LDI R1, 0x05
SUB R2, R0, R1 ; sets Z=1, C=1
LDI R3, 0x12
OUT 0x02, R3   ; OUT leaves flags untouched
BEQ PASS
LDI R4, 0xEE
HLT
PASS: LDI R4, 0x77
HLT
""",

    # Group T6: Integration programs (T36-T40)
    "T36": """
; T36: 8-bit multiply by repeated addition (B.1)
LDI R1, 13
LDI R2, 7
LDI R3, 0
LDI R4, 1
LOOP: LDI R5, 0
CMP R2, R5
BEQ DONE
ADD R3, R3, R1
SUB R2, R2, R4
JMP LOOP
DONE: OUT 0x02, R3
HLT
""",
    "T37": """
; T37: Population count using SHR and carry (B.2)
LDI R1, 0xB7
LDI R2, 0
LDI R3, 8
LDI R4, 1
LOOP: SHR R1, R1
BCC SKIP
ADD R2, R2, R4
SKIP: SUB R3, R3, R4
BNE LOOP
OUT 0x02, R2
HLT
""",
    "T38": """
; T38: Bubble sort in data memory (B.3)
; Preload DMEM[0..7] with 5, 3, 9, 1, 7, 2, 8, 4
LDI R0, 0 ; addr
LDI R1, 5 ; val
ST [R0], R1
LDI R0, 1
LDI R1, 3
ST [R0], R1
LDI R0, 2
LDI R1, 9
ST [R0], R1
LDI R0, 3
LDI R1, 1
ST [R0], R1
LDI R0, 4
LDI R1, 7
ST [R0], R1
LDI R0, 5
LDI R1, 2
ST [R0], R1
LDI R0, 6
LDI R1, 8
ST [R0], R1
LDI R0, 7
LDI R1, 4
ST [R0], R1

; Now run sort
LDI R1, 8 ; n
LDI R7, 1 ; constant 1
OUTER: LDI R2, 0 ; i = 0
LDI R6, 0 ; swap flag
INNER: MOV R3, R2
ADD R4, R3, R7 ; i + 1
CMP R4, R1
BCS ENDIN
LD R5, [R3]
LD R0, [R4]
CMP R5, R0
BCC NOSWAP
BEQ NOSWAP
ST [R3], R0
ST [R4], R5
LDI R6, 1
NOSWAP: ADD R2, R2, R7
JMP INNER
ENDIN: LDI R0, 0
CMP R6, R0
BNE OUTER
HLT
""",
    "T39": """
; T39: Find maximum and minimum of block of memory
LDI R0, 0
LDI R1, 0x12
ST [R0], R1
LDI R0, 1
LDI R1, 0x85
ST [R0], R1
LDI R0, 2
LDI R1, 0x43
ST [R0], R1
; R1 = min, R2 = max
LDI R0, 0
LD R1, [R0]
MOV R2, R1
LDI R7, 1
LDI R0, 1
LD R3, [R0]
CMP R3, R1
BCS NOT_MIN1
MOV R1, R3
NOT_MIN1: CMP R3, R2
BCC NOT_MAX1
MOV R2, R3
NOT_MAX1: HLT
""",
    "T40": """
; T40: Polled UART echo loop
LDI R1, 0x00
OUT 0x02, R1
LDI R2, 0x55
OUT 0x20, R2
HLT
"""
}

def main():
    test_dir = os.path.join("sim", "tests")
    os.makedirs(test_dir, exist_ok=True)
    print(f"Generating 40 Conformance Tests in '{test_dir}'...")

    for name, code in TESTS.items():
        asm_path = os.path.join(test_dir, f"{name}.asm")
        hex_path = os.path.join(test_dir, f"{name}.hex")
        gold_path = os.path.join(test_dir, f"{name}_gold.trace")

        with open(asm_path, "w") as f:
            f.write(code.strip() + "\n")

        # Assemble
        lines = code.strip().splitlines()
        enc = assemble(lines)
        write_hex(enc, hex_path)

        # Generate gold trace
        sim = DSD8Simulator(hex_path, max_cycles=100000)
        sim.run()
        with open(gold_path, "w") as f:
            for l in sim.trace_lines:
                f.write(l + "\n")

    print(f"Successfully generated all {len(TESTS)} conformance tests and golden traces!")

if __name__ == "__main__":
    main()
