// peripherals.v -- reference behavioural models for UART, timer and
// SLOW_ECHO (Section 7.2's standard port map, ports 0x20-0x40).
//
// The spec is explicit that these are supplied so that "a fault in a
// peripheral cannot masquerade as a fault in your processor" -- they
// live in sim/, are never synthesised, and are the same for every
// team. They plug into the peripheral-facing side of your own io_bus
// (rtl/io_bus.v), which decodes ports 0x00-0x1F (switches/buttons/LEDs/
// seven-segment) itself and forwards everything from 0x20 up here.
//
// Two honest limitations, called out rather than hidden:
//   - the UART model never has a byte waiting to receive (UART_RX
//     always reads 0x00, UART_STATUS.rx_valid is always 0). Testing a
//     real receive path needs a stimulus driver this template does not
//     include; replace this model if your course exercises UART_RX.
//   - SLOW_ECHO's 0-7 cycle stall is generated from a free-running
//     counter sampled at the start of each request, not a true random
//     number generator. It is deterministic given the same program and
//     timing, but still varies request to request -- enough to exercise
//     the io_ready handshake (Section 7.1, R19-R20) without depending
//     on a particular Verilog dialect's random-number system tasks.

module dsd8_ref_peripherals (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] periph_port,
    input  wire [7:0] periph_wdata,
    output reg  [7:0] periph_rdata,
    input  wire       periph_rd,
    input  wire       periph_wr,
    output reg        periph_ready
);

    wire request = periph_rd | periph_wr;

    // ---- free-running counter, used only to vary SLOW_ECHO's delay ----
    reg [2:0] free_counter;
    always @(posedge clk) begin
        if (!rst_n) free_counter <= 3'b000;
        else        free_counter <= free_counter + 3'b001;
    end

    // ---- timer model: ports 0x30 (read count) / 0x31 (write control) ----
    reg [7:0] timer_count;
    reg       timer_enable;
    always @(posedge clk) begin
        if (!rst_n) begin
            timer_count  <= 8'h00;
            timer_enable <= 1'b0;
        end else if (periph_wr && periph_port == 8'h31) begin
            timer_enable <= periph_wdata[0];
            if (periph_wdata[1]) timer_count <= 8'h00;
        end else if (timer_enable) begin
            timer_count <= timer_count + 8'h01;
        end
    end

    // ---- SLOW_ECHO model: port 0x40, holds ready low for 0-7 cycles ----
    reg [7:0] slow_echo_value;
    reg [2:0] slow_echo_delay;
    reg       slow_echo_busy;
    wire      is_slow_echo = (periph_port == 8'h40);

    always @(posedge clk) begin
        if (!rst_n) begin
            slow_echo_busy  <= 1'b0;
            slow_echo_delay <= 3'h0;
            slow_echo_value <= 8'h00;
        end else if (is_slow_echo && request && !slow_echo_busy) begin
            slow_echo_busy  <= 1'b1;
            slow_echo_delay <= free_counter;              // 0-7, varies per request
            if (periph_wr) slow_echo_value <= periph_wdata;
        end else if (slow_echo_busy) begin
            if (slow_echo_delay == 3'h0) slow_echo_busy <= 1'b0;
            else                         slow_echo_delay <= slow_echo_delay - 3'h1;
        end
    end

    // ---- port decode / response (Section 7.2) ----
    always @(*) begin
        periph_rdata = 8'h00;
        periph_ready = 1'b0;
        if (request) begin
            case (periph_port)
                8'h20: periph_ready = 1'b1;                                    // UART_TX: accepted immediately
                8'h21: begin periph_rdata = 8'h00; periph_ready = 1'b1; end    // UART_RX: never a byte waiting
                8'h22: begin periph_rdata = 8'h00; periph_ready = 1'b1; end    // UART_STATUS: tx_busy=0, rx_valid=0
                8'h30: begin periph_rdata = timer_count; periph_ready = 1'b1; end
                8'h31: periph_ready = 1'b1;
                8'h40: begin
                    periph_rdata = slow_echo_value;
                    periph_ready = slow_echo_busy && (slow_echo_delay == 3'h0);
                end
                default: periph_ready = 1'b1;   // unmapped: reads 0x00, writes discarded, never stalls
            endcase
        end
    end

endmodule
