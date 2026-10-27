// =============================================================================
// Module: flags_reg
// Owner:  Member B
// Description: Architectural Z, N, C, V flag register.
//              Updated only when flags_we is asserted (for the 8 flag-setting
//              instructions: ADD, SUB, AND, OR, XOR, SHL, SHR, CMP).
//              All flags cleared to 0 on reset.
// =============================================================================

module flags_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flags_we,    // only for the eight flag-setting instructions
    input  wire [3:0]  flags_in,    // {z,n,c,v} from the ALU
    output reg  [3:0]  flags_out    // {Z,N,C,V} architectural state
);

    always @(posedge clk) begin
        if (!rst_n) begin
            flags_out <= 4'b0000;
        end else if (flags_we) begin
            flags_out <= flags_in;
        end
    end

endmodule
