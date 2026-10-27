; T32: IN from unmapped port returns 0x00; OUT to one is harmless
IN R1, 0x99 ; unmapped port -> 0x00
LDI R2, 0xAA
OUT 0x99, R2 ; discarded
HLT
