module fixed_point_multiplier #(
    parameter DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  enable,
    input  wire signed [DATA_WIDTH-1:0] a,
    input  wire signed [DATA_WIDTH-1:0] b,
    output reg signed [OUTPUT_WIDTH-1:0] result,
    output reg done
);

    reg signed [OUTPUT_WIDTH-1:0] result_reg;
    reg done_comb;

    always @(*) begin
        if (enable) begin
            result_reg = a * b; // Perform multiplication when enabled
            done_comb = 1; // Indicate that multiplication is done
        end else begin
            result_reg = result; // Hold previous value when not enabled
            done_comb = 0; // Indicate that multiplication is not done
        end
    end
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 0; // Reset result to zero
            done <= 0; // Reset done signal
        end else begin
            result <= result_reg; // Update result on clock edge
            done <= done_comb; // Update done signal
        end
    end

endmodule
