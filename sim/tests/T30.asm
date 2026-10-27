; T30: Loop that executes 256 times and terminates
LDI R1, 0x00 ; counter (0 to 255 wrapping)
LDI R2, 0x01
LDI R3, 0x00 ; iterations
LOOP: ADD R1, R1, R2
ADD R3, R3, R2
BNE LOOP
HLT
