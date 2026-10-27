; T16: SUB and borrow convention (C=1 means no borrow)
LDI R0, 0x0A
LDI R1, 0x05
SUB R2, R0, R1 ; 10 - 5 = 5, C=1 (no borrow)
LDI R0, 0x05
LDI R1, 0x0A
SUB R3, R0, R1 ; 5 - 10 = 0xFB, C=0 (borrow)
HLT
