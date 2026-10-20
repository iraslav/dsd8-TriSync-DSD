// alu.v -- arithmetic, logic, shifts, and the four flag outputs
// Owner: member B -- this is YOUR module; you are individually examined
// on it at the oral defence, and it is the one Section 8.5 (R24-R25)
// requires a constrained-random self-checking testbench for.
// Spec: Section 5.7 and Section 2.3. Purely combinational. Port list
// is FROZEN. `op` is the instruction opcode directly (R15) -- no
// separate ALU-control encoding needed.
//
// This file intentionally does NOT implement the truth table for you
// -- Section 2.3 already gives you the exact carry, overflow and flag
// definitions; writing the RTL from that table (and then proving it
// correct with your own random test) is the actual exercise. See
// tools/dsd8sim.py if you want a second, independent statement of the
// same semantics in Python to cross-check your own reading of the spec
// against -- but write this module yourself.

module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [3:0] op,     // instruction opcode: 0x4 ADD .. 0xB CMP
    output wire [7:0] result,
    output wire       flag_z,
    output wire       flag_n,
    output wire       flag_c,
    output wire       flag_v
);

    // TODO: implement Section 2.3's operation and flag tables for
    // ADD, SUB, AND, OR, XOR, SHL, SHR and CMP.
    assign result = 8'h00;
    assign flag_z = 1'b0;
    assign flag_n = 1'b0;
    assign flag_c = 1'b0;
    assign flag_v = 1'b0;

    // verilator lint_off UNUSEDSIGNAL
    wire [7:0] unused_a = a;
    wire [7:0] unused_b = b;
    wire [3:0] unused_op = op;
    // verilator lint_on UNUSEDSIGNAL

endmodule
