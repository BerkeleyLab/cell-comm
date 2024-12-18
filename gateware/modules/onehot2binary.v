module onehot2binary #(
    parameter WIDTH = 1,
    parameter LOG2_WIDTH = $clog2(WIDTH+1)
) (
    input wire        [WIDTH-1:0] onehot,
    output reg   [LOG2_WIDTH-1:0] binary
);

integer i;
always @* begin
    binary = 0;
    for (i = 0; i < WIDTH; i = i + 1) begin
        if (onehot[i])
            binary = i;
    end
end

endmodule
