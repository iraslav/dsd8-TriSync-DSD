; T33: I/O does not disturb data memory
LDI R0, 0x05
LDI R1, 0x33
ST [R0], R1 ; DMEM[5] = 0x33
OUT 0x02, R1 ; write LEDs
LD R2, [R0] ; must still be 0x33
HLT
