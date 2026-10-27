; T29: Signed ordering test
LDI R0, 0x01
LDI R1, 0x02
CMP R0, R1 ; 1 - 2 = -1 (N=1, V=0)
BMI IS_NEG
LDI R2, 0x00
HLT
IS_NEG: LDI R2, 0x01
HLT
