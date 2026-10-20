// flags_reg.v -- the architectural Z, N, C, V registers
// Owner: member B -- this is YOUR module; you are individually examined
// on it at the oral defence.
// Spec: Section 5.8. Port list is FROZEN. Updated only by the eight
// flag-setting instructions (Section 2.3.3): ADD, SUB, AND, OR, XOR,
// SHL, SHR, CMP. Every other instruction -- including LD -- leaves all
// four flags unchanged (that is a deliberate design decision in the
// spec, not an oversight; see the "LD does not set flags" callout).

module flags_reg (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       flags_we,     // only for the eight flag-setting instructions
    input  wire [3:0] flags_in,     // {Z,N,C,V} from the ALU
    output reg  [3:0] flags_out     // {Z,N,C,V} architectural state
);

    // Reset state: Z = N = C = V = 0 (Section 2.5, R6) -- already correct below.
    always @(posedge clk) begin
        if (!rst_n) begin
            flags_out <= 4'b0000;
        end else begin
            // TODO: if (flags_we) flags_out <= flags_in;
            flags_out <= flags_out;
        end
    end

endmodule
