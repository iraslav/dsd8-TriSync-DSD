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
