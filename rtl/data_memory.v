// data_memory.v -- 256 x 8 read/write memory
// Owner: member C -- this is YOUR module; you are individually examined
// on it at the oral defence.
// Spec: Section 5.9. Port list is FROZEN -- note that it has no rst_n
// of its own, unlike every other stateful module in this design.
//
// R16: all 256 bytes shall clear to 0x00 by reset, so a read of a
// never-written location returns 0x00, not X. Test T09 checks this
// deliberately.
//
// Because this module has no reset input, "cleared by reset" has to
// come from somewhere else -- that is a genuine design decision worth
// recording in your design report (Section 9.3, item 4). Two
// legitimate answers: (a) initialise the memory array so it starts
// zeroed (works in every simulator, and on FPGA targets whose block
// RAM honours an initial value), or (b) have control_unit sequence 256
// writes of 0x00 through the ordinary we/addr/wdata ports before
// fetching the first real instruction. This stub does neither yet --
// choose one and implement it.

module data_memory (
    input  wire       clk,
    input  wire [7:0] addr,
    input  wire       we,
    input  wire [7:0] wdata,
    output wire [7:0] rdata     // combinational read
);

    reg [7:0] mem [0:255];

    always @(posedge clk) begin
        // TODO: if (we) mem[addr] <= wdata;
    end

    // TODO: assign rdata = mem[addr];
    assign rdata = 8'h00;

    // verilator lint_off UNUSEDSIGNAL
    wire [7:0] unused_addr  = addr;
    wire [7:0] unused_wdata = wdata;
    wire       unused_we    = we;
    // verilator lint_on UNUSEDSIGNAL

endmodule
