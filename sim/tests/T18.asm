; T18: AND, OR, XOR clear C and V, set Z and N
LDI R0, 0xFF
LDI R1, 0x00
AND R2, R0, R1 ; Z=1, N=0, C=0, V=0
LDI R0, 0x80
LDI R1, 0x01
OR R3, R0, R1  ; N=1, Z=0, C=0, V=0
LDI R0, 0xFF
LDI R1, 0xFF
XOR R4, R0, R1 ; Z=1, N=0, C=0, V=0
HLT
