module cordic_div #(
    parameter WIDTH = 16,   // Fixed-point precision (Q4.12 format)
    parameter FRAC_SZ = 12  // Fractional part size
)(
    input wire clk,
    input wire reset,
    input wire start,  // Signal to start division
    input wire signed [WIDTH-1:0] numerator,   
    input wire signed [WIDTH-1:0] denominator, 
    output reg signed [WIDTH-1:0] quotient,    
    output reg done // Indicates division completion
);

    reg signed [2*WIDTH-1:0] num;  // Extended numerator
    reg signed [WIDTH-1:0] denom;
    reg signed [WIDTH:0] remainder;  // One extra bit for precision
    reg [5:0] count;  // Loop counter (max WIDTH+FRAC_SZ iterations)
    reg [2:0] state;  // One-hot encoding
    wire sign; // Store the sign of the result
    wire signed [WIDTH-1:0] rounded_quotient; // Temporary signal for rounding

    assign sign = numerator[WIDTH-1] ^ denominator[WIDTH-1]; // XOR for sign

    // State encoding
    localparam IDLE   = 3'b001;
    localparam DIVIDE = 3'b010;
    localparam DONE   = 3'b100;

    assign rounded_quotient = (remainder > (1 <<< FRAC_SZ)) ? quotient + 1 : quotient; // Rounding logic

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            quotient <= 0;
            num <= 0;
            denom <= 0;
            remainder <= 0;
            count<=0;
            done <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && denominator != 0) begin
                        num <= (numerator[WIDTH-1] ? -numerator : numerator) <<< FRAC_SZ; // Absolute value of numerator and scale
                        denom <= (denominator[WIDTH-1] ? -denominator : denominator); // Absolute value of denominator
                        remainder <= 0;
                        quotient <= 0;
                        count <= WIDTH << 1;
                        state <= DIVIDE;
                    end else if (denominator == 0) begin
                        quotient <= 0; // Handle divide-by-zero
                        state <= IDLE;
                    end else state <= IDLE;
                end

                DIVIDE: begin
                    if (count > 0) begin
                        remainder <= {remainder[WIDTH-1:0], num[2*WIDTH-1]}; // left Shift numerator into remainder
                        num <= num << 1;

                        if (remainder >= denom) begin
                            remainder <= remainder - denom;
                            quotient <= quotient + 1;
                        end else begin
                            quotient <= quotient << 1;
                            count <= count - 1;
                        end
                        
                    end else begin
                        quotient <= sign ? -rounded_quotient : rounded_quotient; // Restore sign
                        done <= 1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    if (!start) state <= IDLE; // Wait for reset signal
                end
            endcase
        end
    end

endmodule
