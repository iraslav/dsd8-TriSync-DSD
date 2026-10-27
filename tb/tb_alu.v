// =============================================================================
// Unit Testbench: tb_alu
// Self-checking testbench for alu (Member B)
// Tests: ADD, SUB, AND, OR, XOR, SHL, SHR, CMP and all condition flags Z,N,C,V.
// =============================================================================

`timescale 1ns/1ps

module tb_alu;

    reg  [7:0] a, b;
    reg  [3:0] op;
    wire [7:0] result;
    wire       flag_z, flag_n, flag_c, flag_v;

    integer errors = 0;

    alu dut (
        .a(a), .b(b), .op(op),
        .result(result),
        .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v)
    );

    task check_alu(
        input [7:0] exp_res,
        input exp_z, input exp_n, input exp_c, input exp_v,
        input [127:0] test_name
    );
    begin
        #1;
        if (result !== exp_res || flag_z !== exp_z || flag_n !== exp_n ||
            flag_c !== exp_c || flag_v !== exp_v) begin
            $display("FAIL: %0s | Got: Res=%02X Flags={Z=%b,N=%b,C=%b,V=%b} | Expected: Res=%02X Flags={Z=%b,N=%b,C=%b,V=%b}",
                     test_name, result, flag_z, flag_n, flag_c, flag_v, exp_res, exp_z, exp_n, exp_c, exp_v);
            errors = errors + 1;
        end
    end
    endtask

    initial begin
        // --- ADD Tests ---
        op = 4'h4;
        a = 8'h05; b = 8'h03; // 5 + 3 = 8
        check_alu(8'h08, 0, 0, 0, 0, "ADD simple");

        a = 8'hFF; b = 8'h01; // 0xFF + 1 = 0x00, C=1, Z=1
        check_alu(8'h00, 1, 0, 1, 0, "ADD carry & zero");

        a = 8'h7F; b = 8'h01; // 127 + 1 = 128 (0x80), V=1, N=1
        check_alu(8'h80, 0, 1, 0, 1, "ADD signed overflow");

        // --- SUB Tests ---
        op = 4'h5;
        a = 8'h0A; b = 8'h04; // 10 - 4 = 6, C=1 (no borrow)
        check_alu(8'h06, 0, 0, 1, 0, "SUB simple");

        a = 8'h05; b = 8'h05; // 5 - 5 = 0, C=1, Z=1
        check_alu(8'h00, 1, 0, 1, 0, "SUB zero");

        a = 8'h02; b = 8'h05; // 2 - 5 = 0xFD (-3), C=0 (borrow!), N=1
        check_alu(8'hFD, 0, 1, 0, 0, "SUB borrow");

        a = 8'h80; b = 8'h01; // -128 - 1 = +127 (0x7F), V=1 (overflow)
        check_alu(8'h7F, 0, 0, 1, 1, "SUB signed overflow");

        // --- CMP Tests ---
        op = 4'hB;
        a = 8'h07; b = 8'h00; // 7 vs 0 -> C=1, Z=0, N=0, V=0 (Appendix B.1 line 6 test!)
        check_alu(8'h07, 0, 0, 1, 0, "CMP 7 vs 0");

        // --- Bitwise AND, OR, XOR ---
        op = 4'h6; a = 8'hAA; b = 8'h0F; // 0xAA & 0x0F = 0x0A
        check_alu(8'h0A, 0, 0, 0, 0, "AND");

        op = 4'h7; a = 8'hF0; b = 8'h0F; // 0xF0 | 0x0F = 0xFF, N=1
        check_alu(8'hFF, 0, 1, 0, 0, "OR negative");

        op = 4'h8; a = 8'hAA; b = 8'hAA; // 0xAA ^ 0xAA = 0x00, Z=1
        check_alu(8'h00, 1, 0, 0, 0, "XOR zero");

        // --- SHL Tests ---
        op = 4'h9;
        a = 8'h81; // SHL 0x81 -> 0x02, C=1 (bit 7 out)
        check_alu(8'h02, 0, 0, 1, 0, "SHL carry");

        // --- SHR Tests (Logical) ---
        op = 4'hA;
        a = 8'h81; // SHR 0x81 -> 0x40, C=1 (bit 0 out)
        check_alu(8'h40, 0, 0, 1, 0, "SHR logical");

        a = 8'h80; // SHR 0x80 -> 0x40, never 0xC0 (logical shift verification)
        check_alu(8'h40, 0, 0, 0, 0, "SHR 0x80->0x40 logical");

        if (errors == 0)
            $display("PASS: tb_alu passed all unit checks!");
        else
            $display("FAIL: tb_alu encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
