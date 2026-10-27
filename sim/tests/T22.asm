; T22: Arithmetic right shift constructed from available instructions
LDI R1, 0x84   ; negative number (-124)
SHR R2, R1     ; logical shift -> 0x42, C=0
LDI R3, 0x80   ; MSB mask
OR R2, R2, R3  ; sign extension -> 0xC2 (-62)
HLT
