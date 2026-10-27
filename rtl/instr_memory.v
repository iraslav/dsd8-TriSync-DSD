// =============================================================================
// Module: instr_memory
// Owner:  Member A
// Description: 512 x 16-bit read-only instruction memory (Harvard architecture).
//              Loaded at simulation start via $readmemh from a hex image file.
//              Combinational read — data is available in the same cycle as addr.
// =============================================================================

module instr_memory #(
    parameter IMAGE = "program.hex"  // hex image loaded with $readmemh
) (
    input  wire        clk,          // kept for port compliance
    input  wire [8:0]  addr,
    output wire [15:0] data          // combinational read
);

    reg [15:0] mem [0:511];
    integer i, fd;

    initial begin
        for (i = 0; i < 512; i = i + 1)
            mem[i] = 16'h0000;
        fd = $fopen(IMAGE, "r");
        if (fd != 0) begin
            $fclose(fd);
            $readmemh(IMAGE, mem);
        end
    end

    assign data = mem[addr];

endmodule
