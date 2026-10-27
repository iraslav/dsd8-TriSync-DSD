; T17: Signed overflow (0x7F+0x01 sets V; 0xFF+0x01 does not)
LDI R0, 0x7F
LDI R1, 0x01
ADD R2, R0, R1 ; sets V=1
LDI R0, 0xFF
LDI R1, 0x01
ADD R3, R0, R1 ; V=0
HLT
