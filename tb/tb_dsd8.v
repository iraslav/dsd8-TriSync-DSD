// tb_dsd8.v -- the conformance harness (Section 8.3)
//
// This is the file the spec calls "the supplied harness": it
// instantiates your dsd8_cpu (plus instr_memory and io_bus, which sit
// outside dsd8_cpu's own boundary), drives clock and reset, loads a
// hex image, runs until `halted` or a cycle limit, and writes a trace
// file in exactly the ten-field format from Section 8.2. Teams do not
// modify this file -- if you think it is wrong, that is worth raising
// with the instructor, not patching locally, since everyone is graded
// against the same harness.
//
// Two parameters are overridden per test run from the command line
// (see scripts/run_conformance.py), rather than hardcoded here:
//   -Ptb_dsd8.imem.IMAGE=\"path/to/test.hex\"
//   -Ptb_dsd8.TRACE_FILE=\"path/to/dut.trace\"
//
// NOTE on io_bus: Section 7.1 freezes dsd8_cpu's six io_* signals, but
// this template was built without the exact frozen port list for
// io_bus's peripheral-facing side (see rtl/io_bus.v). The instantiation
// below matches the ports declared in that file. If your course
// provides a different io_bus interface, update both files together.

`timescale 1ns/1ps

module tb_dsd8;

    parameter TRACE_FILE  = "dut.trace";
    parameter MAX_CYCLES  = 200000;

    reg clk;
    reg rst_n;

    // ---- fetch interface between dsd8_cpu and instr_memory ----
    wire [8:0]  imem_addr;
    wire [15:0] imem_data;

    // ---- I/O bus between dsd8_cpu and io_bus ----
    wire [7:0] io_port, io_wdata, io_rdata;
    wire       io_rd, io_wr, io_ready;

    // ---- board-facing side of io_bus, driven to quiescent values ----
    reg  [7:0] switches;
    reg  [4:0] buttons;
    wire [7:0] leds, seg_value, seg_enable;

    // ---- io_bus <-> reference peripherals (sim/peripherals.v) ----
    wire [7:0] periph_port, periph_wdata, periph_rdata;
    wire       periph_rd, periph_wr, periph_ready;

    // ---- status / trace ----
    wire        halted;
    wire        retire;
    wire [8:0]  retire_pc;
    wire [15:0] retire_ir;
    wire        retire_rf_we;
    wire [2:0]  retire_rf_addr;
    wire [7:0]  retire_rf_data;
    wire        retire_mem_we;
    wire [7:0]  retire_mem_addr;
    wire [7:0]  retire_mem_data;
    wire [3:0]  retire_flags;

    integer f;
    integer seq;
    integer cycle_count;

    // ---- clock: 10ns period ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- reset: held low for the first 4 edges (>= 2 cycles, R7) ----
    initial begin
        rst_n = 1'b0;
        switches = 8'h00;
        buttons  = 5'h00;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
    end

    // ---- device under test ----
    dsd8_cpu uut (
        .clk             (clk),
        .rst_n           (rst_n),
        .imem_addr       (imem_addr),
        .imem_data       (imem_data),
        .io_port         (io_port),
        .io_wdata        (io_wdata),
        .io_rdata        (io_rdata),
        .io_rd           (io_rd),
        .io_wr           (io_wr),
        .io_ready        (io_ready),
        .halted          (halted),
        .retire          (retire),
        .retire_pc       (retire_pc),
        .retire_ir       (retire_ir),
        .retire_rf_we    (retire_rf_we),
        .retire_rf_addr  (retire_rf_addr),
        .retire_rf_data  (retire_rf_data),
        .retire_mem_we   (retire_mem_we),
        .retire_mem_addr (retire_mem_addr),
        .retire_mem_data (retire_mem_data),
        .retire_flags    (retire_flags)
    );

    // instance name "imem" -- run_conformance.py overrides IMAGE with -P
    instr_memory imem (
        .clk  (clk),
        .addr (imem_addr),
        .data (imem_data)
    );

    io_bus io_bus_inst (
        .clk           (clk),
        .rst_n         (rst_n),
        .io_port       (io_port),
        .io_wdata      (io_wdata),
        .io_rdata      (io_rdata),
        .io_rd         (io_rd),
        .io_wr         (io_wr),
        .io_ready      (io_ready),
        .switches      (switches),
        .buttons       (buttons),
        .leds          (leds),
        .seg_value     (seg_value),
        .seg_enable    (seg_enable),
        .periph_port   (periph_port),
        .periph_wdata  (periph_wdata),
        .periph_rdata  (periph_rdata),
        .periph_rd     (periph_rd),
        .periph_wr     (periph_wr),
        .periph_ready  (periph_ready)
    );

    // instructor-supplied reference peripherals (sim/peripherals.v) --
    // a fault here is never mistaken for a fault in your CPU (Section 7.2)
    dsd8_ref_peripherals peripherals (
        .clk          (clk),
        .rst_n        (rst_n),
        .periph_port  (periph_port),
        .periph_wdata (periph_wdata),
        .periph_rdata (periph_rdata),
        .periph_rd    (periph_rd),
        .periph_wr    (periph_wr),
        .periph_ready (periph_ready)
    );

    // ---- trace writer: exactly the fragment from Section 8.3 ----
    initial begin
        f = $fopen(TRACE_FILE, "w");
        seq = 1;
    end

    always @(posedge clk) begin
        if (rst_n && retire) begin
            $fdisplay(f, "%04d %03x %04x %01d %01d %02x %01d %02x %02x %01d%01d%01d%01d",
                      seq, retire_pc, retire_ir,
                      retire_rf_we, retire_rf_addr, retire_rf_data,
                      retire_mem_we, retire_mem_addr, retire_mem_data,
                      retire_flags[3], retire_flags[2], retire_flags[1], retire_flags[0]);
            seq <= seq + 1;
        end
    end

    // ---- run until halted or the cycle limit, then stop ----
    initial begin
        cycle_count = 0;
        @(posedge rst_n);
        while (!halted && cycle_count < MAX_CYCLES) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        if (!halted) begin
            $display("tb_dsd8: WARNING -- hit MAX_CYCLES (%0d) without halting", MAX_CYCLES);
        end
        $fclose(f);
        $finish;
    end

endmodule
