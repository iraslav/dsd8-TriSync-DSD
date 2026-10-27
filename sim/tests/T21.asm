; T21: CMP sets flags and writes no register
LDI R1, 0x20
LDI R2, 0x20
CMP R1, R2 ; sets Z=1, C=1, leaves all registers intact
LDI R3, 0x10
LDI R4, 0x30
CMP R3, R4 ; sets C=0 (borrow), N=1
HLT
