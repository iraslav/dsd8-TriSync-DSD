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
