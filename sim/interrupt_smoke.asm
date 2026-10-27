; End-to-end smoke test for dsd8_interrupt_top.
; Timer A raises an IRQ; the CPU polls, updates LEDs, clears the flag, and halts.

LDI R1, 3
OUT 0x52, R1
LDI R2, 0
OUT 0x53, R2
LDI R3, 1
OUT 0x5A, R3
OUT 0x5C, R3

WAIT:
IN R4, 0x58
LDI R5, 0x10
AND R6, R4, R5
BEQ WAIT

LDI R7, 0xA5
OUT 0x02, R7
LDI R0, 1
OUT 0x59, R0
HLT
