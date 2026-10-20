// instr_memory.v -- 512 x 16 read-only memory, loaded by $readmemh
// Owner: member A
// Spec: Section 5.4. Port list is FROZEN.

module instr_memory #(
    parameter IMAGE = "program.hex"
) (
    input  wire       clk,
    input  wire [8:0] addr,
    output wire [15:0] data
);

    reg [15:0] mem [0:511];

    initial begin
        $readmemh(IMAGE, mem);
    end

    // Section 2.4 (R4): read-only, not writable by any instruction.
    // Combinational read keeps this simple; a registered read is also
    // acceptable as long as it is accounted for in your microarchitecture
    // (Section 4.3) and does not change how many cycles you claim.
    assign data = mem[addr];

    // verilator lint_off UNUSEDSIGNAL
    wire unused_clk = clk;
    // verilator lint_on UNUSEDSIGNAL

endmodule
