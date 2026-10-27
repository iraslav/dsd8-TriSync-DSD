; T20: SHR is logical: shifting 0x80 gives 0x40, never 0xC0
LDI R0, 0x80
SHR R1, R0 ; result must be 0x40, N=0
HLT
