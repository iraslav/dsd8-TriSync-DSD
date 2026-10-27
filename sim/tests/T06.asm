; T06: Writing a register then immediately reading it as source
LDI R1, 0x12
LDI R2, 0x34
ADD R3, R1, R2
ADD R4, R3, R1
HLT
