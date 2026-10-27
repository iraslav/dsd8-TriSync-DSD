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
