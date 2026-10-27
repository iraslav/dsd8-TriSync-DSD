; =============================================================================
; DSD-8 Worked Example B.1: Multiply by repeated addition
; Multiplies R1 (13) by R2 (7), leaving product in R3 (91 = 0x5B)
; Displays product on LEDs (Port 0x02) and halts.
; =============================================================================

LDI R1, 13          ; multiplicand
LDI R2, 7           ; multiplier (counts down to zero)
LDI R3, 0           ; running product
LDI R4, 1           ; the constant 1 -- there is no "subtract immediate"
LOOP: LDI R5, 0
CMP R2, R5          ; has the multiplier reached zero?
BEQ DONE
ADD R3, R3, R1      ; product += multiplicand
SUB R2, R2, R4      ; multiplier -= 1
JMP LOOP
DONE: OUT 0x02, R3  ; show the product on the LEDs
HLT
