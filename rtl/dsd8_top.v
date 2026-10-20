// dsd8_top.v -- system top level
// Owner: shared (whole team integrates this together)
// Spec: Section 5.1. Port list is FROZEN -- do not rename or resize.

module dsd8_top (
    input  wire       clk,
    input  wire       rst_n,       // synchronous, active low
    input  wire [7:0] switches,    // board slide switches  -> port 0x00
    input  wire [4:0] buttons,     // {btnU,btnD,btnL,btnR,btnC} -> port 0x01
    output wire [7:0] leds,        // board LEDs             <- port 0x02
    output wire [6:0] seg,         // seven-segment segments <- port 0x10
    output wire [3:0] an,          // seven-segment digit enables
    output wire       halted       // asserted after HLT retires
);

    // TODO: instantiate dsd8_cpu, instr_memory and io_bus here and wire
    // them together. tb_dsd8.v does NOT instantiate this module -- it
    // instantiates dsd8_cpu directly (Section 8.3) -- so dsd8_top only
    // matters for board bring-up and the demonstration deliverable
    // (Section 9.3, item 5), not for conformance grading.

    assign leds   = 8'h00;
    assign seg    = 7'h7F;   // all segments off (assuming active-low segments)
    assign an     = 4'hF;    // all digits disabled
    assign halted = 1'b0;

endmodule
