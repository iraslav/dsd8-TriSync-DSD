// =============================================================================
// Unit Testbench: tb_flags_reg
// Self-checking testbench for flags_reg (Member B)
// =============================================================================

`timescale 1ns/1ps

module tb_flags_reg;

    reg        clk;
    reg        rst_n;
    reg        flags_we;
    reg  [3:0] flags_in;
    wire [3:0] flags_out;

    integer errors = 0;

    flags_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .flags_we(flags_we),
        .flags_in(flags_in),
        .flags_out(flags_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        flags_we = 0;
        flags_in = 4'b0000;

        #20;
        // Check reset
        if (flags_out !== 4'b0000) begin
            $display("FAIL: flags_out not 0000 on reset"); errors = errors + 1;
        end
        rst_n = 1;

        // Verify holding when flags_we = 0
        @(posedge clk);
        flags_in = 4'b1010;
        flags_we = 0;
        @(posedge clk);
        #1;
        if (flags_out !== 4'b0000) begin
            $display("FAIL: flags_out changed when flags_we=0"); errors = errors + 1;
        end

        // Verify updating when flags_we = 1
        flags_we = 1;
        @(posedge clk);
        #1;
        if (flags_out !== 4'b1010) begin
            $display("FAIL: flags_out did not update to 1010"); errors = errors + 1;
        end

        // Another update
        flags_in = 4'b0101;
        @(posedge clk);
        #1;
        if (flags_out !== 4'b0101) begin
            $display("FAIL: flags_out did not update to 0101"); errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tb_flags_reg passed all checks!");
        else
            $display("FAIL: tb_flags_reg encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
