; T23: JMP forwards and backwards
LDI R0, 0x01
JMP FORWARD
LDI R0, 0xEE ; skipped
FORWARD: LDI R1, 0x02
JMP EXIT
LDI R1, 0xEE ; skipped
EXIT: HLT
