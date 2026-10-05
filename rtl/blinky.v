`timescale 1ns/1ps

// led is the top bit of a WIDTH-bit counter, so it changes every 2^(WIDTH-1)
// clock cycles. At the 10 ns clock in config.yaml that is 2^15 cycles, about
// 328 us: too fast to see, and small enough that the tests can wait for it on
// the gates. A real board clock needs a wider counter. At 100 MHz, WIDTH 26
// blinks at about 1.5 Hz and WIDTH 27 at about 0.75 Hz.
module blinky #(
    parameter WIDTH = 16
)(
    input wire clk,
    input wire rst,
    output wire led
);

    reg [WIDTH-1:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= {WIDTH{1'b0}};
        end else begin
            count <= count + 1'b1;
        end
    end

    assign led = count[WIDTH-1];

endmodule
