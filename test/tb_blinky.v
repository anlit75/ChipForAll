`timescale 1ns/1ps

module tb_blinky;

    reg clk;
    reg rst;
    wire led;

    // Instantiate with a smaller width for simulation
    blinky #(.WIDTH(4)) uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    initial begin
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb_blinky);

        // Initialize signals
        clk = 0;
        rst = 1;

        // Apply reset
        #20 rst = 0;

        // Run simulation for enough cycles
        repeat (100) @(posedge clk);

        $finish;
    end

    // Clock generation
    always #5 clk = ~clk;

endmodule
