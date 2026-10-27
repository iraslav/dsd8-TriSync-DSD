// =============================================================================
// Constrained-Random ALU Testbench: tb_alu_random
// Satisfies Requirements R24 and R25:
//   - Tests 10,000+ random and corner-case operand pairs against reference
//   - Covers all 8 ALU operations: ADD, SUB, AND, OR, XOR, SHL, SHR, CMP
//   - Proves corner cases 0x00, 0x01, 0x7F, 0x80, 0xFF occur as both operands
//   - Reports functional coverage evidence at test completion
// =============================================================================

`timescale 1ns/1ps

module tb_alu_random;

    reg  [7:0] a, b;
    reg  [3:0] op;
    wire [7:0] result;
    wire       flag_z, flag_n, flag_c, flag_v;

    alu dut (
        .a(a), .b(b), .op(op),
        .result(result),
        .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v)
    );

    // Behavioural Reference Model for ALU
    reg [7:0] exp_res;
    reg       exp_z, exp_n, exp_c, exp_v;

    task model_alu(input [7:0] in_a, input [7:0] in_b, input [3:0] in_op);
        reg [8:0] sum9;
        begin
            case (in_op)
                4'h4: begin // ADD
                    sum9 = in_a + in_b;
                    exp_res = sum9[7:0];
                    exp_c   = sum9[8];
                    exp_v   = (in_a[7] == in_b[7]) && (sum9[7] != in_a[7]);
                end
                4'h5, 4'hB: begin // SUB, CMP
                    sum9 = in_a - in_b;
                    exp_res = sum9[7:0];
                    exp_c   = (in_a >= in_b); // C=1 means no borrow
                    exp_v   = (in_a[7] != in_b[7]) && (sum9[7] != in_a[7]);
                end
                4'h6: begin // AND
                    exp_res = in_a & in_b;
                    exp_c   = 0;
                    exp_v   = 0;
                end
                4'h7: begin // OR
                    exp_res = in_a | in_b;
                    exp_c   = 0;
                    exp_v   = 0;
                end
                4'h8: begin // XOR
                    exp_res = in_a ^ in_b;
                    exp_c   = 0;
                    exp_v   = 0;
                end
                4'h9: begin // SHL
                    exp_res = {in_a[6:0], 1'b0};
                    exp_c   = in_a[7];
                    exp_v   = 0;
                end
                4'hA: begin // SHR
                    exp_res = {1'b0, in_a[7:1]};
                    exp_c   = in_a[0];
                    exp_v   = 0;
                end
                default: begin
                    exp_res = 8'h00;
                    exp_c   = 0;
                    exp_v   = 0;
                end
            endcase
            exp_z = (exp_res == 8'h00);
            exp_n = exp_res[7];
        end
    endtask

    // Coverage bins for Requirement R25: 0x00, 0x01, 0x7F, 0x80, 0xFF
    integer cov_a_00 = 0, cov_a_01 = 0, cov_a_7F = 0, cov_a_80 = 0, cov_a_FF = 0;
    integer cov_b_00 = 0, cov_b_01 = 0, cov_b_7F = 0, cov_b_80 = 0, cov_b_FF = 0;
    integer op_counts [4:11];

    integer i, k;
    integer errors = 0;
    reg [7:0] corner_cases [0:4];
    reg [3:0] op_list [0:7];

    initial begin
        corner_cases[0] = 8'h00;
        corner_cases[1] = 8'h01;
        corner_cases[2] = 8'h7F;
        corner_cases[3] = 8'h80;
        corner_cases[4] = 8'hFF;

        op_list[0] = 4'h4; // ADD
        op_list[1] = 4'h5; // SUB
        op_list[2] = 4'h6; // AND
        op_list[3] = 4'h7; // OR
        op_list[4] = 4'h8; // XOR
        op_list[5] = 4'h9; // SHL
        op_list[6] = 4'hA; // SHR
        op_list[7] = 4'hB; // CMP

        for (k = 4; k <= 11; k = k + 1)
            op_counts[k] = 0;

        // 1. First run systematic corner-case matrix (5 x 5 x 8 = 200 combinations)
        for (k = 0; k < 8; k = k + 1) begin
            op = op_list[k];
            for (i = 0; i < 5; i = i + 1) begin
                for (integer j = 0; j < 5; j = j + 1) begin
                    a = corner_cases[i];
                    b = corner_cases[j];
                    #1;
                    model_alu(a, b, op);
                    if (result !== exp_res || flag_z !== exp_z || flag_n !== exp_n ||
                        flag_c !== exp_c || flag_v !== exp_v) begin
                        $display("FAIL in corner matrix! op=%X, a=%02X, b=%02X", op, a, b);
                        errors = errors + 1;
                    end
                end
            end
        end

        // 2. Run 10,000+ constrained-random test vectors
        for (i = 0; i < 12000; i = i + 1) begin
            // 20% of the time pick a corner case, 80% uniform random
            if ($random % 5 == 0)
                a = corner_cases[$random % 5];
            else
                a = $random & 8'hFF;

            if ($random % 5 == 0)
                b = corner_cases[$random % 5];
            else
                b = $random & 8'hFF;

            op = op_list[$random % 8];

            // Update coverage counters
            if (a == 8'h00) cov_a_00 = cov_a_00 + 1;
            if (a == 8'h01) cov_a_01 = cov_a_01 + 1;
            if (a == 8'h7F) cov_a_7F = cov_a_7F + 1;
            if (a == 8'h80) cov_a_80 = cov_a_80 + 1;
            if (a == 8'hFF) cov_a_FF = cov_a_FF + 1;

            if (b == 8'h00) cov_b_00 = cov_b_00 + 1;
            if (b == 8'h01) cov_b_01 = cov_b_01 + 1;
            if (b == 8'h7F) cov_b_7F = cov_b_7F + 1;
            if (b == 8'h80) cov_b_80 = cov_b_80 + 1;
            if (b == 8'hFF) cov_b_FF = cov_b_FF + 1;

            op_counts[op] = op_counts[op] + 1;

            #1;
            model_alu(a, b, op);
            if (result !== exp_res || flag_z !== exp_z || flag_n !== exp_n ||
                flag_c !== exp_c || flag_v !== exp_v) begin
                $display("FAIL random test #%0d! op=%X a=%02X b=%02X", i, op, a, b);
                errors = errors + 1;
            end
        end

        // Coverage Evidence Report per Requirement R25
        $display("=================================================================");
        $display("           ALU RANDOM VERIFICATION & COVERAGE REPORT             ");
        $display("=================================================================");
        $display("Total vectors simulated: %0d", 12000 + 200);
        $display("Mismatches found       : %0d", errors);
        $display("-----------------------------------------------------------------");
        $display("Opcode Coverage:");
        $display("  ADD (0x4): %0d hits", op_counts[4]);
        $display("  SUB (0x5): %0d hits", op_counts[5]);
        $display("  AND (0x6): %0d hits", op_counts[6]);
        $display("  OR  (0x7): %0d hits", op_counts[7]);
        $display("  XOR (0x8): %0d hits", op_counts[8]);
        $display("  SHL (0x9): %0d hits", op_counts[9]);
        $display("  SHR (0xA): %0d hits", op_counts[10]);
        $display("  CMP (0xB): %0d hits", op_counts[11]);
        $display("-----------------------------------------------------------------");
        $display("Corner-case Coverage Evidence (R25):");
        $display("  Operand A [0x00]: %0d hits", cov_a_00);
        $display("  Operand A [0x01]: %0d hits", cov_a_01);
        $display("  Operand A [0x7F]: %0d hits", cov_a_7F);
        $display("  Operand A [0x80]: %0d hits", cov_a_80);
        $display("  Operand A [0xFF]: %0d hits", cov_a_FF);
        $display("  Operand B [0x00]: %0d hits", cov_b_00);
        $display("  Operand B [0x01]: %0d hits", cov_b_01);
        $display("  Operand B [0x7F]: %0d hits", cov_b_7F);
        $display("  Operand B [0x80]: %0d hits", cov_b_80);
        $display("  Operand B [0xFF]: %0d hits", cov_b_FF);
        $display("=================================================================");

        if (errors == 0 && cov_a_00 > 0 && cov_a_01 > 0 && cov_a_7F > 0 &&
            cov_a_80 > 0 && cov_a_FF > 0 && cov_b_00 > 0 && cov_b_01 > 0 &&
            cov_b_7F > 0 && cov_b_80 > 0 && cov_b_FF > 0) begin
            $display("STATUS: PASS (All 12,200 vectors verified, 100%% corner coverage achieved)");
        end else begin
            $display("STATUS: FAIL");
        end

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
