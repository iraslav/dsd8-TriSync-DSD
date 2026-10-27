// =============================================================================
// Module: register_file
// Owner:  Member B
// Description: 8 x 8-bit general-purpose register file.
//              Two combinational read ports, one synchronous write port.
//              All registers cleared to 0x00 on reset.
//              Read-during-write returns the OLD value (write-first not used).
// =============================================================================

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  ra1,     // read address 1
    input  wire [2:0]  ra2,     // read address 2
    output wire [7:0]  rd1,     // combinational read data 1
    output wire [7:0]  rd2,     // combinational read data 2
    input  wire        we,      // write enable
    input  wire [2:0]  wa,      // write address
    input  wire [7:0]  wd       // write data
);

    reg [7:0] regs [0:7];
    integer i;

    // Combinational reads — return OLD value on simultaneous read/write
    assign rd1 = regs[ra1];
    assign rd2 = regs[ra2];

    // Synchronous write with reset
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1)
                regs[i] <= 8'b0;
        end else if (we) begin
            regs[wa] <= wd;
        end
    end

endmodule
