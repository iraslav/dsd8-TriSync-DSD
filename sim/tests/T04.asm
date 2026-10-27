; T04: LDI does not disturb the flags
LDI R0, 0x01
LDI R1, 0x01
SUB R2, R0, R1 ; sets Z=1, C=1, N=0, V=0
LDI R3, 0x55   ; LDI must not disturb flags
BEQ PASS
LDI R4, 0xEE   ; should be skipped
PASS: LDI R5, 0xAA
HLT
