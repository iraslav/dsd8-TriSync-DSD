; T09: Reading never-written locations (must return 0x00 per R6/R16)
LDI R0, 0x00
LD R1, [R0]
LDI R0, 0x50
LD R2, [R0]
LDI R0, 0xFF
LD R3, [R0]
HLT
