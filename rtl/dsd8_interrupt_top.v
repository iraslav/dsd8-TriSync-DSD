// =============================================================================
// Module: dsd8_interrupt_top
// Description: Interrupt-enabled system top. The existing dsd8_top and its
//              baseline I/O bus remain unchanged; this top adds ports 0x50-5F.
// =============================================================================

module dsd8_interrupt_top #(
    parameter IMAGE = "program.hex"
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] switches,
    input  wire [4:0] buttons,
    output wire [7:0] leds,
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire       halted
);

    wire [8:0]  imem_addr;
    wire [15:0] imem_data;
    wire [7:0]  io_port;
    wire [7:0]  io_wdata;
    wire [7:0]  base_io_rdata;
    wire [7:0]  irq_io_rdata;
    wire [7:0]  io_rdata;
    wire        io_rd;
    wire        io_wr;
    wire        base_io_ready;
    wire        irq_io_ready;
    wire        irq_port_selected = (io_port[7:4] == 4'h5);
    wire        io_ready = base_io_ready &&
                           (!irq_port_selected || irq_io_ready);
    wire        irq_io_rd = io_rd && base_io_ready;
    wire        irq_io_wr = io_wr && base_io_ready;

    instr_memory #(.IMAGE(IMAGE)) u_imem (
        .clk  (clk),
        .addr (imem_addr),
        .data (imem_data)
    );

    dsd8_cpu u_cpu (
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
        .retire           (),
        .retire_pc        (),
        .retire_ir        (),
        .retire_rf_we     (),
        .retire_rf_addr   (),
        .retire_rf_data   (),
        .retire_mem_we    (),
        .retire_mem_addr  (),
        .retire_mem_data  (),
        .retire_flags     ()
    );

    io_bus u_io_bus (
        .clk      (clk),
        .rst_n    (rst_n),
        .io_port  (io_port),
        .io_wdata (io_wdata),
        .io_rdata (base_io_rdata),
        .io_rd    (io_rd),
        .io_wr    (io_wr),
        .io_ready (base_io_ready),
        .switches (switches),
        .buttons  (buttons),
        .leds     (leds),
        .seg      (seg),
        .an       (an)
    );

    interrupt_controller u_interrupt_controller (
        .clk      (clk),
        .rst_n    (rst_n),
        .io_port  (io_port),
        .io_wdata (io_wdata),
        .io_rdata (irq_io_rdata),
        .io_rd    (irq_io_rd),
        .io_wr    (irq_io_wr),
        .io_ready (irq_io_ready)
    );

    assign io_rdata = irq_port_selected ? irq_io_rdata : base_io_rdata;

endmodule
