// =============================================================================
// Module: dsd8_top
// Owner:  Shared
// Description: Top-level system module for FPGA board deployment and system
//              simulation. Instantiates dsd8_cpu, instr_memory, and io_bus.
//              Matches Section 5.1 of DSD-8 Specification.
// =============================================================================

module dsd8_top #(
    parameter IMAGE = "program.hex"
) (
    input  wire        clk,        // system clock
    input  wire        rst_n,      // synchronous, active low
    input  wire [7:0]  switches,   // board slide switches -> port 0x00
    input  wire [4:0]  buttons,    // {btnU,btnD,btnL,btnR,btnC} -> port 0x01
    output wire [7:0]  leds,       // board LEDs <- port 0x02
    output wire [6:0]  seg,        // seven-segment segments <- port 0x10
    output wire [3:0]  an,         // seven-segment digit enables <- port 0x11
    output wire        halted      // asserted after HLT retires
);

    // Instruction memory interface
    wire [8:0]  imem_addr;
    wire [15:0] imem_data;

    // I/O bus interface
    wire [7:0]  io_port;
    wire [7:0]  io_wdata;
    wire [7:0]  io_rdata;
    wire        io_rd;
    wire        io_wr;
    wire        io_ready;

    // Unused trace wires at top level
    wire        cpu_retire;
    wire [8:0]  cpu_retire_pc;
    wire [15:0] cpu_retire_ir;
    wire        cpu_retire_rf_we;
    wire [2:0]  cpu_retire_rf_addr;
    wire [7:0]  cpu_retire_rf_data;
    wire        cpu_retire_mem_we;
    wire [7:0]  cpu_retire_mem_addr;
    wire [7:0]  cpu_retire_mem_data;
    wire [3:0]  cpu_retire_flags;

    // Instruction Memory
    instr_memory #(.IMAGE(IMAGE)) u_imem (
        .clk (clk),
        .addr(imem_addr),
        .data(imem_data)
    );

    // Processor Core
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
        .retire         (cpu_retire),
        .retire_pc      (cpu_retire_pc),
        .retire_ir      (cpu_retire_ir),
        .retire_rf_we   (cpu_retire_rf_we),
        .retire_rf_addr (cpu_retire_rf_addr),
        .retire_rf_data (cpu_retire_rf_data),
        .retire_mem_we  (cpu_retire_mem_we),
        .retire_mem_addr(cpu_retire_mem_addr),
        .retire_mem_data(cpu_retire_mem_data),
        .retire_flags   (cpu_retire_flags)
    );

    // I/O Bus Controller & Peripherals
    io_bus u_io (
        .clk      (clk),
        .rst_n    (rst_n),
        .io_port  (io_port),
        .io_wdata (io_wdata),
        .io_rdata (io_rdata),
        .io_rd    (io_rd),
        .io_wr    (io_wr),
        .io_ready (io_ready),
        .switches (switches),
        .buttons  (buttons),
        .leds     (leds),
        .seg      (seg),
        .an       (an)
    );

endmodule
