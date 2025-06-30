module input_mac_unit #(
    parameter DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH = 32, // New parameter for output width
    parameter ADDR_WIDTH = 3, // Matrix A: 8 locations
    parameter WEIGHT_ADDR_WIDTH = 10,  // Matrix B: 16K locations
    parameter ROWS_A = 1, 
    parameter COLS_A = 6, 
    parameter ROWS_B = 6, 
    parameter COLS_B = 100,
    parameter FRAC_SZ = 10  // Fractional part size for Q6.10
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] matrix_A_element, // 1x6 matrix
    input wire signed [DATA_WIDTH-1:0] matrix_B_element, // 6x100 matrix
    output reg [ADDR_WIDTH-1:0] input_Pointer_matrixA, // pointer to next element in MatrixA
    output reg [WEIGHT_ADDR_WIDTH-1:0] input_Pointer_matrixB, // pointer to next element in MatrixB
    // output reg signed [OUTPUT_WIDTH*COLS_B-1:0] result, // 1x100 matrix output in Q12.20 format
    output reg signed [OUTPUT_WIDTH-1:0] out_element, // Register for immediate output
    output reg read_enable,
    output reg valid, // Indicates when an element is ready
    output reg done
);
    reg signed [OUTPUT_WIDTH-1:0] result_acc; // Wider for Q12.20
    reg signed [OUTPUT_WIDTH-1:0] partial_result; // Wider for Q12.20
    reg [6:0] col;
    reg [3:0] k;
    reg [3:0] state;
    localparam IDLE = 0, LOAD = 1, CALC = 2, STORE_RESULT = 3, DONE = 4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            out_element <= 0;
            valid <= 0;
            done <= 0;
            col <= 0;
            k <= 0;
            read_enable <= 0;
            input_Pointer_matrixA <= 0;
            input_Pointer_matrixB <= 0;
            result_acc <= 0;
            partial_result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    partial_result <= 0;
                    if (start) begin
                        state <= LOAD;
                        col <= 0;
                        k <= 0;
                        read_enable <= 1;
                        result_acc <= 0;
                    end
                    done <= 0;
                    input_Pointer_matrixA <= 0;
                    input_Pointer_matrixB <= 0;
                end

                LOAD: begin
                    read_enable <= 0;
                    state <= CALC;
                end

                CALC: begin
                    partial_result <= matrix_A_element * matrix_B_element; // Use registered signals
                    result_acc <= result_acc + partial_result;
                    if (k < COLS_A) begin
                        input_Pointer_matrixA <= input_Pointer_matrixA + 1;
                        input_Pointer_matrixB <= input_Pointer_matrixB + 1;
                        read_enable <= 1;
                        k <= k + 1;
                        state <= LOAD;
                    end else begin
                        k <= 0;
                        result_acc <= 0;
                        partial_result <= 0;
                        input_Pointer_matrixA <= 0;
                        out_element <= result_acc + partial_result; // Final product
                        valid <= 1;
                        state <= STORE_RESULT;
                    end
                end

                STORE_RESULT: begin
                    // result[col * OUTPUT_WIDTH +: OUTPUT_WIDTH] <= out_element;
                    valid <= 0;
                    read_enable <= 0;
                    input_Pointer_matrixA <= 0;
                    if (col < COLS_B-1) begin
                        col <= col + 1;
                        input_Pointer_matrixA <= 0;
                        read_enable <= 1;
                        state <= LOAD;
                        valid <= 0;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule