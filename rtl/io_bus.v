// =============================================================================
// Module: io_bus
// Owner:  Member C
// Description: I/O bus controller with port address decode and io_ready
//              handshake. Maps the standard port addresses:
//                0x00 = SWITCHES (read)
//                0x01 = BUTTONS  (read)
//                0x02 = LEDS     (write, latched)
//                0x10 = SEG_VALUE (write)
//                0x11 = SEG_ENABLE (write)
//                0x40 = SLOW_ECHO (r/w, test peripheral with variable delay)
//              Unmapped read ports return 0x00; unmapped writes are discarded.
//              io_ready is always 1 for standard ports (no stall).
// =============================================================================

module io_bus (
    input  wire        clk,
    input  wire        rst_n,
    // CPU side
    input  wire [7:0]  io_port,
    input  wire [7:0]  io_wdata,
    output reg  [7:0]  io_rdata,
    input  wire        io_rd,
    input  wire        io_wr,
    output wire        io_ready,
    // Board I/O
    input  wire [7:0]  switches,
    input  wire [4:0]  buttons,
    output reg  [7:0]  leds,
    output reg  [6:0]  seg,
    output reg  [3:0]  an
);

    // --- SLOW_ECHO test peripheral ---
    reg [7:0] slow_echo_data;
    reg [2:0] slow_delay_counter;
    reg       slow_busy;

    // io_ready: low only when SLOW_ECHO is busy
    assign io_ready = ~slow_busy;

    // Combinational read mux based on io_port
    always @(*) begin
        case (io_port)
            8'h00: io_rdata = switches;
            8'h01: io_rdata = {3'b000, buttons};
            8'h40: io_rdata = slow_echo_data;
            default: io_rdata = 8'h00;
        endcase
    end

    // Write logic and SLOW_ECHO
    always @(posedge clk) begin
        if (!rst_n) begin
            leds               <= 8'h00;
            seg                <= 7'h00;
            an                 <= 4'h0;
            slow_echo_data     <= 8'h00;
            slow_delay_counter <= 3'b0;
            slow_busy          <= 1'b0;
        end else begin
            // SLOW_ECHO delay countdown
            if (slow_busy) begin
                if (slow_delay_counter == 3'b0)
                    slow_busy <= 1'b0;
                else
                    slow_delay_counter <= slow_delay_counter - 3'b1;
            end

            // Handle writes when io_ready is high
            if (io_wr && io_ready) begin
                case (io_port)
                    8'h02: leds <= io_wdata;
                    8'h10: seg  <= io_wdata[6:0];
                    8'h11: an   <= io_wdata[3:0];
                    8'h40: begin
                        slow_echo_data     <= io_wdata;
                        slow_delay_counter <= io_wdata[2:0];
                        slow_busy          <= (io_wdata[2:0] != 3'b0);
                    end
                    default: begin
                        // Unmapped — discard
                    end
                endcase
            end

            // SLOW_ECHO read delay trigger
            if (io_rd && io_ready && io_port == 8'h40) begin
                slow_delay_counter <= slow_echo_data[2:0];
                slow_busy          <= (slow_echo_data[2:0] != 3'b0);
            end
        end
    end

endmodule
