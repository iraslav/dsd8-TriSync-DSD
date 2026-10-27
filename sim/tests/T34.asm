; T34: IO handshake test
LDI R1, 0x03
OUT 0x40, R1 ; slow echo
IN R2, 0x40
HLT
