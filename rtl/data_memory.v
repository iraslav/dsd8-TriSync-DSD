// =============================================================================
// Module: data_memory
// Owner:  Member C
// Description: 256 x 8-bit read/write data memory.
//              All 256 bytes cleared to 0x00 on reset (requirement R16).
//              Combinational read, synchronous write.
// =============================================================================

module data_memory (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  addr,
    input  wire        we,
    input  wire [7:0]  wdata,
    output wire [7:0]  rdata       // combinational read
);

    reg [7:0] mem [0:255];
    integer i;

    // Combinational read
    assign rdata = mem[addr];

    // Synchronous write with full reset clear
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 256; i = i + 1)
                mem[i] <= 8'b0;
        end else if (we) begin
            mem[addr] <= wdata;
        end
    end

endmodule
