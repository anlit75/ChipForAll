module blinky #(
    parameter WIDTH = 26
)(
    input clk,
    input rst,
    output led
);

    reg [WIDTH-1:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
        end else begin
            count <= count + 1;
        end
    end

    assign led = count[WIDTH-1];

endmodule
