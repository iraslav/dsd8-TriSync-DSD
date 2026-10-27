// =============================================================================
// Unit Testbench: tb_data_memory
// Self-checking testbench for data_memory (Member C)
// Verifies Requirement R16 (all 256 bytes cleared to 0x00 on reset) and R/W.
// =============================================================================

`timescale 1ns/1ps

module tb_data_memory;

    reg        clk;
    reg        rst_n;
    reg  [7:0] addr;
    reg        we;
    reg  [7:0] wdata;
    wire [7:0] rdata;

    integer errors = 0;
    integer i;

    data_memory dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .we(we),
        .wdata(wdata),
        .rdata(rdata)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        addr = 8'h00;
        we = 0;
        wdata = 8'h00;

        #20;
        // Verify R16: all 256 bytes must read 0x00 upon reset
        for (i = 0; i < 256; i = i + 1) begin
            addr = i[7:0];
            #1;
            if (rdata !== 8'h00) begin
                $display("FAIL R16: DMEM[0x%02X] not 0x00 on reset, got %02X", i, rdata);
                errors = errors + 1;
            end
        end

        @(posedge clk);
        #1;
        rst_n = 1;

        // Write walking ones pattern on negedge clk
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            we = 1;
            addr = i[7:0];
            wdata = (8'h01 << i);
        end
        @(negedge clk);
        we = 0;

        // Verify walking ones read back
        for (i = 0; i < 8; i = i + 1) begin
            addr = i[7:0];
            #1;
            if (rdata !== (8'h01 << i)) begin
                $display("FAIL: DMEM[0x%02X] expected %02X, got %02X", i, (8'h01 << i), rdata);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: tb_data_memory passed all checks!");
        else
            $display("FAIL: tb_data_memory encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
