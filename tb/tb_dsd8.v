// =============================================================================
// Testbench Harness: tb_dsd8
// Instantiates dsd8_cpu + instr_memory + io_bus
// Matches Section 8.3 of DSD-8 Specification
// Supports dynamic +IMAGE=<path> and +TRACE=<path> runtime options
// =============================================================================

`timescale 1ns/1ps

module tb_dsd8;

    reg clk;
    reg rst_n;

    // IMEM interface
    wire [8:0]  imem_addr;
    wire [15:0] imem_data;

    // IO bus
    wire [7:0]  io_port;
    wire [7:0]  io_wdata;
    wire [7:0]  io_rdata;
    wire        io_rd;
    wire        io_wr;
    wire        io_ready;

    // Board peripherals
    wire [7:0]  leds;
    wire [6:0]  seg;
    wire [3:0]  an;

    // CPU trace signals
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

    // Direct IMEM array for flexible runtime loading
    reg [15:0] imem_array [0:511];
    assign imem_data = imem_array[imem_addr];

    // Instantiate CPU Core
    dsd8_cpu u_cpu (
        .clk            (clk),
        .rst_n          (rst_n),
        .imem_addr      (imem_addr),
        .imem_data      (imem_data),
        .io_port        (io_port),
        .io_wdata       (io_wdata),
        .io_rdata       (io_rdata),
        .io_rd          (io_rd),
        .io_wr          (io_wr),
        .io_ready       (io_ready),
        .halted         (halted),
        .retire         (retire),
        .retire_pc      (retire_pc),
        .retire_ir      (retire_ir),
        .retire_rf_we   (retire_rf_we),
        .retire_rf_addr (retire_rf_addr),
        .retire_rf_data (retire_rf_data),
        .retire_mem_we  (retire_mem_we),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_data(retire_mem_data),
        .retire_flags   (retire_flags)
    );

    // Instantiate I/O Bus Controller & Peripherals
    io_bus u_io (
        .clk      (clk),
        .rst_n    (rst_n),
        .io_port  (io_port),
        .io_wdata (io_wdata),
        .io_rdata (io_rdata),
        .io_rd    (io_rd),
        .io_wr    (io_wr),
        .io_ready (io_ready),
        .switches (8'h00),
        .buttons  (5'b00000),
        .leds     (leds),
        .seg      (seg),
        .an       (an)
    );

    // Clock generator: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Trace logging per §8.3
    integer f;
    integer seq;
    integer cycle_count;
    integer max_cycles;
    reg [1023:0] image_file;
    reg [1023:0] trace_file;
    integer i;

    initial begin
        clk = 0;
        rst_n = 0;
        seq = 1;
        cycle_count = 0;
        max_cycles = 100000;

        // Clear IMEM
        for (i = 0; i < 512; i = i + 1)
            imem_array[i] = 16'h0000;

        // Determine image file
        if (!$value$plusargs("IMAGE=%s", image_file)) begin
            image_file = "sim/multiply.hex";
        end

        // Determine trace file
        if (!$value$plusargs("TRACE=%s", trace_file)) begin
            trace_file = "sim/dut.trace";
        end

        // Load hex image
        $readmemh(image_file, imem_array);

        f = $fopen(trace_file, "w");
        if (f == 0) begin
            $display("ERROR: Could not open trace file %0s", trace_file);
            $finish;
        end

        // Assert reset for 3 clock cycles per requirement R7
        #15;
        rst_n = 1;

        // Run until halted or cycle limit
        while (!halted && cycle_count < max_cycles) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // Allow writeback of HLT to flush
        repeat (5) @(posedge clk);

        $fclose(f);
        $display("Simulation completed. Halted=%b, Cycles=%0d, Instructions=%0d", halted, cycle_count, seq-1);
        $finish;
    end

    // Trace logger per §8.3
    always @(posedge clk) begin
        if (rst_n && retire) begin
            $fdisplay(f, "%04d %03X %04X %01d %01d %02X %01d %02X %02X %01d%01d%01d%01d",
                     seq, retire_pc, retire_ir,
                     retire_rf_we, retire_rf_addr, retire_rf_data,
                     retire_mem_we, retire_mem_addr, retire_mem_data,
                     retire_flags[3], retire_flags[2], retire_flags[1], retire_flags[0]);
            seq <= seq + 1;
        end
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
