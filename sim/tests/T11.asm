; T11: Address register is contents of rs1, not register number
LDI R4, 0x25 ; R4 holds address 0x25
LDI R5, 0x88 ; R5 holds data 0x88
ST [R4], R5
LDI R6, 0x00
LD R6, [R4]
HLT
