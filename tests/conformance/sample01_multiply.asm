; sample01_multiply.asm
; Worked example from the DSD-8 Project Specification, Appendix B.1.
; Multiplies R1 by R2 (by repeated addition), leaving the product in R3
; and writing it to the LEDs.
;
; Verified expected results (Appendix B.1):
;   R3 = 91 (13 x 7), LEDs = 0x5B, 51 instructions retired.

        LDI  R1, 13     ; multiplicand
        LDI  R2, 7      ; multiplier (counts down to zero)
        LDI  R3, 0      ; running product
        LDI  R4, 1      ; the constant 1 -- there is no "subtract immediate"
LOOP:   LDI  R5, 0
        CMP  R2, R5     ; has the multiplier reached zero?
        BEQ  DONE
        ADD  R3, R3, R1 ; product += multiplicand
        SUB  R2, R2, R4 ; multiplier -= 1
        JMP  LOOP
DONE:   OUT  0x02, R3   ; show the product on the LEDs
        HLT
