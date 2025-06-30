// MAC Unit: Multiply-Accumulate
// This module computes: acc_out = acc_in + (a * b)
// Parameterized for data width and accumulator width.
module MAC_UNIT #(
    parameter DATA_WIDTH = 16,    // Width of input operands a and b
    parameter ACC_WIDTH  = 32     // Width of accumulator output
) (
    input  logic                      clk,       // Clock
    input  logic                      rst,     // Active-low synchronous reset
    input  logic                      en,        // Enable signal: one MAC operation per cycle when high
    input  logic signed [DATA_WIDTH-1:0] a,       // Operand A
    input  logic signed [DATA_WIDTH-1:0] b,       // Operand B
    input  logic signed [ACC_WIDTH-1:0]  acc_in,  // Input accumulator value
    output logic signed [ACC_WIDTH-1:0]  acc_out  // Output accumulator value
);
    // Internal signal for product
    logic signed [2*DATA_WIDTH-1:0] mult;
    // Compute multiplication combinationally
    always_comb begin
        mult = a * b;
    end
    // Accumulator register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_out <= '0;
        end else if (en) begin
            // Truncate or extend product to ACC_WIDTH
            acc_out <= acc_in + mult;
        end else begin
            acc_out <= acc_out;
        end
    end
endmodule


