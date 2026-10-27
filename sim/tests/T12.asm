; T12: ST [Rx], Rx — storing a register using itself as address
LDI R2, 0x02
ST [R2], R2
LD R3, [R2]
HLT
