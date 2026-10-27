// =============================================================================
// Module: alu
// Owner:  Member B
// Description: Purely combinational 8-bit ALU.
//              Uses a SINGLE 9-bit adder for ADD, SUB, and CMP (Requirement R15).
//              Computes all four flags: Z, N, C, V.
//              op input uses the instruction opcode directly.
//
// Opcode map:
//   0x4 = ADD    0x5 = SUB    0x6 = AND    0x7 = OR
//   0x8 = XOR    0x9 = SHL    0xA = SHR    0xB = CMP (flags only)
// =============================================================================

module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [3:0] op,       // instruction opcode directly
    output wire [7:0] result,
    output wire       flag_z,
    output wire       flag_n,
    output wire       flag_c,
    output wire       flag_v
);

    // Single 9-bit adder for ADD, SUB, and CMP (Requirement R15)
    wire       is_sub = (op == 4'h5 || op == 4'hB);
    wire [7:0] b_mux  = is_sub ? ~b : b;
    wire [8:0] adder_sum = {1'b0, a} + {1'b0, b_mux} + {8'b0, is_sub};

    reg [7:0] alu_result;
    reg       carry_out;
    reg       overflow;

    always @(*) begin
        alu_result = 8'h00;
        carry_out  = 1'b0;
        overflow   = 1'b0;

        case (op)
            4'h4: begin // ADD
                alu_result = adder_sum[7:0];
                carry_out  = adder_sum[8];
                // V = (a[7] == b[7]) && (result[7] != a[7])
                overflow   = (a[7] == b[7]) && (adder_sum[7] != a[7]);
            end

            4'h5, 4'hB: begin // SUB, CMP
                alu_result = adder_sum[7:0];
                carry_out  = adder_sum[8]; // C=1 means no borrow (a >= b)
                // V = (a[7] != b[7]) && (result[7] != a[7])
                overflow   = (a[7] != b[7]) && (adder_sum[7] != a[7]);
            end

            4'h6: begin // AND
                alu_result = a & b;
                carry_out  = 1'b0;
                overflow   = 1'b0;
            end

            4'h7: begin // OR
                alu_result = a | b;
                carry_out  = 1'b0;
                overflow   = 1'b0;
            end

            4'h8: begin // XOR
                alu_result = a ^ b;
                carry_out  = 1'b0;
                overflow   = 1'b0;
            end

            4'h9: begin // SHL: shift left, MSB into carry, zero into bit 0
                alu_result = {a[6:0], 1'b0};
                carry_out  = a[7];
                overflow   = 1'b0;
            end

            4'hA: begin // SHR: logical shift right, zero into bit 7, LSB into carry
                alu_result = {1'b0, a[7:1]};
                carry_out  = a[0];
                overflow   = 1'b0;
            end

            default: begin
                alu_result = 8'h00;
                carry_out  = 1'b0;
                overflow   = 1'b0;
            end
        endcase
    end

    assign result = alu_result;
    assign flag_z = (alu_result == 8'h00);
    assign flag_n = alu_result[7];
    assign flag_c = carry_out;
    assign flag_v = overflow;

endmodule
