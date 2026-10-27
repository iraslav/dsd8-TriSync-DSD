; T26: Loop escaped after decrement
LDI R1, 0x03
LDI R2, 0x01
LOOP: SUB R1, R1, R2
BNE LOOP
LDI R3, 0x55
HLT
