; T28: Unsigned ordering with BCS/BCC across 0x7F/0x80
LDI R0, 0x80
LDI R1, 0x7F
CMP R0, R1 ; 0x80 >= 0x7F unsigned -> C=1 (no borrow)
BCS PASS
LDI R2, 0xEE
HLT
PASS: LDI R2, 0x88
HLT
