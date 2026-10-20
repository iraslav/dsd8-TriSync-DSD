// dsd8_cpu.v -- the processor core: fetch, decode, execute, writeback
// Owner: shared (whole team integrates this together)
// Spec: Section 5.2. Port list is FROZEN -- tb_dsd8.v binds to these
// exact names to extract the execution trace (Section 8.3). Renaming
// any of them means the harness will not compile against your design.
//
// retire_* are not debug decoration -- they are how your processor is
// graded (Section 8.2). Get them right early.

module dsd8_cpu (
    input  wire        clk,
    input  wire        rst_n,

    // ---- instruction fetch interface ----
    output wire [8:0]  imem_addr,   // program counter
    input  wire [15:0] imem_data,   // instruction word, valid combinationally

    // ---- I/O bus (Section 7) ----
    output wire [7:0]  io_port,     // port number from IR[7:0]
    output wire [7:0]  io_wdata,    // data for OUT
    input  wire [7:0]  io_rdata,    // data for IN
    output wire        io_rd,       // asserted for one access during IN
    output wire        io_wr,       // asserted for one access during OUT
    input  wire        io_ready,    // peripheral ready; low stalls the CPU

    // ---- status and trace ----
    output wire        halted,
    output wire        retire,          // one pulse per retired instruction
    output wire [8:0]  retire_pc,       // PC of the instruction just retired
    output wire [15:0] retire_ir,       // its instruction word
    output wire        retire_rf_we,    // did it write a register?
    output wire [2:0]  retire_rf_addr,
    output wire [7:0]  retire_rf_data,
    output wire        retire_mem_we,   // did it write data memory?
    output wire [7:0]  retire_mem_addr,
    output wire [7:0]  retire_mem_data,
    output wire [3:0]  retire_flags     // {Z,N,C,V} after the instruction
);

    // TODO: instantiate prog_counter, instr_decoder, register_file, alu,
    // flags_reg, data_memory and control_unit here, and connect them per
    // your chosen microarchitecture (Section 4.3). instr_memory and
    // io_bus are NOT inside dsd8_cpu -- they are wired in one level up
    // (tb_dsd8.v for simulation, dsd8_top for the board).
    //
    // A minimal but *safe* placeholder is given below so that this file
    // compiles, lints clean (no inferred latches) and produces a valid
    // -- if wrong -- trace from the moment your repo exists. Replace it
    // module by module; do not wait until everything is written to run
    // your first simulation.

    reg [8:0] pc_r;
    always @(posedge clk) begin
        if (!rst_n) pc_r <= 9'h000;
        else        pc_r <= pc_r + 9'h001;
    end
    assign imem_addr = pc_r;

    assign io_port  = 8'h00;
    assign io_wdata = 8'h00;
    assign io_rd    = 1'b0;
    assign io_wr    = 1'b0;

    assign halted = 1'b0;
    assign retire = 1'b0;   // stays low: no lines emitted until this is wired up

    assign retire_pc       = pc_r;
    assign retire_ir       = imem_data;
    assign retire_rf_we    = 1'b0;
    assign retire_rf_addr  = 3'b000;
    assign retire_rf_data  = 8'h00;
    assign retire_mem_we   = 1'b0;
    assign retire_mem_addr = 8'h00;
    assign retire_mem_data = 8'h00;
    assign retire_flags    = 4'b0000;

endmodule
