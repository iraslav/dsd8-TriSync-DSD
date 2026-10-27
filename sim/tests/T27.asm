; T27: Branches do not modify flags
LDI R0, 0x05
LDI R1, 0x05
CMP R0, R1 ; sets Z=1
BEQ T1
HLT
T1: BEQ T2 ; test Z=1 again; branch must not have cleared Z
HLT
T2: LDI R3, 0x77
HLT
