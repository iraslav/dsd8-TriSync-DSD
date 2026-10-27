// =============================================================================
// Unit Testbench: tb_register_file
// Self-checking testbench for register_file (Member B)
// =============================================================================

`timescale 1ns/1ps

module tb_register_file;

    reg        clk;
    reg        rst_n;
    reg  [2:0] ra1, ra2;
    wire [7:0] rd1, rd2;
    reg        we;
    reg  [2:0] wa;
    reg  [7:0] wd;

    integer errors = 0;
    integer i;

    register_file dut (
        .clk(clk),
        .rst_n(rst_n),
        .ra1(ra1),
        .ra2(ra2),
        .rd1(rd1),
        .rd2(rd2),
        .we(we),
        .wa(wa),
        .wd(wd)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        ra1 = 0;
        ra2 = 0;
        we = 0;
        wa = 0;
        wd = 0;

        #20;
        // 1. Reset check: all registers 0x00
        for (i = 0; i < 8; i = i + 1) begin
            ra1 = i[2:0];
            #1;
            if (rd1 !== 8'h00) begin
                $display("FAIL: Register R%0d not 0x00 on reset, got %02X", i, rd1);
                errors = errors + 1;
            end
        end

        @(posedge clk);
        #1;
        rst_n = 1;

        // 2. Write distinct values into all registers (drive inputs on negedge clk)
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            we = 1;
            wa = i[2:0];
            wd = 8'h10 + i;
        end
        @(negedge clk);
        we = 0;

        // Verify all 8 registers retained their values
        for (i = 0; i < 8; i = i + 1) begin
            ra1 = i[2:0];
            ra2 = (7 - i);
            #1;
            if (rd1 !== (8'h10 + i)) begin
                $display("FAIL: R%0d expected %02X, got %02X", i, 8'h10 + i, rd1);
                errors = errors + 1;
            end
            if (rd2 !== (8'h10 + (7 - i))) begin
                $display("FAIL: R%0d on port 2 expected %02X, got %02X", 7-i, 8'h10 + (7-i), rd2);
                errors = errors + 1;
            end
        end

        // 3. Test R14: Read-during-write must return OLD value combinationally
        @(negedge clk);
        ra1 = 3'd3; // R3 currently holds 0x13
        we  = 1;
        wa  = 3'd3;
        wd  = 8'hAA; // Writing 0xAA

        @(posedge clk); // Clock edge happens
        #1; // Sample immediately after edge
        if (rd1 !== 8'hAA) begin
            // Wait, R14 says: "A write and a read of the same register in the same cycle
            // shall return the old value on the read ports; the new value becomes visible on the following cycle."
            // Before the clock edge (during the cycle): rd1 returns old value (8'h13).
        end

        // Let's explicitly test within the cycle before clock edge:
        @(negedge clk);
        ra1 = 3'd4; // R4 holds 0x14
        we  = 1;
        wa  = 3'd4;
        wd  = 8'h55;
        #1;
        // Prior to posedge clk, rd1 MUST return 0x14 (old value)!
        if (rd1 !== 8'h14) begin
            $display("FAIL: R14 violation! Combinational read during write did not return old value. Got %02X", rd1);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;
        // After posedge clk, rd1 updates to 0x55
        if (rd1 !== 8'h55) begin
            $display("FAIL: R4 did not update to 0x55 on following cycle");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tb_register_file passed all checks!");
        else
            $display("FAIL: tb_register_file encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
