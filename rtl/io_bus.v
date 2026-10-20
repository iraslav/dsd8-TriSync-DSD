// io_bus.v -- port address decode and the io_ready handshake
// Owner: member C -- this is YOUR module; you are individually examined
// on it at the oral defence.
// Spec: Section 7. The CPU-facing side of this module (the six signals
// wired to dsd8_cpu) is frozen by Section 7.1's signal table. The
// board/peripheral-facing side below is NOT dictated verbatim by the
// spec excerpts this template was built from -- treat those ports as a
// starting design, confirm them against your own course's Section 5.11
// if one exists, and adjust freely; unlike dsd8_cpu, no external
// testbench binds to io_bus's peripheral-facing ports by name.
//
// What is required (Section 7.1, R19-R21): decode io_port into the
// right peripheral, forward io_rd/io_wr and stall the CPU (by holding
// io_ready low) until the addressed peripheral is ready. Ports 0x00 to
// 0x3F are reserved and behave exactly per Section 7.2's table; reads
// of an unmapped port return 0x00, writes to one are discarded, and no
// port may ever hold io_ready low indefinitely.

module io_bus (
    input  wire        clk,
    input  wire        rst_n,

    // ---- CPU-facing side: matches dsd8_cpu's io_* ports exactly ----
    input  wire [7:0]  io_port,
    input  wire [7:0]  io_wdata,
    output wire [7:0]  io_rdata,
    input  wire        io_rd,
    input  wire        io_wr,
    output wire        io_ready,

    // ---- board-facing side (Section 7.2 standard port map) ----
    input  wire [7:0]  switches,     // port 0x00
    input  wire [4:0]  buttons,      // port 0x01
    output reg  [7:0]  leds,         // port 0x02
    output reg  [7:0]  seg_value,    // port 0x10
    output reg  [7:0]  seg_enable,   // port 0x11

    // ---- forwarded to sim/peripherals.v for UART / timer / SLOW_ECHO ----
    output wire [7:0]  periph_port,
    output wire [7:0]  periph_wdata,
    input  wire [7:0]  periph_rdata,
    output wire        periph_rd,
    output wire        periph_wr,
    input  wire        periph_ready
);

    // Safe placeholder: no peripheral ever finishes (io_ready stays low
    // forever), so this compiles and lints clean but will hang the CPU
    // the first time it is used. Implement the decode + handshake per
    // Section 7.1 before wiring this into dsd8_top or tb_dsd8.v.

    assign io_rdata     = 8'h00;
    assign io_ready      = 1'b0;
    assign periph_port  = io_port;
    assign periph_wdata = io_wdata;
    assign periph_rd    = 1'b0;
    assign periph_wr    = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            leds       <= 8'h00;
            seg_value  <= 8'h00;
            seg_enable <= 8'h00;
        end else begin
            // TODO: decode io_port/io_wr and update leds/seg_value/seg_enable
            leds       <= leds;
            seg_value  <= seg_value;
            seg_enable <= seg_enable;
        end
    end

    // verilator lint_off UNUSEDSIGNAL
    wire [7:0] unused_switches   = switches;
    wire [4:0] unused_buttons    = buttons;
    wire [7:0] unused_periph_rd  = periph_rdata;
    wire       unused_periph_rdy = periph_ready;
    // verilator lint_on UNUSEDSIGNAL

endmodule
