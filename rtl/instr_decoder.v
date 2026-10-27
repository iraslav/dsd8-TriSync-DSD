// =============================================================================
// Module: instr_decoder
// Owner:  Member A
// Description: Purely combinational instruction decoder.
//              Splits the 16-bit instruction word into all possible fields.
//              The control unit decides which fields are meaningful based on
//              the opcode. Note the deliberate overlaps: rd/cond share bits
//              [11:9], imm8/port share bits [7:0], etc.
// =============================================================================

module instr_decoder (
    input  wire [15:0] instr,
    output wire [3:0]  opcode,  // instr[15:12]
    output wire [2:0]  rd,      // instr[11:9]
    output wire [2:0]  rs1,     // instr[8:6]
    output wire [2:0]  rs2,     // instr[5:3]
    output wire [7:0]  imm8,    // instr[7:0]
    output wire [8:0]  addr9,   // instr[8:0]
    output wire [2:0]  cond,    // instr[11:9]  (same bits as rd)
    output wire [7:0]  port,    // instr[7:0]   (same bits as imm8)
    output wire        io_dir   // instr[8]: 0 = IN, 1 = OUT
);

    assign opcode = instr[15:12];
    assign rd     = instr[11:9];
    assign rs1    = instr[8:6];
    assign rs2    = instr[5:3];
    assign imm8   = instr[7:0];
    assign addr9  = instr[8:0];
    assign cond   = instr[11:9];
    assign port   = instr[7:0];
    assign io_dir = instr[8];

endmodule
