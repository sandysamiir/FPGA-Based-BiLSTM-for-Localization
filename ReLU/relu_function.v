module relu #(parameter WIDTH = 16) (
    input wire signed [WIDTH-1:0] in,  // 16-bit signed fixed-point input (Q4.12)
    output wire signed [WIDTH-1:0] out  // 16-bit signed fixed-point output (Q4.12)
);
    assign out = (in[WIDTH-1] == 1'b0) ? in : 'd0;  // If positive, keep value; else, output 0
endmodule