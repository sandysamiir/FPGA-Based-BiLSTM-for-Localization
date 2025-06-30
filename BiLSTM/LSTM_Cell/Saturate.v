module saturate_q8_24_to_q4_12 (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    input  wire cell_done, 
    input  wire signed [31:0] in_q8_24,     // Q8.24 input
    output reg  signed [15:0] out_q4_12,     // Q4.12 output
    output reg first_activation,             // High for one cycle on first activation
    output reg done                          // High for one clock cycle when output is ready
);

    // Constants in Q8.24 format for saturation limits
    localparam signed [31:0] MAX_Q8_24 = 32'sd134213632;  // 7.9997 * (2^24)
    localparam signed [31:0] MIN_Q8_24 = -32'sd134217728; // -8 * (2^24)

    // Intermediate combinational result
    reg signed [15:0] out_q4_12_comb;
    reg done_comb;

    reg has_activated;         // Internal flag to track first activation
    reg first_activation_d;    // Delayed version to hold first_activation high for one more cycle
    reg done_comb_d;           // Delayed version of done_comb for edge detection

    // Combinational saturation logic
    always @(*) begin
        if (enable) begin
            if (in_q8_24 > MAX_Q8_24) begin
                out_q4_12_comb = 16'sd32767;
                done_comb = 1'b1;
            end
            else if (in_q8_24 < MIN_Q8_24) begin
                out_q4_12_comb = -16'sd32768;
                done_comb = 1'b1;
            end
            else begin
                out_q4_12_comb = in_q8_24 >>> 12; // Q8.24 to Q4.12
                done_comb = 1'b1;
            end
        end else begin
            out_q4_12_comb = out_q4_12; // Hold previous value logically
            done_comb = 1'b0;
        end
    end

    // Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_q4_12 <= 16'sd0;
            first_activation <= 1'b0;
            first_activation_d <= 1'b0;
            has_activated <= 1'b0;
            done <= 1'b0;
            done_comb_d <= 1'b0;
        end else begin
            out_q4_12 <= out_q4_12_comb;

            // Rising edge detection of done_comb to pulse done for one clock
            done <= done_comb & ~done_comb_d;
            done_comb_d <= done_comb;

            // One-cycle pulse on first activation
            if (cell_done) begin
                has_activated <= 1'b0; // Reset delayed activation on cell_done
            end
            else if (enable && !has_activated) begin
                first_activation <= 1'b1;
                first_activation_d <= 1'b1;
                has_activated <= 1'b1;
            end else begin
                first_activation <= first_activation_d;
                first_activation_d <= 1'b0;
            end

            // Reset first_activation if cell_done is high
        end
    end

endmodule

