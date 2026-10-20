// control_unit.v -- the FSM that sequences every instruction
// Owner: member C -- this is YOUR module; you are individually examined
// on it at the oral defence, and it is the heart of your microarchitecture
// choice (Section 4.3).
// Spec: Section 6. Port list is FROZEN.
//
// This is deliberately the least finished file in this repository: the
// control unit is the one part of the design the spec leaves entirely
// up to you (single-cycle, multi-cycle, or pipelined -- Section 4.3),
// and it is what the recommended state machine and control-signal
// table in Section 6 describe. Copying a working FSM from anywhere
// would defeat the point of the assignment and of the oral defence.
//
// What every implementation must guarantee, regardless of style
// (Section 8.2, R22): instructions retire in program order, and
// `retire` pulses exactly once per retired instruction -- never zero,
// never twice.

module control_unit (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] opcode,
    input  wire [2:0] cond,
    input  wire [3:0] flags,      // {Z,N,C,V}
    input  wire       io_ready,
    output reg        pc_en,
    output reg        pc_load,
    output reg        rf_we,
    output reg        mem_we,
    output reg        io_rd,
    output reg        io_wr,
    output reg        flags_we,
    output reg  [1:0] wb_sel,     // 0=ALU 1=DMEM 2=imm8 3=io_rdata
    output reg        halted,
    output reg        retire
);

    // Safe placeholder: every output held low/constant on every path
    // (no inferred latches), nothing retires yet. Build your FSM here
    // -- Section 6.1's diagram and Section 6.2's control-signal table
    // are your starting point, not a fixed answer for every opcode.
    always @(posedge clk) begin
        if (!rst_n) begin
            pc_en    <= 1'b0;
            pc_load  <= 1'b0;
            rf_we    <= 1'b0;
            mem_we   <= 1'b0;
            io_rd    <= 1'b0;
            io_wr    <= 1'b0;
            flags_we <= 1'b0;
            wb_sel   <= 2'b00;
            halted   <= 1'b0;
            retire   <= 1'b0;
        end else begin
            // TODO: implement the state machine from Section 6.
            pc_en    <= 1'b0;
            pc_load  <= 1'b0;
            rf_we    <= 1'b0;
            mem_we   <= 1'b0;
            io_rd    <= 1'b0;
            io_wr    <= 1'b0;
            flags_we <= 1'b0;
            wb_sel   <= 2'b00;
            halted   <= halted;
            retire   <= 1'b0;
        end
    end

    // verilator lint_off UNUSEDSIGNAL
    wire [3:0] unused_opcode = opcode;
    wire [2:0] unused_cond   = cond;
    wire [3:0] unused_flags  = flags;
    wire       unused_ready  = io_ready;
    // verilator lint_on UNUSEDSIGNAL

endmodule
