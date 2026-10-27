; T19: SHL out of bit 7 into carry, and SHR out of bit 0 into carry
LDI R0, 0x80
SHL R1, R0 ; C=1, Z=1
LDI R0, 0x01
SHR R2, R0 ; C=1, Z=1
HLT
