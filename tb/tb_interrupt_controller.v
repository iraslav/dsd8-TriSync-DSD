`timescale 1ns/1ps

module tb_interrupt_controller;

    reg        clk;
    reg        rst_n;
    reg  [7:0] io_port;
    reg  [7:0] io_wdata;
    wire [7:0] io_rdata;
    reg        io_rd;
    reg        io_wr;
    wire       io_ready;
    integer    errors;

    interrupt_controller dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .io_port  (io_port),
        .io_wdata (io_wdata),
        .io_rdata (io_rdata),
        .io_rd    (io_rd),
        .io_wr    (io_wr),
        .io_ready (io_ready)
    );

    always #5 clk = ~clk;

    task write_port;
        input [7:0] port;
        input [7:0] data;
        begin
            @(negedge clk);
            io_port = port;
            io_wdata = data;
            io_wr = 1'b1;
            @(posedge clk);
            #1;
            io_wr = 1'b0;
        end
    endtask

    task check_port;
        input [7:0] port;
        input [7:0] expected;
        input [8*48-1:0] label_text;
        begin
            io_port = port;
            io_rd = 1'b1;
            #1;
            if (io_rdata !== expected) begin
                $display("FAIL: %0s expected %02X, got %02X",
                         label_text, expected, io_rdata);
                errors = errors + 1;
            end
            io_rd = 1'b0;
        end
    endtask

    task check_equal;
        input [7:0] actual;
        input [7:0] expected;
        input [8*48-1:0] label_text;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s expected %02X, got %02X",
                         label_text, expected, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        io_port = 8'h00;
        io_wdata = 8'h00;
        io_rd = 1'b0;
        io_wr = 1'b0;
        errors = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        check_port(8'h58, 8'h00, "reset IRQ status");
        check_equal(io_ready, 1'b1, "always-ready interface");

        write_port(8'h5A, 8'h0F);
        write_port(8'h52, 8'h03);
        write_port(8'h53, 8'h00);
        write_port(8'h5C, 8'h01);
        repeat (3) @(posedge clk);
        #1;
        check_port(8'h50, 8'h03, "Timer A count-up value");
        check_port(8'h58, 8'h11, "Timer A sticky match");
        check_port(8'h5B, 8'h00, "Timer A priority");

        write_port(8'h59, 8'h01);
        check_port(8'h58, 8'h00, "Timer A clear");
        check_port(8'h50, 8'h04, "Timer A continues after clear");
        check_port(8'h58, 8'h00, "Timer A does not repeat at match");

        write_port(8'h56, 8'h02);
        write_port(8'h57, 8'h00);
        write_port(8'h5C, 8'h38);
        repeat (2) @(posedge clk);
        #1;
        check_port(8'h54, 8'h00, "Timer B countdown terminal value");
        check_port(8'h58, 8'h12, "Timer B countdown interrupt");
        check_port(8'h5B, 8'h01, "Timer B priority");

        write_port(8'h5D, 8'h01);
        write_port(8'h5E, 8'h01);
        check_port(8'h58, 8'h1E, "event and manual flags");
        write_port(8'h59, 8'h02);
        check_port(8'h5B, 8'h02, "event priority after Timer B clear");
        write_port(8'h59, 8'h04);
        check_port(8'h5B, 8'h03, "manual priority after event clear");
        write_port(8'h59, 8'h08);
        check_port(8'h58, 8'h00, "all interrupt sources cleared");

        write_port(8'h50, 8'h00);
        write_port(8'h51, 8'h00);
        write_port(8'h52, 8'h01);
        write_port(8'h5A, 8'h0E);
        write_port(8'h5C, 8'h01);
        repeat (1) @(posedge clk);
        #1;
        check_port(8'h58, 8'h00, "masked Timer A source");
        write_port(8'h5A, 8'h0F);
        write_port(8'h50, 8'h00);
        repeat (1) @(posedge clk);
        #1;
        check_port(8'h58, 8'h11, "Timer A flag after re-enabling");
        write_port(8'h5A, 8'h0E);
        check_port(8'h58, 8'h01, "masked latched flag");
        write_port(8'h5A, 8'h0F);
        check_port(8'h58, 8'h11, "unmasked latched flag");
        write_port(8'h59, 8'h01);
        check_port(8'h58, 8'h00, "clear unmasked Timer A flag");

        if (errors == 0)
            $display("PASS: tb_interrupt_controller");
        else
            $fatal(1, "FAIL: tb_interrupt_controller had %0d error(s)", errors);
        $finish;
    end

endmodule
