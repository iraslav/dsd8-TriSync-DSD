; ===========================================================================
; Worked Example B.3 (DSD-8 Specification v1.0):
; Bubble sort of eight bytes in data memory, ascending order.
;   Input : DMEM[0x00..0x07] = 5 3 9 1 7 2 8 4
;   Output: DMEM[0x00..0x07] = 1 2 3 4 5 7 8 9
; The init block stores the unsorted data with ST/LDI pairs so the program
; is self-contained (the ISA has no "store immediate" instruction).
; ===========================================================================

; ---- initialization: DMEM[0x00..0x07] = 5 3 9 1 7 2 8 4 ----
    LDI R1, 0x00
    LDI R5, 5
    ST  [R1], R5
    LDI R1, 0x01
    LDI R5, 3
    ST  [R1], R5
    LDI R1, 0x02
    LDI R5, 9
    ST  [R1], R5
    LDI R1, 0x03
    LDI R5, 1
    ST  [R1], R5
    LDI R1, 0x04
    LDI R5, 7
    ST  [R1], R5
    LDI R1, 0x05
    LDI R5, 2
    ST  [R1], R5
    LDI R1, 0x06
    LDI R5, 8
    ST  [R1], R5
    LDI R1, 0x07
    LDI R5, 4
    ST  [R1], R5

; ---- B.3 body: bubble sort ----
    LDI R1, 8          ; n
    LDI R7, 1          ; the constant 1
OUTER:
    LDI R2, 0          ; i = 0
    LDI R6, 0          ; "a swap happened" flag
INNER:
    MOV R3, R2         ; assembles to OR R3, R2, R2
    ADD R4, R3, R7     ; R4 = i + 1
    CMP R4, R1
    BCS ENDIN          ; i+1 >= n, so this pass is finished
    LD  R5, [R3]       ; a[i]
    LD  R0, [R4]       ; a[i+1]
    CMP R5, R0
    BCC NOSWAP         ; a[i] < a[i+1], already in order
    BEQ NOSWAP         ; equal, nothing to do
    ST  [R3], R0       ; swap them
    ST  [R4], R5
    LDI R6, 1
NOSWAP:
    ADD R2, R2, R7
    JMP INNER
ENDIN:
    LDI R0, 0
    CMP R6, R0
    BNE OUTER          ; repeat while any swap occurred
    HLT
