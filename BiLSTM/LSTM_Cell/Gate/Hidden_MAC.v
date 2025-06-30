module hidden_mac_unit #(
    parameter DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH = 32,
    parameter ADDR_WIDTH_A = 8,
    parameter ADDR_WIDTH_B = 14,
    parameter COLS_A = 100,
    parameter COLS_B = 100,
    parameter CHUNK_SIZE = 4,      // Process 10 elements at a time
    parameter BURST_WIDTH = 2,
    parameter FRAC_SZ = 10
)(
    input wire clk,
    input wire rst,
    input wire start,

    input wire signed [DATA_WIDTH*CHUNK_SIZE/2-1:0] hidden_element_A1,
    input wire signed [DATA_WIDTH*CHUNK_SIZE/2-1:0] hidden_element_B1,

    output reg [ADDR_WIDTH_A-2:0] hidden_Pointer_matrixA,
    output reg [ADDR_WIDTH_B-2:0] hidden_Pointer_matrixB,

    // output reg signed [OUTPUT_WIDTH*COLS_B-1:0] result,
    output reg signed [OUTPUT_WIDTH-1:0] out_element,
    
    output reg read_enable,
    output reg valid,
    output reg done
);

    reg signed [OUTPUT_WIDTH-1:0] result_acc;
    reg [3:0] state;
    reg [6:0] chunk_idx;
    reg [6:0] col_idx;

    localparam IDLE  = 0,
               LOAD  = 1,
               CALC  = 2,
               STORE = 3,
               DONE  = 4;

    integer i;
    reg signed [DATA_WIDTH-1:0] A_vals [0:CHUNK_SIZE/2-1];
    reg signed [DATA_WIDTH-1:0] B_vals [0:CHUNK_SIZE/2-1];
    reg signed [OUTPUT_WIDTH-1:0] partial_products [0:CHUNK_SIZE/2-1];

    // Unpack 10 inputs (5 from each port)
    always @(*) begin
        for (i = 0; i < CHUNK_SIZE/2; i = i + 1) begin
            A_vals[i] = hidden_element_A1[DATA_WIDTH*(CHUNK_SIZE/2 - 1 - i) +: DATA_WIDTH];
            B_vals[i] = hidden_element_B1[DATA_WIDTH*(CHUNK_SIZE/2 - 1 - i) +: DATA_WIDTH];
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            read_enable <= 0;
            valid <= 0;
            done <= 0;
            // result <= 0;
            out_element <= 0;
            hidden_Pointer_matrixA <= 0;
            hidden_Pointer_matrixB <= 0;
            result_acc <= 0;
            chunk_idx <= 0;
            col_idx <= 0;
             for (i = 0; i < CHUNK_SIZE/2; i = i + 1) begin
                        partial_products[i] <=0;
                    end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        result_acc <= 0;
                        chunk_idx <= 0;
                        col_idx <= 0;
                        hidden_Pointer_matrixA <= 0;
                        hidden_Pointer_matrixB <= 0;
                        read_enable <= 1;
                        state <= LOAD;
                    end
                    valid <= 0;
                    done <= 0;
                end
                LOAD: begin
                    read_enable <= 1;
                    hidden_Pointer_matrixA <= hidden_Pointer_matrixA + 1;
                    hidden_Pointer_matrixB <= hidden_Pointer_matrixB + 1;
                    state <= CALC;
                end
             CALC: begin
                    read_enable <= 1;
                    chunk_idx <= chunk_idx + 1;
                    for (i = 0; i < CHUNK_SIZE/2; i = i + 1) begin
                        partial_products[i] <= A_vals[i] * B_vals[i];
                    end
                    result_acc <= result_acc +  partial_products[0] + partial_products[1];

                    if ((chunk_idx+1) * CHUNK_SIZE/2 <COLS_A) begin
                        hidden_Pointer_matrixA <= hidden_Pointer_matrixA + 1;
                        hidden_Pointer_matrixB <= hidden_Pointer_matrixB + 1;
                    end 
                    else if ((chunk_idx+1) * CHUNK_SIZE/2 ==COLS_A) begin
                        hidden_Pointer_matrixA <= 0 ;
                        hidden_Pointer_matrixB <= hidden_Pointer_matrixB ;
                    end else begin
                        chunk_idx <= 0;
                        out_element <= result_acc + partial_products[0] + partial_products[1]; 
                        hidden_Pointer_matrixA <= 0;
                        //hidden_Pointer_matrixB <=hidden_Pointer_matrixB + 1;
                        valid <= 1;
                         result_acc <= 0;
                        read_enable <= 1;
                        state <= STORE;
                    end
                end

                STORE: begin
                    valid <= 0;
                    for (i = 0; i < CHUNK_SIZE/2; i = i + 1) begin
                        partial_products[i] <= 0;
                    end
                    hidden_Pointer_matrixA <=0; 
                    if (col_idx < COLS_B) begin
                        col_idx <= col_idx + 1;
                        read_enable <= 1;
                        state <= LOAD;
                    end else begin
                        read_enable <= 0;
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
