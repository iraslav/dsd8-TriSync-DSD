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
