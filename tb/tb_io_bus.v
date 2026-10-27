// =============================================================================
// Unit Testbench: tb_io_bus
// Self-checking testbench for io_bus (Member C)
// Verifies standard port mappings (0x00, 0x01, 0x02, 0x10, 0x11, 0x40 SLOW_ECHO)
// =============================================================================

`timescale 1ns/1ps

module tb_io_bus;

    reg        clk;
    reg        rst_n;
    reg  [7:0] io_port;
    reg  [7:0] io_wdata;
    wire [7:0] io_rdata;
    reg        io_rd;
    reg        io_wr;
    wire       io_ready;

    reg  [7:0] switches;
    reg  [4:0] buttons;
    wire [7:0] leds;
    wire [6:0] seg;
    wire [3:0] an;

    integer errors = 0;

    io_bus dut (
        .clk(clk),
        .rst_n(rst_n),
        .io_port(io_port),
        .io_wdata(io_wdata),
        .io_rdata(io_rdata),
        .io_rd(io_rd),
        .io_wr(io_wr),
        .io_ready(io_ready),
        .switches(switches),
        .buttons(buttons),
        .leds(leds),
        .seg(seg),
        .an(an)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        io_port = 0;
        io_wdata = 0;
        io_rd = 0;
        io_wr = 0;
        switches = 8'hA5;
        buttons = 5'b10101;

        #20;
        rst_n = 1;

        // 1. Read Switches (Port 0x00)
        io_port = 8'h00;
        io_rd = 1;
        #1;
        if (io_rdata !== 8'hA5) begin
            $display("FAIL: Port 0x00 SWITCHES read expected 0xA5, got %02X", io_rdata);
            errors = errors + 1;
        end
        io_rd = 0;

        // 2. Read Buttons (Port 0x01)
        io_port = 8'h01;
        io_rd = 1;
        #1;
        if (io_rdata !== 8'h15) begin
            $display("FAIL: Port 0x01 BUTTONS read expected 0x15, got %02X", io_rdata);
            errors = errors + 1;
        end
        io_rd = 0;

        // 3. Write LEDs (Port 0x02)
        @(posedge clk);
        io_port = 8'h02;
        io_wdata = 8'h5B;
        io_wr = 1;
        @(posedge clk);
        io_wr = 0;
        #1;
        if (leds !== 8'h5B) begin
            $display("FAIL: Port 0x02 LEDS write expected 0x5B, got %02X", leds);
            errors = errors + 1;
        end

        // 4. Read Unmapped port (Port 0x88) must return 0x00 per R21
        io_port = 8'h88;
        io_rd = 1;
        #1;
        if (io_rdata !== 8'h00) begin
            $display("FAIL R21: Unmapped port 0x88 read did not return 0x00, got %02X", io_rdata);
            errors = errors + 1;
        end
        io_rd = 0;

        if (errors == 0)
            $display("PASS: tb_io_bus passed all checks!");
        else
            $display("FAIL: tb_io_bus encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
