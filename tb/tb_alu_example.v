// tb_alu_example.v -- a WORKED EXAMPLE of a self-checking unit
// testbench, for the pattern Section 8.5 (R24) requires of every
// module, not just the ALU.
//
// This testbench will FAIL against the placeholder alu.v in this
// template -- that is expected and correct: it means the harness is
// doing its job. It stops failing once you implement alu.v for real.
//
// What makes a testbench "self-checking": it computes the expected
// result *independently* of the DUT (the `expected_*` functions below
// are a second, independent statement of Section 2.3's truth table --
// compare them against tools/dsd8sim.py's Python version, which is a
// third), applies a set of directed vectors, and reports a single
// PASS/FAIL verdict a script can act on without a human reading
// waveforms. scripts/run_unit_tests.py looks for the exact strings
// "TESTBENCH: PASS" or "TESTBENCH: FAIL" on stdout -- keep that
// convention in every unit testbench you write for the other modules.
//
// This is a small DIRECTED test (one vector per opcode, plus the
// documented corner-case operands 0x00/0x01/0x7F/0x80/0xFF). It does
// NOT satisfy R24's "at least 10,000 random operand pairs" requirement
// by itself -- extend it (or write a second testbench) with a
// constrained-random loop before you rely on it for your verification
// report.

`timescale 1ns/1ps

module tb_alu_example;

    reg  [7:0] a, b;
    reg  [3:0] op;
    wire [7:0] result;
    wire       flag_z, flag_n, flag_c, flag_v;

    integer errors;
    integer i;

    alu dut (
        .a(a), .b(b), .op(op),
        .result(result),
        .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v)
    );

    // ---- independent reference model (Section 2.3) ----
    function [7:0] expected_result;
        input [7:0] fa, fb;
        input [3:0] fop;
        reg [8:0] add9, sub9;
        begin
            add9 = {1'b0, fa} + {1'b0, fb};
            sub9 = {1'b0, fa} + {1'b0, ~fb} + 9'h001;
            case (fop)
                4'h4: expected_result = add9[7:0];
                4'h5: expected_result = sub9[7:0];
                4'h6: expected_result = fa & fb;
                4'h7: expected_result = fa | fb;
                4'h8: expected_result = fa ^ fb;
                4'h9: expected_result = {fa[6:0], 1'b0};
                4'hA: expected_result = {1'b0, fa[7:1]};
                4'hB: expected_result = sub9[7:0];   // CMP: same arithmetic, caller discards it
                default: expected_result = 8'h00;
            endcase
        end
    endfunction

    function expected_carry;
        input [7:0] fa, fb;
        input [3:0] fop;
        reg [8:0] add9, sub9;
        begin
            add9 = {1'b0, fa} + {1'b0, fb};
            sub9 = {1'b0, fa} + {1'b0, ~fb} + 9'h001;
            case (fop)
                4'h4: expected_carry = add9[8];
                4'h5, 4'hB: expected_carry = sub9[8];   // C=1 means NO borrow
                4'h9: expected_carry = fa[7];
                4'hA: expected_carry = fa[0];
                default: expected_carry = 1'b0;         // AND/OR/XOR clear C
            endcase
        end
    endfunction

    function expected_overflow;
        input [7:0] fa, fb;
        input [3:0] fop;
        reg result7, a7;
        begin
            a7 = fa[7];
            result7 = expected_result(fa, fb, fop)[7];
            case (fop)
                4'h4:    expected_overflow = (fa[7] == fb[7]) && (result7 != a7);
                4'h5, 4'hB: expected_overflow = (fa[7] != fb[7]) && (result7 != a7);
                default: expected_overflow = 1'b0;
            endcase
        end
    endfunction

    task check(input [7:0] ta, input [7:0] tb, input [3:0] top, input [127:0] label);
        reg [7:0] exp_result;
        reg       exp_z, exp_n, exp_c, exp_v;
        begin
            a = ta; b = tb; op = top;
            #1;
            exp_result = expected_result(ta, tb, top);
            exp_z = (exp_result == 8'h00);
            exp_n = exp_result[7];
            exp_c = expected_carry(ta, tb, top);
            exp_v = expected_overflow(ta, tb, top);

            if (result !== exp_result || flag_z !== exp_z || flag_n !== exp_n
                    || flag_c !== exp_c || flag_v !== exp_v) begin
                errors = errors + 1;
                $display("  MISMATCH (%0s): a=%02h b=%02h op=%0h -> got result=%02h z=%b n=%b c=%b v=%b, expected result=%02h z=%b n=%b c=%b v=%b",
                          label, ta, tb, top, result, flag_z, flag_n, flag_c, flag_v,
                          exp_result, exp_z, exp_n, exp_c, exp_v);
            end
        end
    endtask

    initial begin
        errors = 0;

        // one directed vector per opcode
        check(8'h05, 8'h03, 4'h4, "ADD");
        check(8'h05, 8'h03, 4'h5, "SUB");
        check(8'hF0, 8'h0F, 4'h6, "AND");
        check(8'hF0, 8'h0F, 4'h7, "OR");
        check(8'hFF, 8'h0F, 4'h8, "XOR");
        check(8'h81, 8'h00, 4'h9, "SHL");
        check(8'h81, 8'h00, 4'hA, "SHR");
        check(8'h05, 8'h05, 4'hB, "CMP");

        // the documented corner-case operands (Section 8.5, R25), both
        // as the 'a' and as the 'b' operand, on ADD and SUB
        for (i = 0; i < 5; i = i + 1) begin
            case (i)
                0: a = 8'h00; 1: a = 8'h01; 2: a = 8'h7F; 3: a = 8'h80; 4: a = 8'hFF;
            endcase
            check(a, 8'h01, 4'h4, "ADD corner (a)");
            check(8'h01, a, 4'h4, "ADD corner (b)");
            check(a, 8'h01, 4'h5, "SUB corner (a)");
            check(8'h01, a, 4'h5, "SUB corner (b)");
        end

        if (errors == 0) begin
            $display("TESTBENCH: PASS");
        end else begin
            $display("TESTBENCH: FAIL (%0d errors)", errors);
        end
        $finish;
    end

endmodule
