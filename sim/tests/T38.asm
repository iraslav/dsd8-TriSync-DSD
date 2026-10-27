; T38: Bubble sort in data memory (B.3)
; Preload DMEM[0..7] with 5, 3, 9, 1, 7, 2, 8, 4
LDI R0, 0 ; addr
LDI R1, 5 ; val
ST [R0], R1
LDI R0, 1
LDI R1, 3
ST [R0], R1
LDI R0, 2
LDI R1, 9
ST [R0], R1
LDI R0, 3
LDI R1, 1
ST [R0], R1
LDI R0, 4
LDI R1, 7
ST [R0], R1
LDI R0, 5
LDI R1, 2
ST [R0], R1
LDI R0, 6
LDI R1, 8
ST [R0], R1
LDI R0, 7
LDI R1, 4
ST [R0], R1

; Now run sort
LDI R1, 8 ; n
LDI R7, 1 ; constant 1
OUTER: LDI R2, 0 ; i = 0
LDI R6, 0 ; swap flag
INNER: MOV R3, R2
ADD R4, R3, R7 ; i + 1
CMP R4, R1
BCS ENDIN
LD R5, [R3]
LD R0, [R4]
CMP R5, R0
BCC NOSWAP
BEQ NOSWAP
ST [R3], R0
ST [R4], R5
LDI R6, 1
NOSWAP: ADD R2, R2, R7
JMP INNER
ENDIN: LDI R0, 0
CMP R6, R0
BNE OUTER
HLT
