// =============================================================================
// Module: control_unit
// Owner:  Member C
// Description: Multi-cycle FSM control unit for the DSD-8 processor.
//              States: FETCH → EXECUTE → WRITEBACK (3 cycles per instruction).
//              Generates all datapath control signals based on opcode.
//              Handles branch decision from cond and flags {Z,N,C,V}.
//              Handles io_ready stall for IN/OUT instructions.
//              Asserts 'retire' pulse in WRITEBACK for trace output.
//              Asserts 'halted' after HLT retires and stays halted until reset.
// =============================================================================

module control_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  opcode,
    input  wire [2:0]  cond,
    input  wire [3:0]  flags,       // {Z,N,C,V}: flags[3]=Z, flags[2]=N, flags[1]=C, flags[0]=V
    input  wire        io_ready,
    // ---- datapath control ----
    output reg         pc_en,
    output reg         pc_load,
    output reg         rf_we,
    output reg         mem_we,
    output reg         io_rd,
    output reg         io_wr,
    output reg         flags_we,
    output reg  [1:0]  wb_sel,      // 0=ALU 1=DMEM 2=imm8 3=io_rdata
    output reg         halted,
    output reg         retire       // one pulse as the instruction completes
);

    // Opcodes per Section 3.2
    localparam OP_NOP = 4'h0;
    localparam OP_LDI = 4'h1;
    localparam OP_LD  = 4'h2;
    localparam OP_ST  = 4'h3;
    localparam OP_ADD = 4'h4;
    localparam OP_SUB = 4'h5;
    localparam OP_AND = 4'h6;
    localparam OP_OR  = 4'h7;
    localparam OP_XOR = 4'h8;
    localparam OP_SHL = 4'h9;
    localparam OP_SHR = 4'hA;
    localparam OP_CMP = 4'hB;
    localparam OP_JMP = 4'hC;
    localparam OP_BCC = 4'hD;
    localparam OP_IO  = 4'hE;
    localparam OP_HLT = 4'hF;

    // FSM states
    localparam S_FETCH     = 3'd0;
    localparam S_EXECUTE   = 3'd1;
    localparam S_IO_WAIT   = 3'd2;
    localparam S_WRITEBACK = 3'd3;
    localparam S_HALTED    = 3'd4;

    reg [2:0] state, next_state;

    // Latched instruction control fields during FETCH
    reg [3:0] opcode_r;
    reg [2:0] cond_r;

    // Branch decision per Section 3.3
    // flags layout: {Z, N, C, V} -> flags[3]=Z, flags[2]=N, flags[1]=C, flags[0]=V
    reg branch_taken;
    always @(*) begin
        case (cond_r)
            3'b000: branch_taken = flags[3];         // BEQ: Z=1
            3'b001: branch_taken = ~flags[3];        // BNE: Z=0
            3'b010: branch_taken = flags[1];         // BCS: C=1
            3'b011: branch_taken = ~flags[1];        // BCC: C=0
            3'b100: branch_taken = flags[2];         // BMI: N=1
            3'b101: branch_taken = ~flags[2];        // BPL: N=0
            3'b110: branch_taken = flags[0];         // BVS: V=1
            3'b111: branch_taken = ~flags[0];        // BVC: V=0
            default: branch_taken = 1'b0;
        endcase
    end

    // State register and field latch
    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_FETCH;
            opcode_r <= 4'h0;
            cond_r   <= 3'b0;
        end else begin
            state <= next_state;
            if (state == S_FETCH) begin
                opcode_r <= opcode;
                cond_r   <= cond;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_FETCH: begin
                next_state = S_EXECUTE;
            end

            S_EXECUTE: begin
                if (opcode_r == OP_IO && !io_ready)
                    next_state = S_IO_WAIT;
                else
                    next_state = S_WRITEBACK;
            end

            S_IO_WAIT: begin
                if (io_ready)
                    next_state = S_WRITEBACK;
                else
                    next_state = S_IO_WAIT;
            end

            S_WRITEBACK: begin
                if (opcode_r == OP_HLT)
                    next_state = S_HALTED;
                else
                    next_state = S_FETCH;
            end

            S_HALTED: begin
                next_state = S_HALTED;
            end

            default: next_state = S_FETCH;
        endcase
    end

    // Datapath control output logic
    always @(*) begin
        pc_en    = 1'b0;
        pc_load  = 1'b0;
        rf_we    = 1'b0;
        mem_we   = 1'b0;
        io_rd    = 1'b0;
        io_wr    = 1'b0;
        flags_we = 1'b0;
        wb_sel   = 2'b00;
        halted   = 1'b0;
        retire   = 1'b0;

        case (state)
            S_FETCH: begin
                // Fetching instruction; nothing active
            end

            S_EXECUTE, S_IO_WAIT: begin
                // Hold I/O bus requests during EXECUTE and IO_WAIT until io_ready
                if (opcode_r == OP_IO) begin
                    if (cond_r[0] == 1'b0)
                        io_rd = 1'b1;
                    else
                        io_wr = 1'b1;
                end
            end

            S_WRITEBACK: begin
                retire = 1'b1;

                case (opcode_r)
                    OP_NOP: begin
                        pc_en = 1'b1;
                    end

                    OP_LDI: begin
                        rf_we  = 1'b1;
                        wb_sel = 2'd2;  // imm8
                        pc_en  = 1'b1;
                    end

                    OP_LD: begin
                        rf_we  = 1'b1;
                        wb_sel = 2'd1;  // DMEM
                        pc_en  = 1'b1;
                    end

                    OP_ST: begin
                        mem_we = 1'b1;
                        pc_en  = 1'b1;
                    end

                    OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_SHL, OP_SHR: begin
                        rf_we    = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'd0;  // ALU
                        pc_en    = 1'b1;
                    end

                    OP_CMP: begin
                        flags_we = 1'b1;
                        // rf_we = 0; CMP writes no register
                        pc_en    = 1'b1;
                    end

                    OP_JMP: begin
                        pc_en   = 1'b1;
                        pc_load = 1'b1;
                    end

                    OP_BCC: begin
                        pc_en   = 1'b1;
                        pc_load = branch_taken;
                    end

                    OP_IO: begin
                        if (cond_r[0] == 1'b0) begin
                            // IN
                            rf_we  = 1'b1;
                            wb_sel = 2'd3;  // io_rdata
                        end
                        // OUT writes no register
                        pc_en = 1'b1;
                    end

                    OP_HLT: begin
                        // Retire pulse emitted, PC holds its address, halted asserted thereafter
                        pc_en  = 1'b0;
                    end

                    default: begin
                        pc_en = 1'b1;
                    end
                endcase
            end

            S_HALTED: begin
                halted = 1'b1;
            end

            default: ;
        endcase
    end

endmodule
