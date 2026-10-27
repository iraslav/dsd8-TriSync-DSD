; =============================================================================
; DSD-8 Worked Example B.2: Population count
; Counts the number of set bits in R1 by shifting into the carry flag.
; Expected result: R2 = 6, 44 instructions retired.
; =============================================================================

LDI R1, 0xB7    ; 1011 0111 -- six bits set
LDI R2, 0       ; count
LDI R3, 8       ; bits remaining
LDI R4, 1
LOOP: SHR R1, R1 ; the old bit 0 lands in C
BCC SKIP        ; C = 0, so that bit was clear
ADD R2, R2, R4
SKIP: SUB R3, R3, R4
BNE LOOP        ; SUB set Z when the counter hit zero
OUT 0x02, R2
HLT
