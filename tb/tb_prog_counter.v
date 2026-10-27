// =============================================================================
// Unit Testbench: tb_prog_counter
// Self-checking testbench for prog_counter (Member A)
// =============================================================================

`timescale 1ns/1ps

module tb_prog_counter;

    reg        clk;
    reg        rst_n;
    reg        pc_en;
    reg        pc_load;
    reg  [8:0] branch_addr;
    wire [8:0] pc;

    integer errors = 0;

    prog_counter dut (
        .clk(clk),
        .rst_n(rst_n),
        .pc_en(pc_en),
        .pc_load(pc_load),
        .branch_addr(branch_addr),
        .pc(pc)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        pc_en = 0;
        pc_load = 0;
        branch_addr = 9'h000;

        // 1. Reset check
        #20;
        @(posedge clk);
        if (pc !== 9'h000) begin
            $display("FAIL: Reset did not set PC to 0x000, got %03X", pc);
            errors = errors + 1;
        end
        rst_n = 1;

        // 2. PC held when pc_en = 0
        @(posedge clk);
        if (pc !== 9'h000) begin
            $display("FAIL: PC changed while pc_en=0");
            errors = errors + 1;
        end

        // 3. PC increment when pc_en = 1, pc_load = 0
        pc_en = 1;
        @(posedge clk);
        #1;
        if (pc !== 9'h001) begin
            $display("FAIL: Expected PC=0x001, got %03X", pc);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;
        if (pc !== 9'h002) begin
            $display("FAIL: Expected PC=0x002, got %03X", pc);
            errors = errors + 1;
        end

        // 4. PC branch load
        pc_load = 1;
        branch_addr = 9'h1A5;
        @(posedge clk);
        #1;
        if (pc !== 9'h1A5) begin
            $display("FAIL: Expected PC=0x1A5 on branch, got %03X", pc);
            errors = errors + 1;
        end

        // 5. Increment from branched address
        pc_load = 0;
        @(posedge clk);
        #1;
        if (pc !== 9'h1A6) begin
            $display("FAIL: Expected PC=0x1A6 after branch, got %03X", pc);
            errors = errors + 1;
        end

        // 6. Wrap around 511 -> 0
        pc_load = 1;
        branch_addr = 9'h1FF;
        @(posedge clk);
        #1;
        pc_load = 0;
        @(posedge clk);
        #1;
        if (pc !== 9'h000) begin
            $display("FAIL: PC did not wrap to 0x000 from 0x1FF, got %03X", pc);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tb_prog_counter passed all checks!");
        else
            $display("FAIL: tb_prog_counter encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
