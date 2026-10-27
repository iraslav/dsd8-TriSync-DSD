// =============================================================================
// Module: prog_counter
// Owner:  Member A
// Description: 9-bit program counter with increment and load capability.
//              On reset, PC = 0x000. When pc_en is high:
//                - pc_load=0 → PC increments (wraps within 9-bit range)
//                - pc_load=1 → PC loads branch_addr
// =============================================================================

module prog_counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_en,       // advance or load this cycle
    input  wire        pc_load,     // 1 = load branch_addr, 0 = increment
    input  wire [8:0]  branch_addr,
    output reg  [8:0]  pc
);

    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 9'b0;
        end else if (pc_en) begin
            if (pc_load)
                pc <= branch_addr;
            else
                pc <= pc + 9'b1;
        end
    end

endmodule
