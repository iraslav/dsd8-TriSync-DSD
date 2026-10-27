// =============================================================================
// Module: interrupt_controller
// Description: Polling-based timer/event peripheral for the DSD-8 I/O bus.
//              Kept separate from the frozen processor and I/O bus modules.
// =============================================================================

module interrupt_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] io_port,
    input  wire [7:0] io_wdata,
    output reg  [7:0] io_rdata,
    input  wire       io_rd,
    input  wire       io_wr,
    output wire       io_ready
);

    reg [15:0] timer_a_count;
    reg [15:0] timer_a_threshold;
    reg        timer_a_enable;
    reg        timer_a_mode;

    reg [15:0] timer_b_count;
    reg [15:0] timer_b_threshold;
    reg        timer_b_enable;
    reg        timer_b_mode;

    reg [3:0] irq_enable;
    reg [7:0] irq_vector_base;
    reg       timer_a_irq;
    reg       timer_b_irq;
    reg       event_irq;
    reg       manual_irq;

    wire timer_control_write = io_wr && (io_port == 8'h5C);
    wire timer_a_count_up_match =
        (timer_a_count + 16'h0001) == timer_a_threshold;
    wire timer_b_count_up_match =
        (timer_b_count + 16'h0001) == timer_b_threshold;
    wire irq_any_pending =
        (timer_a_irq && irq_enable[0]) |
        (timer_b_irq && irq_enable[1]) |
        (event_irq   && irq_enable[2]) |
        (manual_irq  && irq_enable[3]);
    wire [3:0] irq_source =
        (timer_a_irq && irq_enable[0]) ? 4'h0 :
        (timer_b_irq && irq_enable[1]) ? 4'h1 :
        (event_irq   && irq_enable[2]) ? 4'h2 :
        (manual_irq  && irq_enable[3]) ? 4'h3 :
                                         4'h0;

    assign io_ready = 1'b1;

    always @(*) begin
        case (io_port)
            8'h50: io_rdata = timer_a_count[7:0];
            8'h51: io_rdata = timer_a_count[15:8];
            8'h54: io_rdata = timer_b_count[7:0];
            8'h55: io_rdata = timer_b_count[15:8];
            8'h58: io_rdata = {3'b000, irq_any_pending, manual_irq,
                               event_irq, timer_b_irq, timer_a_irq};
            8'h5A: io_rdata = {irq_vector_base[7:4], irq_enable};
            8'h5B: io_rdata = {4'b0000, irq_source};
            default: io_rdata = 8'h00;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            timer_a_count     <= 16'h0000;
            timer_a_threshold <= 16'h0000;
            timer_a_enable    <= 1'b0;
            timer_a_mode      <= 1'b0;
            timer_b_count     <= 16'h0000;
            timer_b_threshold <= 16'h0000;
            timer_b_enable    <= 1'b0;
            timer_b_mode      <= 1'b0;
            irq_enable        <= 4'h0;
            irq_vector_base   <= 8'h00;
            timer_a_irq       <= 1'b0;
            timer_b_irq       <= 1'b0;
            event_irq         <= 1'b0;
            manual_irq        <= 1'b0;
        end else begin
            if (timer_a_enable && !timer_control_write) begin
                if (timer_a_mode) begin
                    if (timer_a_count == 16'h0001) begin
                        timer_a_count  <= 16'h0000;
                        timer_a_enable <= 1'b0;
                        if (irq_enable[0])
                            timer_a_irq <= 1'b1;
                    end else if (timer_a_count == 16'h0000) begin
                        timer_a_enable <= 1'b0;
                        if (irq_enable[0])
                            timer_a_irq <= 1'b1;
                    end else begin
                        timer_a_count <= timer_a_count - 16'h0001;
                    end
                end else begin
                    timer_a_count <= timer_a_count + 16'h0001;
                    if (timer_a_count_up_match && irq_enable[0])
                        timer_a_irq <= 1'b1;
                end
            end

            if (timer_b_enable && !timer_control_write) begin
                if (timer_b_mode) begin
                    if (timer_b_count == 16'h0001) begin
                        timer_b_count  <= 16'h0000;
                        timer_b_enable <= 1'b0;
                        if (irq_enable[1])
                            timer_b_irq <= 1'b1;
                    end else if (timer_b_count == 16'h0000) begin
                        timer_b_enable <= 1'b0;
                        if (irq_enable[1])
                            timer_b_irq <= 1'b1;
                    end else begin
                        timer_b_count <= timer_b_count - 16'h0001;
                    end
                end else begin
                    timer_b_count <= timer_b_count + 16'h0001;
                    if (timer_b_count_up_match && irq_enable[1])
                        timer_b_irq <= 1'b1;
                end
            end

            if (io_wr) begin
                case (io_port)
                    8'h50: timer_a_count[7:0] <= io_wdata;
                    8'h51: timer_a_count[15:8] <= io_wdata;
                    8'h52: timer_a_threshold[7:0] <= io_wdata;
                    8'h53: timer_a_threshold[15:8] <= io_wdata;
                    8'h54: timer_b_count[7:0] <= io_wdata;
                    8'h55: timer_b_count[15:8] <= io_wdata;
                    8'h56: timer_b_threshold[7:0] <= io_wdata;
                    8'h57: timer_b_threshold[15:8] <= io_wdata;
                    8'h59: begin
                        if (io_wdata[0])
                            timer_a_irq <= 1'b0;
                        if (io_wdata[1])
                            timer_b_irq <= 1'b0;
                        if (io_wdata[2])
                            event_irq <= 1'b0;
                        if (io_wdata[3])
                            manual_irq <= 1'b0;
                    end
                    8'h5A: begin
                        irq_enable      <= io_wdata[3:0];
                        irq_vector_base <= {io_wdata[7:4], 4'b0000};
                    end
                    8'h5C: begin
                        timer_a_enable <= io_wdata[0];
                        timer_a_mode   <= io_wdata[1];
                        timer_b_enable <= io_wdata[3];
                        timer_b_mode   <= io_wdata[4];
                        if (io_wdata[2])
                            timer_a_count <= timer_a_threshold;
                        if (io_wdata[5])
                            timer_b_count <= timer_b_threshold;
                    end
                    8'h5D: begin
                        if (io_wdata[0] && irq_enable[2])
                            event_irq <= 1'b1;
                    end
                    8'h5E: begin
                        if (io_wdata[0] && irq_enable[3])
                            manual_irq <= 1'b1;
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
