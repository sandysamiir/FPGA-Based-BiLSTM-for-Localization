module LSTM_Gate_TOP #(
    parameter DATA_WIDTH = 16,
    parameter OUTPUT_WIDTH = 32,
    parameter FRAC_SZ = 10,
    parameter FIFO_DEPTH = 8,
    parameter input_ADDR_WIDTH = 3,
    parameter input_hidden_ADDR_WIDTH = 10,
    parameter input_READ_BURST = 1,
    parameter hidden_ADDR_WIDTH = 8,
    parameter hidden_hidden_ADDR_WIDTH = 14,
    parameter hidden_READ_BURST = 2,
    parameter CHUNK_SIZE = 4
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire cell_done,
    input wire bilstm_done,
    input wire signed [DATA_WIDTH*input_READ_BURST-1:0] input_element_A,
    input wire signed [DATA_WIDTH*input_READ_BURST-1:0] input_element_B,
    input wire signed [DATA_WIDTH*hidden_READ_BURST-1:0] read_data_A1,
    input wire signed [DATA_WIDTH*hidden_READ_BURST-1:0] read_data_B1,
    input wire signed [DATA_WIDTH-1:0] bias_element, // Bias for the addition
    input wire select, // 0 for tanh, 1 for sigmoid
    output wire input_read_enable,
    output wire [input_ADDR_WIDTH-1:0] input_Pointer_matrixA,
    output wire [input_hidden_ADDR_WIDTH-1:0] input_Pointer_matrixB,
    output wire hidden_read_enable,
    output wire [(hidden_ADDR_WIDTH-2):0] hidden_Pointer_matrixA,
    output wire [(hidden_hidden_ADDR_WIDTH-2):0] hidden_Pointer_matrixB,
    output reg signed [15:0] final_output,
    output wire bias_read_enable,
    output reg [6:0] bias_pointer, // Pointer for bias memory
    output wire valid_out
);

    // Internal signals
    // wire signed [OUTPUT_WIDTH*100-1:0] input_mac_result;
    wire valid_x, input_mac_done;
    wire signed [OUTPUT_WIDTH-1:0] Z_x;
    //wire signed [OUTPUT_WIDTH*100-1:0] hidden_mac_result;
    wire valid_h, hidden_mac_done;
    wire mac_en;
    wire signed [OUTPUT_WIDTH-1:0] Z_h;
    wire signed [OUTPUT_WIDTH-1:0] mac_fifo_data_out;
    wire mac_fifo_empty, mac_fifo_full, mac_fifo_wr_en, mac_fifo_rd_en;
    reg signed [OUTPUT_WIDTH-1:0] addition_result;
    wire signed [DATA_WIDTH-1:0] saturated_result;
    wire sat_en;
    wire done_sat;
    wire signed [DATA_WIDTH-1:0] sat_fifo_data_out;
    wire sat_fifo_empty, sat_fifo_full, sat_fifo_wr_en, sat_fifo_rd_en;
    wire signed [DATA_WIDTH-1:0] activation_result;
    wire add_en;
    wire act_en;
    wire bias_en;
    reg first_activation_delayed; // To hold the delayed value of first activation
    //wire special_op;
    wire act_done;

    reg signed [DATA_WIDTH-1:0] bias_results; // To hold the bias results

    // Input MAC Unit
    input_mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .ADDR_WIDTH(input_ADDR_WIDTH),
        .WEIGHT_ADDR_WIDTH(input_hidden_ADDR_WIDTH),
        .ROWS_A(1),
        .COLS_A(6),
        .ROWS_B(6),
        .COLS_B(100),
        .FRAC_SZ(FRAC_SZ)
    ) input_mac_unit (
        .clk(clk),
        .rst(rst),
        .start(mac_en),
        .matrix_A_element(input_element_A), // Assuming READ_BURST = 1
        .matrix_B_element(input_element_B),
        .input_Pointer_matrixA(input_Pointer_matrixA),
        .input_Pointer_matrixB(input_Pointer_matrixB),
        // .result(input_mac_result),
        .out_element(Z_x),
        .read_enable(input_read_enable),
        .valid(valid_x),
        .done(input_mac_done)
    );


    // Hidden MAC Unit
    hidden_mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .ADDR_WIDTH_A(hidden_ADDR_WIDTH),
        .ADDR_WIDTH_B(hidden_hidden_ADDR_WIDTH),
        .COLS_A(100),
        .COLS_B(100),
        .CHUNK_SIZE(CHUNK_SIZE),
        .BURST_WIDTH(hidden_READ_BURST),
        .FRAC_SZ(FRAC_SZ)
    ) hidden_mac_inst (
        .clk(clk),
        .rst(rst),
        .start(mac_en),
        .hidden_element_A1(read_data_A1),
        .hidden_element_B1(read_data_B1),
        .hidden_Pointer_matrixA(hidden_Pointer_matrixA),
        .hidden_Pointer_matrixB(hidden_Pointer_matrixB),
        // .result(hidden_mac_result),
        .out_element(Z_h),
        .read_enable(hidden_read_enable),
        .valid(valid_h),
        .done(hidden_mac_done)
    );

    // Instantiate MAC FIFO
    FIFO #(
        .FIFO_WIDTH(OUTPUT_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) mac_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(mac_fifo_wr_en),
        .rd_en(mac_fifo_rd_en),
        .wr_ack(),
        .overflow(),
        .full(mac_fifo_full),
        .empty(mac_fifo_empty),
        .almostfull(),
        .almostempty(),
        .underflow(),
        .data_in(Z_x), 
        .data_out(mac_fifo_data_out)
    );

    // Instantiate Gate Control Unit
    gate_control_unit control_unit (
        .clk(clk),
        .rst(rst),
        .start_gate(start),
        .valid_x(valid_x),
        .valid_h(valid_h),
        .act_done(act_done),
        .mac_fifo_empty(mac_fifo_empty),
        .mac_fifo_full(mac_fifo_full),
        .sat_fifo_empty(sat_fifo_empty),
        .mac_en(mac_en),
        .mac_fifo_wr_en(mac_fifo_wr_en),
        .mac_fifo_rd_en(mac_fifo_rd_en),
        .sat_fifo_wr_en(sat_fifo_wr_en),
        .sat_fifo_rd_en(sat_fifo_rd_en),
        .sat_en(sat_en),
        .first_activation_reg(first_activation_delayed),
        .bilstm_done(bilstm_done),
        .add_en(add_en),
        .bias_en(bias_en),
        .act_en(act_en),
        //.special_op(special_op),
        .valid_out(valid_out)
    );

    // Instantiate Saturation Module
    saturate_q8_24_to_q4_12 saturate (
        .clk(clk),
        .rst(rst),
        .enable(sat_en),
        .cell_done(cell_done),
        .in_q8_24(addition_result),
        .out_q4_12(saturated_result),
        .first_activation(first_activation),
        .done(done_sat)
    );

    // Instantiate SAT FIFO
    FIFO #(
        .FIFO_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(64)
    ) sat_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(sat_fifo_wr_en),
        .rd_en(sat_fifo_rd_en),
        .wr_ack(),
        .overflow(),
        .full(sat_fifo_full),
        .empty(sat_fifo_empty),
        .almostfull(),
        .almostempty(),
        .underflow(),
        .data_in(bias_results), 
        .data_out(sat_fifo_data_out)
    );

    // Instantiate Activation Module
    cordic_activation #(
        .WIDTH(16),
        .ITERATIONS(16),
        .FRAC_SZ(FRAC_SZ)
    ) activation (
        .clk(clk),
        .reset(rst),
        .start_hyperbolic(act_en),
        .Z(sat_fifo_data_out),
        .select(select),
        .result(activation_result),
        .done(act_done)
    );
    assign bias_read_enable=sat_en; // Enable bias read when saturation is done
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addition_result <= 0;
        end else if (add_en) begin
            // Perform addition of input and input results
            addition_result <= mac_fifo_data_out + Z_h; // Q12.20 format
        end
    end
always @(posedge clk or posedge rst) begin
        if (rst) begin
            bias_results <= 0; // Reset to true on reset
            bias_pointer<=0;
            first_activation_delayed <= 0; // Reset first activation flag
        end else if (cell_done) begin
            bias_results <= 0; // Reset to true on reset
            bias_pointer<=0;
            first_activation_delayed <= 0; // Reset first activation flag
        end
        else if (bias_en) begin
            first_activation_delayed <= first_activation; 
            bias_results <= saturated_result+bias_element; // Set to false when start is triggered
            bias_pointer <= bias_pointer + 1; // Increment bias pointer
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            final_output <= 0;
        end else if (act_done) begin
            final_output <= activation_result; 
        end
    end

endmodule