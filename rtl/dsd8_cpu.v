// =============================================================================
// Module: dsd8_cpu
// Owner:  Shared
// Description: The DSD-8 processor core. Instantiates all internal modules
//              (PC, decoder, register file, ALU, flags, data memory, control
//              unit) and wires them together. Exposes the retire_* trace
//              interface for conformance verification per Section 5.2 & 8.2.
// =============================================================================

module dsd8_cpu (
    input  wire        clk,
    input  wire        rst_n,
    // ---- instruction fetch interface ----
    output wire [8:0]  imem_addr,   // program counter
    input  wire [15:0] imem_data,   // instruction word, valid combinationally
    // ---- I/O bus (see section 7) ----
    output wire [7:0]  io_port,     // port number from the instruction
    output wire [7:0]  io_wdata,    // data for OUT
    input  wire [7:0]  io_rdata,    // data for IN
    output wire        io_rd,       // asserted for one access during IN
    output wire        io_wr,       // asserted for one access during OUT
    input  wire        io_ready,    // peripheral ready; low stalls the CPU
    // ---- status and trace ----
    output wire        halted,
    output wire        retire,      // one pulse per retired instruction
    output wire [8:0]  retire_pc,   // PC of the instruction just retired
    output wire [15:0] retire_ir,   // its instruction word
    output wire        retire_rf_we,
    output wire [2:0]  retire_rf_addr,
    output wire [7:0]  retire_rf_data,
    output wire        retire_mem_we,
    output wire [7:0]  retire_mem_addr,
    output wire [7:0]  retire_mem_data,
    output wire [3:0]  retire_flags  // {Z,N,C,V} after the instruction
);

    // =========================================================================
    // Program Counter
    // =========================================================================
    wire [8:0] pc_out;
    wire       pc_en_w;
    wire       pc_load_w;
    wire [8:0] branch_target;

    prog_counter u_pc (
        .clk        (clk),
        .rst_n      (rst_n),
        .pc_en      (pc_en_w),
        .pc_load    (pc_load_w),
        .branch_addr(branch_target),
        .pc         (pc_out)
    );

    assign imem_addr = pc_out;

    // =========================================================================
    // Fetch tracking & Instruction Register
    // =========================================================================
    reg [15:0] instr_reg;
    reg [8:0]  pc_reg;
    reg        in_fetch;

    wire cu_retire;

    always @(posedge clk) begin
        if (!rst_n) begin
            in_fetch  <= 1'b1;
            instr_reg <= 16'h0000;
            pc_reg    <= 9'h000;
        end else begin
            if (in_fetch) begin
                instr_reg <= imem_data;
                pc_reg    <= pc_out;
                in_fetch  <= 1'b0;
            end else if (cu_retire) begin
                in_fetch  <= 1'b1;
            end
        end
    end

    // =========================================================================
    // Instruction Decoder — decodes the latched instruction
    // =========================================================================
    wire [3:0] dec_opcode;
    wire [2:0] dec_rd, dec_rs1, dec_rs2, dec_cond;
    wire [7:0] dec_imm8, dec_port;
    wire [8:0] dec_addr9;
    wire       dec_io_dir;

    instr_decoder u_decoder (
        .instr  (instr_reg),
        .opcode (dec_opcode),
        .rd     (dec_rd),
        .rs1    (dec_rs1),
        .rs2    (dec_rs2),
        .imm8   (dec_imm8),
        .addr9  (dec_addr9),
        .cond   (dec_cond),
        .port   (dec_port),
        .io_dir (dec_io_dir)
    );

    assign branch_target = dec_addr9;

    // =========================================================================
    // Register File
    // =========================================================================
    wire [7:0] rf_rd1, rf_rd2;
    wire       rf_we_w;
    wire [7:0] rf_wd_w;
    wire [1:0] wb_sel;

    // Read port 2 addressing per §6.3 (R18):
    //   ST: data to store comes from rd
    //   OUT: data to output comes from rd/rs
    //   R-type: second operand from rs2
    wire [2:0] rf_ra2_mux;
    assign rf_ra2_mux = (dec_opcode == 4'h3) ? dec_rd :
                        (dec_opcode == 4'hE && dec_io_dir) ? dec_rd :
                        dec_rs2;

    register_file u_regfile (
        .clk  (clk),
        .rst_n(rst_n),
        .ra1  (dec_rs1),
        .ra2  (rf_ra2_mux),
        .rd1  (rf_rd1),
        .rd2  (rf_rd2),
        .we   (rf_we_w),
        .wa   (dec_rd),
        .wd   (rf_wd_w)
    );

    // =========================================================================
    // ALU
    // =========================================================================
    wire [7:0] alu_result;
    wire       alu_z, alu_n, alu_c, alu_v;

    alu u_alu (
        .a      (rf_rd1),
        .b      (rf_rd2),
        .op     (dec_opcode),
        .result (alu_result),
        .flag_z (alu_z),
        .flag_n (alu_n),
        .flag_c (alu_c),
        .flag_v (alu_v)
    );

    // =========================================================================
    // Flags Register
    // =========================================================================
    wire       flags_we_w;
    wire [3:0] flags_out;

    flags_reg u_flags (
        .clk      (clk),
        .rst_n    (rst_n),
        .flags_we (flags_we_w),
        .flags_in ({alu_z, alu_n, alu_c, alu_v}),
        .flags_out(flags_out)
    );

    // =========================================================================
    // Data Memory
    // =========================================================================
    wire       dmem_we_w;
    wire [7:0] dmem_rdata;

    data_memory u_dmem (
        .clk  (clk),
        .rst_n(rst_n),
        .addr (rf_rd1),     // address from rs1
        .we   (dmem_we_w),
        .wdata(rf_rd2),     // write data from rd (via ra2 mux)
        .rdata(dmem_rdata)
    );

    // Writeback mux: 0=ALU, 1=DMEM, 2=imm8, 3=io_rdata
    assign rf_wd_w = (wb_sel == 2'd0) ? alu_result :
                     (wb_sel == 2'd1) ? dmem_rdata :
                     (wb_sel == 2'd2) ? dec_imm8   :
                     /* 2'd3 */         io_rdata;

    // =========================================================================
    // Control Unit
    // Fed during FETCH from imem_data combinationally to eliminate 1-cycle latency
    // =========================================================================
    wire [3:0] cu_opcode_in = in_fetch ? imem_data[15:12] : dec_opcode;
    wire [2:0] cu_cond_in   = in_fetch ? 
                              ((imem_data[15:12] == 4'hE) ? {2'b00, imem_data[8]} : imem_data[11:9]) :
                              ((dec_opcode == 4'hE) ? {2'b00, dec_io_dir} : dec_cond);

    wire cu_halted;

    control_unit u_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .opcode   (cu_opcode_in),
        .cond     (cu_cond_in),
        .flags    (flags_out),
        .io_ready (io_ready),
        .pc_en    (pc_en_w),
        .pc_load  (pc_load_w),
        .rf_we    (rf_we_w),
        .mem_we   (dmem_we_w),
        .io_rd    (io_rd),
        .io_wr    (io_wr),
        .flags_we (flags_we_w),
        .wb_sel   (wb_sel),
        .halted   (cu_halted),
        .retire   (cu_retire)
    );

    // =========================================================================
    // I/O Bus assignments
    // =========================================================================
    assign io_port  = dec_port;
    assign io_wdata = rf_rd2;
    assign halted   = cu_halted;

    // =========================================================================
    // Retire / Execution Trace outputs per §8.2
    // =========================================================================
    assign retire          = cu_retire;
    assign retire_pc       = pc_reg;
    assign retire_ir       = instr_reg;
    assign retire_rf_we    = rf_we_w & cu_retire;
    assign retire_rf_addr  = (rf_we_w & cu_retire) ? dec_rd : 3'b0;
    assign retire_rf_data  = (rf_we_w & cu_retire) ? rf_wd_w : 8'h00;
    assign retire_mem_we   = dmem_we_w & cu_retire;
    assign retire_mem_addr = (dmem_we_w & cu_retire) ? rf_rd1 : 8'h00;
    assign retire_mem_data = (dmem_we_w & cu_retire) ? rf_rd2 : 8'h00;
    // Reflect flags after this instruction completed per §8.2 & Appendix C
    assign retire_flags    = flags_we_w ? {alu_z, alu_n, alu_c, alu_v} : flags_out;

endmodule
