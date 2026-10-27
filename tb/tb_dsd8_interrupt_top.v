`timescale 1ns/1ps

module tb_dsd8_interrupt_top;

    reg        clk;
    reg        rst_n;
    reg  [7:0] switches;
    reg  [4:0] buttons;
    wire [7:0] leds;
    wire [6:0] seg;
    wire [3:0] an;
    wire       halted;
    integer    cycles;
    integer    errors;

    dsd8_interrupt_top #(.IMAGE("sim/interrupt_smoke.hex")) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .switches (switches),
        .buttons  (buttons),
        .leds     (leds),
        .seg      (seg),
        .an       (an),
        .halted   (halted)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        switches = 8'h00;
        buttons = 5'h00;
        cycles = 0;
        errors = 0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        while (!halted && cycles < 1000) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end

        if (!halted) begin
            $display("FAIL: CPU did not halt within 1000 cycles");
            errors = errors + 1;
        end
        if (leds !== 8'hA5) begin
            $display("FAIL: expected LED value A5, got %02X", leds);
            errors = errors + 1;
        end
        if (dut.u_interrupt_controller.timer_a_irq !== 1'b0) begin
            $display("FAIL: Timer A IRQ flag was not cleared by the program");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tb_dsd8_interrupt_top (%0d cycles)", cycles);
        else
            $fatal(1, "FAIL: tb_dsd8_interrupt_top had %0d error(s)", errors);
        $finish;
    end

endmodule
