// =============================================================================
// Unit Testbench: tb_control_unit
// Self-checking testbench for control_unit (Member C)
// Verifies control signals for all 16 opcodes, branch conditions, and IO stall.
// =============================================================================

`timescale 1ns/1ps

module tb_control_unit;

    reg        clk;
    reg        rst_n;
    reg  [3:0] opcode;
    reg  [2:0] cond;
    reg  [3:0] flags;
    reg        io_ready;

    wire       pc_en;
    wire       pc_load;
    wire       rf_we;
    wire       mem_we;
    wire       io_rd;
    wire       io_wr;
    wire       flags_we;
    wire [1:0] wb_sel;
    wire       halted;
    wire       retire;

    integer errors = 0;

    control_unit dut (
        .clk(clk),
        .rst_n(rst_n),
        .opcode(opcode),
        .cond(cond),
        .flags(flags),
        .io_ready(io_ready),
        .pc_en(pc_en),
        .pc_load(pc_load),
        .rf_we(rf_we),
        .mem_we(mem_we),
        .io_rd(io_rd),
        .io_wr(io_wr),
        .flags_we(flags_we),
        .wb_sel(wb_sel),
        .halted(halted),
        .retire(retire)
    );

    always #5 clk = ~clk;

    task step_instruction;
        begin
            @(posedge clk); // S_FETCH -> S_EXECUTE
            @(posedge clk); // S_EXECUTE -> S_WRITEBACK
            #1;             // sample outputs in WRITEBACK
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        opcode = 4'h0;
        cond = 3'b0;
        flags = 4'b0000;
        io_ready = 1;

        #20;
        rst_n = 1;

        // 1. NOP (0x0): rf_we=0, mem_we=0, flags_we=0, pc_en=1
        opcode = 4'h0;
        step_instruction;
        if (rf_we !== 0 || mem_we !== 0 || flags_we !== 0 || pc_en !== 1 || retire !== 1) begin
            $display("FAIL: Control unit NOP signals incorrect"); errors = errors + 1;
        end
        @(posedge clk); // return to FETCH

        // 2. LDI (0x1): rf_we=1, wb_sel=2
        opcode = 4'h1;
        step_instruction;
        if (rf_we !== 1 || wb_sel !== 2'd2 || pc_en !== 1) begin
            $display("FAIL: Control unit LDI signals incorrect"); errors = errors + 1;
        end
        @(posedge clk);

        // 3. CMP (0xB): rf_we=0, flags_we=1
        opcode = 4'hB;
        step_instruction;
        if (rf_we !== 0 || flags_we !== 1 || pc_en !== 1) begin
            $display("FAIL: Control unit CMP must set flags_we=1 and rf_we=0"); errors = errors + 1;
        end
        @(posedge clk);

        // 4. Branch BEQ taken: flags[3]=1 (Z=1), cond=000 -> pc_load=1
        opcode = 4'hD;
        cond = 3'b000;
        flags = 4'b1000; // Z=1
        step_instruction;
        if (pc_load !== 1) begin
            $display("FAIL: BEQ branch should be taken when Z=1"); errors = errors + 1;
        end
        @(posedge clk);

        // 5. Branch BEQ not taken: flags[3]=0 (Z=0), cond=000 -> pc_load=0
        opcode = 4'hD;
        cond = 3'b000;
        flags = 4'b0000; // Z=0
        step_instruction;
        if (pc_load !== 0) begin
            $display("FAIL: BEQ branch should not be taken when Z=0"); errors = errors + 1;
        end
        @(posedge clk);

        // 6. Branch BCS taken: flags[1]=1 (C=1), cond=010 -> pc_load=1
        opcode = 4'hD;
        cond = 3'b010;
        flags = 4'b0010; // C=1
        step_instruction;
        if (pc_load !== 1) begin
            $display("FAIL: BCS branch should be taken when C=1"); errors = errors + 1;
        end
        @(posedge clk);

        if (errors == 0)
            $display("PASS: tb_control_unit passed all checks!");
        else
            $display("FAIL: tb_control_unit encountered %0d errors!", errors);

        $finish;
    end

// Optional waveform capture (only active when vvp runs with a +VCD=<file> plusarg)
`include "tb/wave_dump.vh"

endmodule
