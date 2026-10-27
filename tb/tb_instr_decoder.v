// =============================================================================
// Unit Testbench: tb_instr_decoder
// Self-checking testbench for instr_decoder (Member A)
// Verifies all 5 instruction formats per Section 3.1 & 3.5.
// =============================================================================

`timescale 1ns/1ps

module tb_instr_decoder;

    reg  [15:0] instr;
    wire [3:0]  opcode;
    wire [2:0]  rd;
    wire [2:0]  rs1;
    wire [2:0]  rs2;
    wire [7:0]  imm8;
    wire [8:0]  addr9;
    wire [2:0]  cond;
    wire [7:0]  port;
    wire        io_dir;

    integer errors = 0;

    instr_decoder dut (
        .instr(instr),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm8(imm8),
        .addr9(addr9),
        .cond(cond),
        .port(port),
        .io_dir(io_dir)
    );

    initial begin
        // 1. Format I: LDI R2, 13 -> 0x140D
        instr = 16'h140D;
        #1;
        if (opcode !== 4'h1 || rd !== 3'd2 || imm8 !== 8'h0D) begin
            $display("FAIL Format I (LDI R2, 13)"); errors = errors + 1;
        end

        // 2. Format R: ADD R3, R3, R1 -> 0x46C8
        instr = 16'h46C8;
        #1;
        if (opcode !== 4'h4 || rd !== 3'd3 || rs1 !== 3'd3 || rs2 !== 3'd1) begin
            $display("FAIL Format R (ADD R3, R3, R1)"); errors = errors + 1;
        end

        // 3. Format M: LD R5, [R3] -> 0x2AC0
        instr = 16'h2AC0;
        #1;
        if (opcode !== 4'h2 || rd !== 3'd5 || rs1 !== 3'd3) begin
            $display("FAIL Format M (LD R5, [R3])"); errors = errors + 1;
        end

        // 4. Format J: JMP 0x004 -> 0xC004
        instr = 16'hC004;
        #1;
        if (opcode !== 4'hC || addr9 !== 9'h004) begin
            $display("FAIL Format J (JMP 0x004)"); errors = errors + 1;
        end

        // 5. Format J: BCC 0x011 -> 0xD611 (cond=011)
        instr = 16'hD611;
        #1;
        if (opcode !== 4'hD || cond !== 3'b011 || addr9 !== 9'h011) begin
            $display("FAIL Format J (BCC 0x011)"); errors = errors + 1;
        end

        // 6. Format P: IN R1, 0x22 -> 0xE222 (dir=0)
        instr = 16'hE222;
        #1;
        if (opcode !== 4'hE || rd !== 3'd1 || io_dir !== 1'b0 || port !== 8'h22) begin
            $display("FAIL Format P (IN R1, 0x22)"); errors = errors + 1;
        end

        // 7. Format P: OUT 0x02, R3 -> 0xE702 (dir=1, rs=3)
        instr = 16'hE702;
        #1;
        if (opcode !== 4'hE || rd !== 3'd3 || io_dir !== 1'b1 || port !== 8'h02) begin
            $display("FAIL Format P (OUT 0x02, R3)"); errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tb_instr_decoder passed all checks!");
        else
            $display("FAIL: tb_instr_decoder encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
