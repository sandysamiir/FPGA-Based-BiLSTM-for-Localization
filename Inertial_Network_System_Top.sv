
module Inertial_Network_System_Top #(
    parameter DATA_WIDTH = 16,
    parameter MULT_OUTPUT_WIDTH = 32,
    parameter fully_addr_width = 8,
    parameter FRAC_SZ = 12,
    parameter FIFO_DEPTH = 128,
    parameter output_fifo_depth_fwd = 32,
    parameter output_fifo_depth_bwd = 32,
    parameter INPUT_ADDR_WIDTH = 6,
    parameter INPUT_HIDDEN_ADDR_WIDTH = 10,
    parameter INPUT_READ_BURST = 1,
    parameter HIDDEN_ADDR_WIDTH = 8,
    parameter HIDDEN_HIDDEN_ADDR_WIDTH = 14,
    parameter HIDDEN_READ_BURST = 2,
    parameter CHUNK_SIZE = 4,
    parameter HIDDEN_SIZE = 16,
    parameter SEQ_LEN = 10,
    parameter vector_size = 200, // Concatenated size
    parameter output_mem_size = 2000, // Size of the output memory
	parameter K = 4,// number of parallel neurons in FC
    parameter MEM_FILE_INPUT = "input_matrix.mem",
    parameter MEM_FILE_HIDDEN = "hidden_matrix_A.mem",
    parameter MEM_FILE_IH_INPUT_FWD = "bilstm_weight_ih_l0_input_gate.mem",
    parameter MEM_FILE_IH_CANDIDATE_FWD = "bilstm_weight_ih_l0_cell_gate.mem",
    parameter MEM_FILE_IH_FORGET_FWD = "bilstm_weight_ih_l0_forget_gate.mem",
    parameter MEM_FILE_IH_OUTPUT_FWD = "bilstm_weight_ih_l0_output_gate.mem",
    parameter MEM_FILE_HH_INPUT_FWD = "bilstm_weight_hh_l0_input_gate.mem",
    parameter MEM_FILE_HH_CANDIDATE_FWD = "bilstm_weight_hh_l0_cell_gate.mem",
    parameter MEM_FILE_HH_FORGET_FWD = "bilstm_weight_hh_l0_forget_gate.mem",
    parameter MEM_FILE_HH_OUTPUT_FWD = "bilstm_weight_hh_l0_output_gate.mem",
    parameter MEM_FILE_INPUT_BIAS_FWD = "input_gate_bias_bilstm.l0.mem",
    parameter MEM_FILE_CANDIDATE_BIAS_FWD = "cell_gate_bias_bilstm.l0.mem",
    parameter MEM_FILE_FORGET_BIAS_FWD = "forget_gate_bias_bilstm.l0.mem",
    parameter MEM_FILE_OUTPUT_BIAS_FWD = "output_gate_bias_bilstm.l0.mem",
    parameter MEM_FILE_IH_INPUT_BWD = "input_gate_weight_ih_bilstm.l0_reverse.mem",
    parameter MEM_FILE_IH_CANDIDATE_BWD = "cell_gate_weight_ih_bilstm.l0_reverse.mem",
    parameter MEM_FILE_IH_FORGET_BWD = "forget_gate_weight_ih_bilstm.l0_reverse.mem",
    parameter MEM_FILE_IH_OUTPUT_BWD = "output_gate_weight_ih_bilstm.l0_reverse.mem",
    parameter MEM_FILE_HH_INPUT_BWD = "input_gate_weight_hh_bilstm.l0_reverse.mem",
    parameter MEM_FILE_HH_CANDIDATE_BWD = "cell_gate_weight_hh_bilstm.l0_reverse.mem",
    parameter MEM_FILE_HH_FORGET_BWD = "forget_gate_weight_hh_bilstm.l0_reverse.mem",
    parameter MEM_FILE_HH_OUTPUT_BWD = "output_gate_weight_hh_bilstm.l0_reverse.mem",
    parameter MEM_FILE_INPUT_BIAS_BWD = "input_gate_bias_bilstm.l0_reverse.mem",
    parameter MEM_FILE_CANDIDATE_BIAS_BWD = "cell_gate_bias_bilstm.l0_reverse.mem",
    parameter MEM_FILE_FORGET_BIAS_BWD = "forget_gate_bias_bilstm.l0_reverse.mem",
    parameter MEM_FILE_OUTPUT_BIAS_BWD = "output_gate_bias_bilstm.l0_reverse.mem",
    parameter fc1_IN_DIM     = 200,
    parameter fc1_OUT_DIM    = 100,
    parameter fc2_IN_DIM     = 100,
    parameter fc2_OUT_DIM    = 3
) (
    input  logic clk,
    input  logic rst,
    input  logic start_inertial,
    input  logic [INPUT_ADDR_WIDTH-1:0] input_write_address,
    input  logic signed [DATA_WIDTH-1:0] input_write_data,
    input  logic input_write_enable,
    output logic signed [DATA_WIDTH-1:0] X_position,
    output logic signed [DATA_WIDTH-1:0] y_position,
    output logic signed [DATA_WIDTH-1:0] z_position,
    output logic done_inertial
);

    // BiLSTM_TOP ports
    logic start_bilstm;
    logic [DATA_WIDTH-1:0] write_data_fwd;
    logic [DATA_WIDTH-1:0] write_data_bwd;
    logic [DATA_WIDTH*2-1:0] write_data_hidden_fwd;
    logic [DATA_WIDTH*2-1:0] write_data_hidden_bwd;
    logic write_enable_fwd;
    logic write_enable_bwd;
    logic [INPUT_HIDDEN_ADDR_WIDTH-1:0] input_hidden_write_address_fwd;
    logic [INPUT_HIDDEN_ADDR_WIDTH-1:0] input_hidden_write_address_bwd;
    logic [6:0] write_address_bias_fwd;
    logic [6:0] write_address_bias_bwd;
    logic [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hidden_hidden_write_address_fwd;
    logic [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hidden_hidden_write_address_bwd;
    logic concat_mem_read_enable;
    logic [fully_addr_width-1:0] concat_mem_read_address;
    logic [DATA_WIDTH-1:0] concat_mem_read_data;
    logic signed [DATA_WIDTH-1:0] bilstm_out;
    logic signed [DATA_WIDTH-1:0] bilstm_out_vector [0:vector_size-1];
    logic done_store_concat;
    logic bilstm_done;

    // FC1_TOP ports
    logic signed [DATA_WIDTH-1:0] fc1_out_vector [0:fc1_OUT_DIM-1];
    logic out_done_fc1;
    // ReLU ports
    logic signed [DATA_WIDTH-1:0] relu_out_vector [0:fc1_OUT_DIM-1] ;

    // FC2_TOP ports
    logic out_done_fc2;
    logic signed [DATA_WIDTH-1:0] out_vector_fc2 [0:fc2_OUT_DIM-1];

    // Inertial_control_unit ports
    logic start_fc1;
    logic start_fc2;

    // Instantiate BiLSTM Top
    BiLSTM_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .MULT_OUTPUT_WIDTH(MULT_OUTPUT_WIDTH),
        .fully_addr_width(fully_addr_width),
        .FRAC_SZ(FRAC_SZ),
        .FIFO_DEPTH(FIFO_DEPTH),
        .output_fifo_depth_fwd(output_fifo_depth_fwd),
        .output_fifo_depth_bwd(output_fifo_depth_bwd),
        .INPUT_ADDR_WIDTH(INPUT_ADDR_WIDTH),
        .INPUT_HIDDEN_ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .INPUT_READ_BURST(INPUT_READ_BURST),
        .HIDDEN_ADDR_WIDTH(HIDDEN_ADDR_WIDTH),
        .HIDDEN_HIDDEN_ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .HIDDEN_READ_BURST(HIDDEN_READ_BURST),
        .CHUNK_SIZE(CHUNK_SIZE),
        .HIDDEN_SIZE(HIDDEN_SIZE),
        .SEQ_LEN(SEQ_LEN),
        .vector_size(vector_size),
        .output_mem_size(output_mem_size),
        .MEM_FILE_INPUT(MEM_FILE_INPUT),
        .MEM_FILE_HIDDEN(MEM_FILE_HIDDEN),
        .MEM_FILE_IH_INPUT_FWD(MEM_FILE_IH_INPUT_FWD),
        .MEM_FILE_IH_CANDIDATE_FWD(MEM_FILE_IH_CANDIDATE_FWD),
        .MEM_FILE_IH_FORGET_FWD(MEM_FILE_IH_FORGET_FWD),
        .MEM_FILE_IH_OUTPUT_FWD(MEM_FILE_IH_OUTPUT_FWD),
        .MEM_FILE_HH_INPUT_FWD(MEM_FILE_HH_INPUT_FWD),
        .MEM_FILE_HH_CANDIDATE_FWD(MEM_FILE_HH_CANDIDATE_FWD),
        .MEM_FILE_HH_FORGET_FWD(MEM_FILE_HH_FORGET_FWD),
        .MEM_FILE_HH_OUTPUT_FWD(MEM_FILE_HH_OUTPUT_FWD),
        .MEM_FILE_INPUT_BIAS_FWD(MEM_FILE_INPUT_BIAS_FWD),
        .MEM_FILE_CANDIDATE_BIAS_FWD(MEM_FILE_CANDIDATE_BIAS_FWD),
        .MEM_FILE_FORGET_BIAS_FWD(MEM_FILE_FORGET_BIAS_FWD),
        .MEM_FILE_OUTPUT_BIAS_FWD(MEM_FILE_OUTPUT_BIAS_FWD),
        .MEM_FILE_IH_INPUT_BWD(MEM_FILE_IH_INPUT_BWD),
        .MEM_FILE_IH_CANDIDATE_BWD(MEM_FILE_IH_CANDIDATE_BWD),
        .MEM_FILE_IH_FORGET_BWD(MEM_FILE_IH_FORGET_BWD),
        .MEM_FILE_IH_OUTPUT_BWD(MEM_FILE_IH_OUTPUT_BWD),
        .MEM_FILE_HH_INPUT_BWD(MEM_FILE_HH_INPUT_BWD),
        .MEM_FILE_HH_CANDIDATE_BWD(MEM_FILE_HH_CANDIDATE_BWD),
        .MEM_FILE_HH_FORGET_BWD(MEM_FILE_HH_FORGET_BWD),
        .MEM_FILE_HH_OUTPUT_BWD(MEM_FILE_HH_OUTPUT_BWD),
        .MEM_FILE_INPUT_BIAS_BWD(MEM_FILE_INPUT_BIAS_BWD),
        .MEM_FILE_CANDIDATE_BIAS_BWD(MEM_FILE_CANDIDATE_BIAS_BWD),
        .MEM_FILE_FORGET_BIAS_BWD(MEM_FILE_FORGET_BIAS_BWD),
        .MEM_FILE_OUTPUT_BIAS_BWD(MEM_FILE_OUTPUT_BIAS_BWD)
    ) u_bilstm_top (
        .clk(clk),
        .rst(rst), // or .rst_n(rst_n) if active low
        .start_bilstm(start_bilstm),
        .input_write_address(input_write_address),
        .input_write_data(input_write_data),
        .input_write_enable(input_write_enable),
        .write_data_fwd(write_data_fwd),
        .write_data_bwd(write_data_bwd),
        .write_data_hidden_fwd(write_data_hidden_fwd),
        .write_data_hidden_bwd(write_data_hidden_bwd),
        .write_enable_fwd(write_enable_fwd),
        .write_enable_bwd(write_enable_bwd),
        .input_hidden_write_address_fwd(input_hidden_write_address_fwd),
        .input_hidden_write_address_bwd(input_hidden_write_address_bwd),
        .write_address_bias_fwd(write_address_bias_fwd),
        .write_address_bias_bwd(write_address_bias_bwd),
        .hidden_hidden_write_address_fwd(hidden_hidden_write_address_fwd),
        .hidden_hidden_write_address_bwd(hidden_hidden_write_address_bwd),
        .concat_mem_read_enable(concat_mem_read_enable),
        .concat_mem_read_address(concat_mem_read_address),
        .concat_mem_read_data(concat_mem_read_data),
        .bilstm_out(bilstm_out),
        .bilstm_out_vector(bilstm_out_vector),
        .done_store_concat(done_store_concat),
        .bilstm_done(bilstm_done)
    );

    // Instantiate FC1_TOP
    FC1_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(MULT_OUTPUT_WIDTH),
        .IN_DIM(fc1_IN_DIM),
        .OUT_DIM(fc1_OUT_DIM),
		.K(K)
    ) u_fc1 (
        .clk(clk),
        .rst(rst),
        .start(start_fc1),
        .in_vector(bilstm_out_vector),
        .out_vector(fc1_out_vector),
        .out_done(out_done_fc1)
    );

    // Instantiate ReLU for each output of FC1
    genvar i;
    generate
        for (i = 0; i < 100 ; i = i + 1) begin : relu_gen
            relu #(.WIDTH(DATA_WIDTH)) u_relu (
                .in(fc1_out_vector[i]),
                .out(relu_out_vector[i])
            );
        end
    endgenerate

    // Instantiate FC2_TOP
    FC2_TOP #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(MULT_OUTPUT_WIDTH),
        .IN_DIM(fc2_IN_DIM),
        .OUT_DIM(fc2_OUT_DIM),
		.K(K)
    ) u_fc2 (
        .clk(clk),
        .rst(rst),
        .start(start_fc2),
        .in_vector(relu_out_vector),
        .out_vector(out_vector_fc2),
        .out_done(out_done_fc2)
    );

    // Instantiate Inertial_control_unit
    Inertial_control_unit u_control_unit (
        .clk(clk),
        .rst(rst), // Assuming rst_n is active low, convert to active high
        .start(start_inertial),
        .done_store_concat(done_store_concat),
        .out_done_fc1(out_done_fc1),
        .out_done_fc2(out_done_fc2),
        .start_bilstm(start_bilstm),
        .start_fc1(start_fc1),
        .start_fc2(start_fc2),
        .done(done_inertial)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            X_position <= 0;
            y_position <= 0;
            z_position <= 0;
        end else if (out_done_fc2) begin
            X_position <= out_vector_fc2[0];
            y_position <= out_vector_fc2[1];
            z_position <= out_vector_fc2[2];
        end
    end

endmodule