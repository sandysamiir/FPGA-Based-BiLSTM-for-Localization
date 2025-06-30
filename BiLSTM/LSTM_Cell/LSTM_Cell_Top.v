module LSTM_Cell_Top #(
    parameter DATA_WIDTH = 16,
    parameter MULT_OUTPUT_WIDTH = 32,
    parameter FRAC_SZ = 10,
    parameter FIFO_DEPTH = 128,
    parameter output_fifo_depth = 8,
    parameter INPUT_ADDR_WIDTH = 3,
    parameter INPUT_HIDDEN_ADDR_WIDTH = 10,
    parameter INPUT_READ_BURST = 1,
    parameter HIDDEN_ADDR_WIDTH = 8,
    parameter HIDDEN_HIDDEN_ADDR_WIDTH = 13,
    parameter HIDDEN_READ_BURST = 2,
    parameter CHUNK_SIZE = 4
 )(
    input wire clk,
    input wire rst,
    input wire start_cell,
    input wire bilstm_done,
    input wire [3:0] seq_idx_control, 
    input wire signed [DATA_WIDTH-1:0] prev_cell_state,
    input wire [DATA_WIDTH-1:0] input_element_input_gate, input_element_candidate_gate, input_element_forget_gate, input_element_output_gate,
    input wire [DATA_WIDTH-1:0] ih_input_element, ih_candidate_element, ih_forget_element, ih_output_element,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] hidden_data_1_input_gate,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] hidden_data_1_candidate_gate,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] hidden_data_1_forget_gate,   
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] hidden_data_1_output_gate,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] input_read_data_B1,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] candidate_read_data_B1,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] forget_read_data_B1,
    input wire [DATA_WIDTH*HIDDEN_READ_BURST-1:0] output_read_data_B1,
    input wire [DATA_WIDTH-1:0] input_gate_bias_element, candidate_gate_bias_element, forget_gate_bias_element, output_gate_bias_element,
    input wire cell_fifo_empty,
    output wire input_read_enable_input_gate, input_read_enable_candidate_gate, input_read_enable_forget_gate, input_read_enable_output_gate,
    output wire hidden_read_enable_input_gate, hidden_read_enable_candidate_gate, hidden_read_enable_forget_gate, hidden_read_enable_output_gate,
    output wire [INPUT_ADDR_WIDTH-1:0] input_Pointer_input_gate, input_Pointer_candidate_gate, input_Pointer_forget_gate, input_Pointer_output_gate,
    output wire [INPUT_HIDDEN_ADDR_WIDTH-1:0] ih_input_Pointer, ih_candidate_Pointer, ih_forget_Pointer, ih_output_Pointer,
    output wire [(HIDDEN_ADDR_WIDTH-2):0] hidden_Pointer_input_gate, hidden_Pointer_candidate_gate, hidden_Pointer_forget_gate, hidden_Pointer_output_gate,
    output wire [(HIDDEN_HIDDEN_ADDR_WIDTH-2):0] hh_input_Pointer, hh_candidate_Pointer, hh_forget_Pointer, hh_output_Pointer,
    output wire input_bias_read_enable, candidate_bias_read_enable, forget_bias_read_enable, output_bias_read_enable,
    output wire [6:0] input_bias_pointer, candidate_bias_pointer, forget_bias_pointer, output_bias_pointer,
    output wire signed [DATA_WIDTH-1:0] hidden_state,
    output wire signed [DATA_WIDTH-1:0] current_cell_state,
    output wire cell_state_valid,
    output wire hidden_state_valid,
    output wire cell_done,
    output wire cell_fifo_rd_en
 );
    // Internal signals
    wire start_gate, start_EW;
    wire signed [DATA_WIDTH-1:0] input_gate_output, candidate_gate_output, forget_gate_output, output_gate_output;
    wire signed [DATA_WIDTH-1:0] input_fifo_data_out, candidate_fifo_data_out, forget_fifo_data_out, output_fifo_data_out;
    wire input_fifo_full, input_fifo_empty, input_fifo_wr_en, input_fifo_rd_en;
    wire candidate_fifo_full, candidate_fifo_empty, candidate_fifo_wr_en, candidate_fifo_rd_en;
    wire hyperbolic_done;
    wire input_gate_valid, candidate_gate_valid, forget_gate_valid, output_gate_valid;

    // Registered start signal for gates
    reg start_gate_reg;
    // Registering read data
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start_gate_reg<=0;
        end else begin
            start_gate_reg <= start_gate;
        end
    end

    // Input Gate instantiation
    LSTM_Gate_TOP #(
        .DATA_WIDTH (DATA_WIDTH),
        .OUTPUT_WIDTH (MULT_OUTPUT_WIDTH),
        .FRAC_SZ (FRAC_SZ),
        .FIFO_DEPTH (FIFO_DEPTH),
        .input_ADDR_WIDTH (INPUT_ADDR_WIDTH),
        .input_hidden_ADDR_WIDTH (INPUT_HIDDEN_ADDR_WIDTH),
        .input_READ_BURST (INPUT_READ_BURST),
        .hidden_ADDR_WIDTH (HIDDEN_ADDR_WIDTH),
        .hidden_hidden_ADDR_WIDTH (HIDDEN_HIDDEN_ADDR_WIDTH),
        .hidden_READ_BURST (HIDDEN_READ_BURST),
        .CHUNK_SIZE (CHUNK_SIZE)
    )input_gate(
        .clk(clk),
        .rst(rst),
        .start(start_gate_reg),
        .cell_done(cell_done),
        .bilstm_done(bilstm_done),
        .input_element_A(input_element_input_gate),
        .input_element_B(ih_input_element),
        .read_data_A1(hidden_data_1_input_gate), 
        .read_data_B1(input_read_data_B1), 
        .bias_element(input_gate_bias_element),
        .bias_read_enable(input_bias_read_enable),
        .bias_pointer(input_bias_pointer),
        .select(1'b1), // 0 for tanh, 1 for sigmoid
        .input_read_enable(input_read_enable_input_gate),
        .input_Pointer_matrixA(input_Pointer_input_gate),
        .input_Pointer_matrixB(ih_input_Pointer),
        .hidden_read_enable(hidden_read_enable_input_gate),
        .hidden_Pointer_matrixA(hidden_Pointer_input_gate),
        .hidden_Pointer_matrixB(hh_input_Pointer),
        .final_output(input_gate_output),
        .valid_out(input_gate_valid)
    );

    // Candidate Gate instantiation
    LSTM_Gate_TOP #(
        .DATA_WIDTH (DATA_WIDTH),
        .OUTPUT_WIDTH (MULT_OUTPUT_WIDTH),
        .FRAC_SZ (FRAC_SZ),
        .FIFO_DEPTH (FIFO_DEPTH),
        .input_ADDR_WIDTH (INPUT_ADDR_WIDTH),
        .input_hidden_ADDR_WIDTH (INPUT_HIDDEN_ADDR_WIDTH),
        .input_READ_BURST (INPUT_READ_BURST),
        .hidden_ADDR_WIDTH (HIDDEN_ADDR_WIDTH),
        .hidden_hidden_ADDR_WIDTH (HIDDEN_HIDDEN_ADDR_WIDTH),
        .hidden_READ_BURST (HIDDEN_READ_BURST),
        .CHUNK_SIZE (CHUNK_SIZE)
    )candidate_gate(
        .clk(clk),
        .rst(rst),
        .start(start_gate_reg),
        .cell_done(cell_done),
        .bilstm_done(bilstm_done),
        .input_element_A(input_element_candidate_gate),
        .input_element_B(ih_candidate_element),
        .read_data_A1(hidden_data_1_candidate_gate), 
        .read_data_B1(candidate_read_data_B1), 
        .bias_element(candidate_gate_bias_element),
        .bias_read_enable(candidate_bias_read_enable),
        .bias_pointer(candidate_bias_pointer),
        .select(1'b0), // 0 for tanh, 1 for sigmoid
        .input_read_enable(input_read_enable_candidate_gate),
        .input_Pointer_matrixA(input_Pointer_candidate_gate),
        .input_Pointer_matrixB(ih_candidate_Pointer),
        .hidden_read_enable(hidden_read_enable_candidate_gate),
        .hidden_Pointer_matrixA(hidden_Pointer_candidate_gate),
        .hidden_Pointer_matrixB(hh_candidate_Pointer),
        .final_output(candidate_gate_output),
        .valid_out(candidate_gate_valid)
    );

    // Forget Gate instantiation
    LSTM_Gate_TOP #(
        .DATA_WIDTH (DATA_WIDTH),
        .OUTPUT_WIDTH (MULT_OUTPUT_WIDTH),
        .FRAC_SZ (FRAC_SZ),
        .FIFO_DEPTH (FIFO_DEPTH),
        .input_ADDR_WIDTH (INPUT_ADDR_WIDTH),
        .input_hidden_ADDR_WIDTH (INPUT_HIDDEN_ADDR_WIDTH),
        .input_READ_BURST (INPUT_READ_BURST),
        .hidden_ADDR_WIDTH (HIDDEN_ADDR_WIDTH),
        .hidden_hidden_ADDR_WIDTH (HIDDEN_HIDDEN_ADDR_WIDTH),
        .hidden_READ_BURST (HIDDEN_READ_BURST),
        .CHUNK_SIZE (CHUNK_SIZE)
    )forget_gate(
        .clk(clk),
        .rst(rst),
        .start(start_gate_reg),
        .cell_done(cell_done),
        .bilstm_done(bilstm_done),
        .input_element_A(input_element_forget_gate),
        .input_element_B(ih_forget_element),
        .read_data_A1(hidden_data_1_forget_gate), 
        .read_data_B1(forget_read_data_B1), 
        .bias_element(forget_gate_bias_element),
        .bias_read_enable(forget_bias_read_enable),
        .bias_pointer(forget_bias_pointer),
        .select(1'b1), // 0 for tanh, 1 for sigmoid
        .input_read_enable(input_read_enable_forget_gate),
        .input_Pointer_matrixA(input_Pointer_forget_gate),
        .input_Pointer_matrixB(ih_forget_Pointer),
        .hidden_read_enable(hidden_read_enable_forget_gate),
        .hidden_Pointer_matrixA(hidden_Pointer_forget_gate),
        .hidden_Pointer_matrixB(hh_forget_Pointer),
        .final_output(forget_gate_output),
        .valid_out(forget_gate_valid)
    );

    // Output Gate instantiation
    LSTM_Gate_TOP #(
        .DATA_WIDTH (DATA_WIDTH),
        .OUTPUT_WIDTH (MULT_OUTPUT_WIDTH),
        .FRAC_SZ (FRAC_SZ),
        .FIFO_DEPTH (FIFO_DEPTH),
        .input_ADDR_WIDTH (INPUT_ADDR_WIDTH),
        .input_hidden_ADDR_WIDTH (INPUT_HIDDEN_ADDR_WIDTH),
        .input_READ_BURST (INPUT_READ_BURST),
        .hidden_ADDR_WIDTH (HIDDEN_ADDR_WIDTH),
        .hidden_hidden_ADDR_WIDTH (HIDDEN_HIDDEN_ADDR_WIDTH),
        .hidden_READ_BURST (HIDDEN_READ_BURST),
        .CHUNK_SIZE (CHUNK_SIZE)
    )output_gate(
        .clk(clk),
        .rst(rst),
        .start(start_gate_reg),
        .cell_done(cell_done),
        .bilstm_done(bilstm_done),
        .input_element_A(input_element_output_gate),
        .input_element_B(ih_output_element),
        .read_data_A1(hidden_data_1_output_gate), 
        .read_data_B1(output_read_data_B1), 
        .bias_element(output_gate_bias_element),
        .bias_read_enable(output_bias_read_enable),
        .bias_pointer(output_bias_pointer),
        .select(1'b1), // 0 for tanh, 1 for sigmoid
        .input_read_enable(input_read_enable_output_gate),
        .input_Pointer_matrixA(input_Pointer_output_gate),
        .input_Pointer_matrixB(ih_output_Pointer),
        .hidden_read_enable(hidden_read_enable_output_gate),
        .hidden_Pointer_matrixA(hidden_Pointer_output_gate),
        .hidden_Pointer_matrixB(hh_output_Pointer),
        .final_output(output_gate_output),
        .valid_out(output_gate_valid)
    );

    // Input Gate FIFO instantiation
    FIFO #(
        .FIFO_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (output_fifo_depth)
    )input_fifo (
        .clk(clk), 
        .rst(rst), 
        .wr_en(input_fifo_wr_en), 
        .rd_en(input_fifo_rd_en), 
        .wr_ack(), 
        .overflow(), 
        .full(input_fifo_full), 
        .empty(input_fifo_empty), 
        .almostfull(), 
        .almostempty(), 
        .underflow(), 
        .data_in(input_gate_output), 
        .data_out(input_fifo_data_out)
    );

    // Candidate Gate FIFO instantiation
    FIFO #(
        .FIFO_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (output_fifo_depth)
    )candidate_fifo (
        .clk(clk), 
        .rst(rst), 
        .wr_en(candidate_fifo_wr_en), 
        .rd_en(candidate_fifo_rd_en), 
        .wr_ack(), 
        .overflow(), 
        .full(candidate_fifo_full), 
        .empty(candidate_fifo_empty), 
        .almostfull(), 
        .almostempty(), 
        .underflow(), 
        .data_in(candidate_gate_output), 
        .data_out(candidate_fifo_data_out)
    );

    // Forget Gate FIFO instantiation
    FIFO #(
        .FIFO_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (output_fifo_depth)
    )forget_fifo (
        .clk(clk), 
        .rst(rst), 
        .wr_en(forget_fifo_wr_en), 
        .rd_en(forget_fifo_rd_en), 
        .wr_ack(), 
        .overflow(), 
        .full(forget_fifo_full), 
        .empty(forget_fifo_empty), 
        .almostfull(), 
        .almostempty(), 
        .underflow(), 
        .data_in(forget_gate_output), 
        .data_out(forget_fifo_data_out)
    );

    // Output Gate FIFO instantiation
    FIFO #(
        .FIFO_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (output_fifo_depth)
    )output_fifo (
        .clk(clk), 
        .rst(rst), 
        .wr_en(output_fifo_wr_en), 
        .rd_en(output_fifo_rd_en), 
        .wr_ack(), 
        .overflow(), 
        .full(output_fifo_full), 
        .empty(output_fifo_empty), 
        .almostfull(), 
        .almostempty(), 
        .underflow(), 
        .data_in(output_gate_output), 
        .data_out(output_fifo_data_out)
    );

    // Element-wise multiplication instantiation
    EW_TOP #(
        .DATA_WIDTH (DATA_WIDTH),
        .MULT_OUTPUT_WIDTH (MULT_OUTPUT_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    )EW_Multiplication(
        .clk(clk),
        .rst(rst),
        .start(start_EW),
        .cell_done(cell_done),
        .input1_a(input_fifo_data_out),
        .input1_b(candidate_fifo_data_out),
        .input2_a(forget_fifo_data_out),
        .input2_b(prev_cell_state),
        .output_gate(output_fifo_data_out),
        .hidden_state(hidden_state),
        .current_cell_state(current_cell_state),
        .hyperbolic_done(hyperbolic_done),
        .cell_state_valid(cell_state_valid),
        .hidden_state_valid_out(hidden_state_valid)
    );


    // Instantiate LSTM Control Unit
    LSTM_Cell_Control_Unit control_unit (
        .clk(clk),
        .rst(rst),
        .start(start_cell),
        .start_gate(start_gate),
        .start_EW(start_EW),
        .seq_idx_control(seq_idx_control),
        .input_gate_valid(input_gate_valid),
        .candidate_gate_valid(candidate_gate_valid),    
        .forget_gate_valid(forget_gate_valid),
        .output_gate_valid(output_gate_valid),
        .input_fifo_empty(input_fifo_empty),
        .input_fifo_full(input_fifo_full),
        .input_fifo_wr_en(input_fifo_wr_en),
        .input_fifo_rd_en(input_fifo_rd_en),
        .candidate_fifo_empty(candidate_fifo_empty),
        .candidate_fifo_full(candidate_fifo_full),
        .candidate_fifo_wr_en(candidate_fifo_wr_en),
        .candidate_fifo_rd_en(candidate_fifo_rd_en),
        .forget_fifo_empty(forget_fifo_empty),
        .forget_fifo_full(forget_fifo_full),
        .forget_fifo_wr_en(forget_fifo_wr_en),
        .forget_fifo_rd_en(forget_fifo_rd_en),
        .output_fifo_empty(output_fifo_empty), 
        .output_fifo_full(output_fifo_full), 
        .output_fifo_wr_en(output_fifo_wr_en), 
        .output_fifo_rd_en(output_fifo_rd_en),
        .cell_fifo_empty(cell_fifo_empty),
        .cell_fifo_rd_en(cell_fifo_rd_en),
        .hyperbolic_done(hyperbolic_done),
        .cell_state_valid(cell_state_valid),
        .hidden_state_valid(hidden_state_valid),
        .cell_done(cell_done)
    );

endmodule