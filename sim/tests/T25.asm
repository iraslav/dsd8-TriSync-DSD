; T25: Branch conditions not taken — fall through
LDI R0, 0x05
LDI R1, 0x06
CMP R0, R1
BEQ FAIL
LDI R2, 0xAA
JMP PASS
FAIL: LDI R2, 0xEE
PASS: HLT
