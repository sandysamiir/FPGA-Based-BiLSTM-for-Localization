module EW_TOP #(
    parameter DATA_WIDTH = 16,
    parameter MULT_OUTPUT_WIDTH = 32,
    parameter FIFO_DEPTH = 128
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire cell_done,
    input wire signed [DATA_WIDTH-1:0] input1_a,
    input wire signed [DATA_WIDTH-1:0] input1_b,
    input wire signed [DATA_WIDTH-1:0] input2_a,
    input wire signed [DATA_WIDTH-1:0] input2_b,
    input wire signed [DATA_WIDTH-1:0] output_gate,
    output reg signed [DATA_WIDTH-1:0] hidden_state,
    output wire signed [DATA_WIDTH-1:0] current_cell_state,
    output wire hyperbolic_done,
    output wire cell_state_valid,
    output reg hidden_state_valid_out
);

    // Internal wires
    wire signed [MULT_OUTPUT_WIDTH-1:0] mult1_result, mult2_result;
    wire signed [MULT_OUTPUT_WIDTH-1:0] adder_result;
    wire signed [DATA_WIDTH-1:0] saturated_output1, saturated_output2;
    wire signed [DATA_WIDTH-1:0] activation_output;
    reg signed [MULT_OUTPUT_WIDTH-1:0] Saturation2_input;
    wire fifo_full, fifo_empty;
    wire fifo_wr_en, fifo_rd_en;
    wire mult_enable;
    wire mult1_done, mult2_done;
    wire sat1_enable, sat2_enable;
    wire start_hyp;
    wire signed [DATA_WIDTH-1:0] fifo_data_out;
    reg hidden_state_valid_reg;
    // Instantiate two multipliers
    fixed_point_multiplier #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(MULT_OUTPUT_WIDTH)
    ) multiplier1 (
        .clk(clk),
        .reset(rst),
        .enable(mult_enable),
        .a(input1_a),
        .b(input1_b),
        .result(mult1_result),
        .done(mult1_done)
    );

    fixed_point_multiplier #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_WIDTH(MULT_OUTPUT_WIDTH)
    ) multiplier2 (
        .clk(clk),
        .reset(rst),
        .enable(mult_enable),
        .a(input2_a),
        .b(input2_b),
        .result(mult2_result),
        .done(mult2_done)
    );

    // Instantiate the saturation module
    saturate_q8_24_to_q4_12 saturate1 (
        .clk(clk),
        .rst(rst),
        .enable(sat1_enable),
        .cell_done(cell_done),
        .in_q8_24(adder_result+32'sd512), // Add 512 to the result for saturation
        .out_q4_12(saturated_output1),
        .first_activation(), // Not used in this context
        .done(cell_state_valid)
    );

    // FIFO to store the saturated output
    FIFO #(
        .FIFO_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .wr_ack(),
        .overflow(),
        .full(fifo_full),
        .empty(fifo_empty),
        .almostfull(),
        .almostempty(),
        .underflow(),
        .data_in(saturated_output1), 
        .data_out(fifo_data_out)
    );

    // Instantiate the activation function (tanh)
    cordic_activation #(
        .WIDTH(DATA_WIDTH),
        .ITERATIONS(16),
        .FRAC_SZ(12)
    ) activation (
        .clk(clk),
        .reset(rst),
        .start_hyperbolic(start_hyp),
        .Z(fifo_data_out),
        .select(1'b0), // 0 for tanh
        .result(activation_output),
        .done(hyperbolic_done)
    );

    // Instantiate the second saturation module
    saturate_q8_24_to_q4_12 saturate2 (
        .clk(clk),
        .rst(rst),
        .enable(sat2_enable),
        .cell_done(cell_done),
        .in_q8_24(Saturation2_input+32'sd512), // Multiply with previous cell state
        .out_q4_12(saturated_output2), 
        .first_activation(), // Not used in this context
        .done(hidden_state_valid)
    );

    // Instantiate the control unit
    EW_Control_Unit control_unit (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mult_enable(mult_enable),
        .mult1_done(mult1_done),
        .mult2_done(mult2_done),
        .sat1_enable(sat1_enable),
        .sat1_done(cell_state_valid),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_wr_en(fifo_wr_en),
        .fifo_rd_en(fifo_rd_en),
        .start_hyp(start_hyp),
        .hyperbolic_done(hyperbolic_done),
        .sat2_enable(sat2_enable),
        .sat2_done(hidden_state_valid)
    );

    // Add the results of the two multipliers
    assign adder_result = mult1_result + mult2_result; 
    
    // Multiply with previous cell state
    //assign Saturation2_input = output_gate * activation_output; 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Saturation2_input <= 0;
        end else begin
           Saturation2_input <= output_gate * activation_output; // Q12.20 format
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hidden_state <= 0;
        end else if(hidden_state_valid_reg) begin
            hidden_state <= saturated_output2; // Q6.10 format
        end
    end
    //assign hidden_state = saturated_output2; // Output from the second saturation module
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hidden_state_valid_reg <= 0;
            hidden_state_valid_out<=0;
        end else begin
            hidden_state_valid_reg <= hidden_state_valid;
            hidden_state_valid_out<= hidden_state_valid_reg;
        end   
    end

    // Output from the first saturation module
    assign current_cell_state = saturated_output1; 
    // assign hidden_state = saturated_output2; // Output from the second saturation module

endmodule