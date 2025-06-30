module BiLSTM_TOP #(
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
    parameter MEM_FILE_OUTPUT_BIAS_BWD = "output_gate_bias_bilstm.l0_reverse.mem"
)(
    input wire clk,
    input wire rst,
    input wire start_bilstm,
    input wire [INPUT_ADDR_WIDTH-1:0] input_write_address,
    input wire signed [DATA_WIDTH-1:0] input_write_data,
    input wire input_write_enable,
    input wire [DATA_WIDTH-1:0] write_data_fwd,
    input wire [DATA_WIDTH-1:0] write_data_bwd,
    input wire [DATA_WIDTH*2-1:0] write_data_hidden_fwd,
    input wire [DATA_WIDTH*2-1:0] write_data_hidden_bwd,
    input wire write_enable_fwd,
    input wire write_enable_bwd,
    input wire [INPUT_HIDDEN_ADDR_WIDTH-1:0] input_hidden_write_address_fwd,
    input wire [INPUT_HIDDEN_ADDR_WIDTH-1:0] input_hidden_write_address_bwd,
    input wire [6:0] write_address_bias_fwd,
    input wire [6:0] write_address_bias_bwd,
    input wire [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hidden_hidden_write_address_fwd,
    input wire [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hidden_hidden_write_address_bwd,
    input wire concat_mem_read_enable,
    input wire [fully_addr_width-1:0] concat_mem_read_address,
    output wire signed [DATA_WIDTH-1:0] concat_mem_read_data,
    output wire signed [HIDDEN_SIZE-1:0] bilstm_out,
    output wire signed [HIDDEN_SIZE-1:0] bilstm_out_vector [0:vector_size-1],
    output wire done_store_concat,
    output wire bilstm_done
);

    // Internal wires for LSTM cells
    wire signed [DATA_WIDTH-1:0] hidden_state_fwd, hidden_state_bwd;
    wire signed [DATA_WIDTH-1:0] current_cell_state_fwd, current_cell_state_bwd;
    wire cell_state_valid_fwd, cell_state_valid_bwd;
    wire hidden_state_valid_fwd, hidden_state_valid_bwd;
    wire cell_done_fwd, cell_done_bwd;

    // Control signals from BiLSTM Control Unit
    wire start_fwd_cell, start_bwd_cell;
    wire fwd_hidden_fifo_wr_en, fwd_cell_fifo_wr_en;
    wire bwd_hidden_fifo_wr_en, bwd_cell_fifo_wr_en;
    wire fwd_hidden_fifo_rd_en, bwd_hidden_fifo_rd_en ;
    wire fwd_cell_fifo_rd_en, bwd_cell_fifo_rd_en;
    wire [DATA_WIDTH-1:0] FWD_FIFO_OUT_HIDDEN, BWD_FIFO_OUT_HIDDEN;
    wire [DATA_WIDTH-1:0] FWD_FIFO_OUT_CELL, BWD_FIFO_OUT_CELL;
    wire fwd_hidden_fifo_full, bwd_hidden_fifo_full;
    wire fwd_cell_fifo_full, bwd_cell_fifo_full; 
    wire fwd_hidden_fifo_empty, bwd_hidden_fifo_empty;
    wire fwd_cell_fifo_empty, bwd_cell_fifo_empty;
    wire fwd_concat_en, bwd_concat_en, concat_done;
    wire [$clog2(SEQ_LEN)-1:0] seq_idx_control;


    // Input-hidden memory ports (input gate, candidate gate, forget gate, output gate)
    wire input_read_enable_input_gate_fwd, input_read_enable_candidate_gate_fwd, input_read_enable_forget_gate_fwd, input_read_enable_output_gate_fwd;
    wire input_read_enable_input_gate_bwd, input_read_enable_candidate_gate_bwd, input_read_enable_forget_gate_bwd, input_read_enable_output_gate_bwd;
    wire [INPUT_ADDR_WIDTH-1:0] input_Pointer_input_gate_fwd, input_Pointer_candidate_gate_fwd, input_Pointer_forget_gate_fwd, input_Pointer_output_gate_fwd;
    wire [INPUT_ADDR_WIDTH-1:0] input_Pointer_input_gate_bwd, input_Pointer_candidate_gate_bwd, input_Pointer_forget_gate_bwd, input_Pointer_output_gate_bwd;
    wire [DATA_WIDTH-1:0] input_element_input_gate_fwd, input_element_candidate_gate_fwd, input_element_forget_gate_fwd, input_element_output_gate_fwd;
    wire [DATA_WIDTH-1:0] input_element_input_gate_bwd, input_element_candidate_gate_bwd, input_element_forget_gate_bwd, input_element_output_gate_bwd;
    wire [INPUT_HIDDEN_ADDR_WIDTH-1:0] ih_input_Pointer_fwd, ih_candidate_Pointer_fwd, ih_forget_Pointer_fwd, ih_output_Pointer_fwd;
    wire [INPUT_HIDDEN_ADDR_WIDTH-1:0] ih_input_Pointer_bwd, ih_candidate_Pointer_bwd, ih_forget_Pointer_bwd, ih_output_Pointer_bwd;
    wire [DATA_WIDTH-1:0] ih_input_element_fwd, ih_candidate_element_fwd, ih_forget_element_fwd, ih_output_element_fwd;
    wire [DATA_WIDTH-1:0] ih_input_element_bwd, ih_candidate_element_bwd, ih_forget_element_bwd, ih_output_element_bwd;

    // Hidden-hidden memory ports (input gate, candidate gate, forget gate, output gate)
    wire hidden_read_enable_input_gate_fwd, hidden_read_enable_candidate_gate_fwd, hidden_read_enable_forget_gate_fwd, hidden_read_enable_output_gate_fwd;
    wire hidden_read_enable_input_gate_bwd, hidden_read_enable_candidate_gate_bwd, hidden_read_enable_forget_gate_bwd, hidden_read_enable_output_gate_bwd;
    wire [HIDDEN_ADDR_WIDTH-2:0] hidden_Pointer_input_gate_fwd, hidden_Pointer_candidate_gate_fwd, hidden_Pointer_forget_gate_fwd, hidden_Pointer_output_gate_fwd;
    wire [HIDDEN_ADDR_WIDTH-2:0] hidden_Pointer_input_gate_bwd, hidden_Pointer_candidate_gate_bwd, hidden_Pointer_forget_gate_bwd, hidden_Pointer_output_gate_bwd;
    wire [DATA_WIDTH*2-1:0] hidden_data_1_input_gate_fwd, hidden_data_1_candidate_gate_fwd, hidden_data_1_forget_gate_fwd, hidden_data_1_output_gate_fwd;
    wire [DATA_WIDTH*2-1:0] hidden_data_1_input_gate_bwd, hidden_data_1_candidate_gate_bwd, hidden_data_1_forget_gate_bwd, hidden_data_1_output_gate_bwd;
    wire [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hh_input_Pointer_fwd, hh_candidate_Pointer_fwd, hh_forget_Pointer_fwd, hh_output_Pointer_fwd;
    wire [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hh_input_Pointer_bwd, hh_candidate_Pointer_bwd, hh_forget_Pointer_bwd, hh_output_Pointer_bwd;
    wire [DATA_WIDTH*2-1:0] input_read_data_B1_fwd, candidate_read_data_B1_fwd, forget_read_data_B1_fwd, output_read_data_B1_fwd;
    wire [DATA_WIDTH*2-1:0] input_read_data_B1_bwd, candidate_read_data_B1_bwd, forget_read_data_B1_bwd, output_read_data_B1_bwd;

    // Bias memory ports
    wire input_bias_read_enable_fwd, candidate_bias_read_enable_fwd, forget_bias_read_enable_fwd, output_bias_read_enable_fwd;
    wire input_bias_read_enable_bwd, candidate_bias_read_enable_bwd, forget_bias_read_enable_bwd, output_bias_read_enable_bwd;
    wire [6:0] input_bias_pointer_fwd, candidate_bias_pointer_fwd, forget_bias_pointer_fwd, output_bias_pointer_fwd;
    wire [6:0] input_bias_pointer_bwd, candidate_bias_pointer_bwd, forget_bias_pointer_bwd, output_bias_pointer_bwd;
    wire [DATA_WIDTH-1:0] input_gate_bias_element_fwd, candidate_gate_bias_element_fwd, forget_gate_bias_element_fwd, output_gate_bias_element_fwd;
    wire [DATA_WIDTH-1:0] input_gate_bias_element_bwd, candidate_gate_bias_element_bwd, forget_gate_bias_element_bwd, output_gate_bias_element_bwd;



    // Signal to observe concatenated hidden state
    reg [HIDDEN_ADDR_WIDTH-2:0] hidden_write_address_mem_fwd;
    reg [HIDDEN_ADDR_WIDTH-2:0] hidden_write_address_mem_bwd;

    reg [DATA_WIDTH*2-1:0] prev_hidden_state_fwd;
    reg concat_valid_fwd;
    reg [DATA_WIDTH*2-1:0] concat_hidden_state_fwd;
    reg [DATA_WIDTH*2-1:0] prev_hidden_state_bwd;
    reg concat_valid_bwd;
    reg [DATA_WIDTH*2-1:0] concat_hidden_state_bwd;

    // New register to hold the validity of the previous hidden state
    reg prev_hidden_valid_fwd;

    // --- Concatenate and store two consecutive hidden FIFO values (Forward) ---
    reg pair_toggle_fwd;
    reg fwd_hidden_fifo_rd_en_d; // Delayed read enable
    reg fwd_hidden_fifo_empty_d; // Delayed empty state

    // Add this parameter at the top (or use your own logic to determine NUM_PAIRS)
    localparam NUM_PAIRS = 50;

    // Add this register for the done signal
    reg done_store;

    //concat_memory ports
    wire fully_write_enable;
    wire [DATA_WIDTH-1:0] fully_write_data;
    wire [$clog2(vector_size)-1:0] fully_write_address;

    


    // Input Memory instantiation
    input_memory#(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (INPUT_ADDR_WIDTH),   // 8 locations
        .READ_BURST (INPUT_READ_BURST),
        .SEQ_LEN (SEQ_LEN), 
        .MEM_FILE (MEM_FILE_INPUT)
    ) input_memory_inst (
        .clk (clk),
        .timestamp_idx (seq_idx_control),
        .write_enable (input_write_enable),
        .write_address (input_write_address),
        .write_data (input_write_data),
        .read_enable_1_fwd (input_read_enable_input_gate_fwd),
        .read_enable_2_fwd (input_read_enable_candidate_gate_fwd),
        .read_enable_3_fwd (input_read_enable_forget_gate_fwd),
        .read_enable_4_fwd (input_read_enable_output_gate_fwd),
        .input_Pointer_1_fwd (input_Pointer_input_gate_fwd),
        .input_Pointer_2_fwd (input_Pointer_candidate_gate_fwd),
        .input_Pointer_3_fwd (input_Pointer_forget_gate_fwd),
        .input_Pointer_4_fwd (input_Pointer_output_gate_fwd),
        .input_element_1_fwd (input_element_input_gate_fwd),
        .input_element_2_fwd (input_element_candidate_gate_fwd),
        .input_element_3_fwd (input_element_forget_gate_fwd),
        .input_element_4_fwd (input_element_output_gate_fwd),
        .read_enable_1_bwd(input_read_enable_input_gate_bwd),
        .read_enable_2_bwd(input_read_enable_candidate_gate_bwd),
        .read_enable_3_bwd(input_read_enable_forget_gate_bwd),
        .read_enable_4_bwd(input_read_enable_output_gate_bwd),
        .input_Pointer_1_bwd(input_Pointer_input_gate_bwd),
        .input_Pointer_2_bwd(input_Pointer_candidate_gate_bwd),
        .input_Pointer_3_bwd(input_Pointer_forget_gate_bwd),
        .input_Pointer_4_bwd(input_Pointer_output_gate_bwd),
        .input_element_1_bwd(input_element_input_gate_bwd),
        .input_element_2_bwd(input_element_candidate_gate_bwd),
        .input_element_3_bwd(input_element_forget_gate_bwd),
        .input_element_4_bwd(input_element_output_gate_bwd)
    );

    // Hidden Memory instantiation
    hidden_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (HIDDEN_ADDR_WIDTH),
        .READ_BURST (HIDDEN_READ_BURST),
        .MEM_FILE (MEM_FILE_HIDDEN)
    )hidden_memory(
        .clk (clk),
        .write_enable_fwd(concat_valid_fwd),
        .write_address_fwd(hidden_write_address_mem_fwd),
        .write_data_fwd(concat_hidden_state_fwd),
        .write_enable_bwd(concat_valid_bwd),
        .write_address_bwd(hidden_write_address_mem_bwd),
        .write_data_bwd(concat_hidden_state_bwd),        
        .read_enable_1_fwd(hidden_read_enable_input_gate_fwd),
        .read_enable_2_fwd(hidden_read_enable_candidate_gate_fwd),
        .read_enable_3_fwd(hidden_read_enable_forget_gate_fwd),
        .read_enable_4_fwd(hidden_read_enable_output_gate_fwd),
        .read_pointer_1_fwd(hidden_Pointer_input_gate_fwd),
        .read_pointer_2_fwd(hidden_Pointer_candidate_gate_fwd),
        .read_pointer_3_fwd(hidden_Pointer_forget_gate_fwd),
        .read_pointer_4_fwd(hidden_Pointer_output_gate_fwd),
        .read_data_11_fwd(hidden_data_1_input_gate_fwd),
        .read_data_21_fwd(hidden_data_1_candidate_gate_fwd),
        .read_data_31_fwd(hidden_data_1_forget_gate_fwd),
        .read_data_41_fwd(hidden_data_1_output_gate_fwd),
        .read_enable_1_bwd(hidden_read_enable_input_gate_bwd),
        .read_enable_2_bwd(hidden_read_enable_candidate_gate_bwd),
        .read_enable_3_bwd(hidden_read_enable_forget_gate_bwd),
        .read_enable_4_bwd(hidden_read_enable_output_gate_bwd),
        .read_pointer_1_bwd(hidden_Pointer_input_gate_bwd),
        .read_pointer_2_bwd(hidden_Pointer_candidate_gate_bwd),
        .read_pointer_3_bwd(hidden_Pointer_forget_gate_bwd),
        .read_pointer_4_bwd(hidden_Pointer_output_gate_bwd),
        .read_data_11_bwd(hidden_data_1_input_gate_bwd),
        .read_data_21_bwd(hidden_data_1_candidate_gate_bwd),
        .read_data_31_bwd(hidden_data_1_forget_gate_bwd),
        .read_data_41_bwd(hidden_data_1_output_gate_bwd)
    );

    // (input-hidden) Input gate Memory module
    input_hidden_input_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_INPUT_FWD)
    ) ih_input_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(input_hidden_write_address_fwd),
        .write_data(write_data_fwd),
        .read_enable(input_read_enable_input_gate_fwd),
        .input_Pointer(ih_input_Pointer_fwd),
        .input_element(ih_input_element_fwd)
    );
    // (input-hidden) Input gate Memory module
    input_hidden_input_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_INPUT_BWD)
    ) ih_input_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(input_hidden_write_address_bwd),
        .write_data(write_data_bwd),
        .read_enable(input_read_enable_input_gate_bwd),
        .input_Pointer(ih_input_Pointer_bwd),
        .input_element(ih_input_element_bwd)
    );

    // (input-hidden) Candidate gate Memory module
    input_hidden_candidate_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_CANDIDATE_FWD)
    ) ih_candidate_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(input_hidden_write_address_fwd),
        .write_data(write_data_fwd),
        .read_enable(input_read_enable_candidate_gate_fwd),
        .input_Pointer(ih_candidate_Pointer_fwd),
        .input_element(ih_candidate_element_fwd)
    );
    // (input-hidden) Candidate gate Memory module
    input_hidden_candidate_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_CANDIDATE_BWD)
    ) ih_candidate_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(input_hidden_write_address_bwd),
        .write_data(write_data_bwd),
        .read_enable(input_read_enable_candidate_gate_bwd),
        .input_Pointer(ih_candidate_Pointer_bwd),
        .input_element(ih_candidate_element_bwd)
    );
    // (input-hidden) Forget gate Memory module
    input_hidden_forget_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_FORGET_FWD)
    ) ih_forget_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(input_hidden_write_address_fwd),
        .write_data(write_data_fwd),
        .read_enable(input_read_enable_forget_gate_fwd),
        .input_Pointer(ih_forget_Pointer_fwd),
        .input_element(ih_forget_element_fwd)
    );
    // (input-hidden) Forget gate Memory module
    input_hidden_forget_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_FORGET_BWD)
    ) ih_forget_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(input_hidden_write_address_bwd),
        .write_data(write_data_bwd),
        .read_enable(input_read_enable_forget_gate_bwd),
        .input_Pointer(ih_forget_Pointer_bwd),
        .input_element(ih_forget_element_bwd)
    );
    // (input-hidden) Output gate Memory module
    input_hidden_output_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_OUTPUT_FWD)
    ) ih_output_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(input_hidden_write_address_fwd),
        .write_data(write_data_fwd),
        .read_enable(input_read_enable_output_gate_fwd),
        .input_Pointer(ih_output_Pointer_fwd),
        .input_element(ih_output_element_fwd)
    );
        // (input-hidden) Output gate Memory module
    input_hidden_output_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .READ_BURST(INPUT_READ_BURST),
        .MEM_FILE(MEM_FILE_IH_OUTPUT_BWD)
    ) ih_output_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(input_hidden_write_address_bwd),
        .write_data(write_data_bwd),
        .read_enable(input_read_enable_output_gate_bwd),
        .input_Pointer(ih_output_Pointer_bwd),
        .input_element(ih_output_element_bwd)
    );

        // (hidden-hidden) Input gate Memory module
    hidden_hidden_input_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_INPUT_FWD)
    ) hh_input_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(hidden_hidden_write_address_fwd),
        .write_data(write_data_hidden_fwd),
        .read_enable(hidden_read_enable_input_gate_fwd),
        .read_pointer(hh_input_Pointer_fwd),
        .read_data_B1(input_read_data_B1_fwd)
    );
        // (hidden-hidden) Input gate Memory module
    hidden_hidden_input_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_INPUT_BWD)
    ) hh_input_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(hidden_hidden_write_address_bwd),
        .write_data(write_data_hidden_bwd),
        .read_enable(hidden_read_enable_input_gate_bwd),
        .read_pointer(hh_input_Pointer_bwd),
        .read_data_B1(input_read_data_B1_bwd)
    );

    // (hidden-hidden) Candidate gate Memory module
    hidden_hidden_candidate_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_CANDIDATE_FWD)
    ) hh_candidate_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(hidden_hidden_write_address_fwd),
        .write_data(write_data_hidden_fwd),
        .read_enable(hidden_read_enable_candidate_gate_fwd),
        .read_pointer(hh_candidate_Pointer_fwd),
        .read_data_B1(candidate_read_data_B1_fwd)
    );

    // (hidden-hidden) Candidate gate Memory module
    hidden_hidden_candidate_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_CANDIDATE_BWD)
    ) hh_candidate_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(hidden_hidden_write_address_bwd),
        .write_data(write_data_hidden_bwd),
        .read_enable(hidden_read_enable_candidate_gate_bwd),
        .read_pointer(hh_candidate_Pointer_bwd),
        .read_data_B1(candidate_read_data_B1_bwd)
    );

    // (hidden-hidden) Forget gate Memory module
    hidden_hidden_forget_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_FORGET_FWD)
    ) hh_forget_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(hidden_hidden_write_address_fwd),
        .write_data(write_data_hidden_fwd),
        .read_enable(hidden_read_enable_forget_gate_fwd),
        .read_pointer(hh_forget_Pointer_fwd),
        .read_data_B1(forget_read_data_B1_fwd)
    );

    // (hidden-hidden) Forget gate Memory module
    hidden_hidden_forget_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_FORGET_BWD)
    ) hh_forget_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(hidden_hidden_write_address_bwd),
        .write_data(write_data_hidden_bwd),
        .read_enable(hidden_read_enable_forget_gate_bwd),
        .read_pointer(hh_forget_Pointer_bwd),
        .read_data_B1(forget_read_data_B1_bwd)
    );

        // (hidden-hidden) Output gate Memory module
    hidden_hidden_output_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_OUTPUT_FWD)
    ) hh_output_gate_mem_fwd (
        .clk(clk),
        .write_enable(write_enable_fwd),
        .write_address(hidden_hidden_write_address_fwd),
        .write_data(write_data_hidden_fwd),
        .read_enable(hidden_read_enable_output_gate_fwd),
        .read_pointer(hh_output_Pointer_fwd),
        .read_data_B1(output_read_data_B1_fwd)
    );
    
    // (hidden-hidden) Output gate Memory module
    hidden_hidden_output_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .READ_BURST(HIDDEN_READ_BURST),
        .MEM_FILE(MEM_FILE_HH_OUTPUT_BWD)
    ) hh_output_gate_mem_bwd (
        .clk(clk),
        .write_enable(write_enable_bwd),
        .write_address(hidden_hidden_write_address_bwd),
        .write_data(write_data_hidden_bwd),
        .read_enable(hidden_read_enable_output_gate_bwd),
        .read_pointer(hh_output_Pointer_bwd),
        .read_data_B1(output_read_data_B1_bwd)
    );

    input_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_INPUT_BIAS_FWD)
    ) input_gate_bias_fwd (
        .clk (clk),
        .write_enable (write_enable_fwd),
        .write_address (write_address_bias_fwd),
        .write_data (write_data_fwd),
        .read_enable (input_bias_read_enable_fwd),
        .input_Pointer (input_bias_pointer_fwd),
        .input_element (input_gate_bias_element_fwd)
    );

    input_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_INPUT_BIAS_BWD)
    ) input_gate_bias_bwd (
        .clk (clk),
        .write_enable (write_enable_bwd),
        .write_address (write_address_bias_bwd),
        .write_data (write_data_bwd),
        .read_enable (input_bias_read_enable_bwd),
        .input_Pointer (input_bias_pointer_bwd),
        .input_element (input_gate_bias_element_bwd)
    );

    candidate_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_CANDIDATE_BIAS_FWD)
     ) candidate_gate_bias_fwd (
        .clk (clk),
        .write_enable (write_enable_fwd),
        .write_address (write_address_bias_fwd),
        .write_data (write_data_fwd),
        .read_enable (candidate_bias_read_enable_fwd),
        .input_Pointer (candidate_bias_pointer_fwd),
        .input_element (candidate_gate_bias_element_fwd)
    );  

    candidate_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_CANDIDATE_BIAS_BWD)
    ) candidate_gate_bias_bwd (
        .clk (clk),
        .write_enable (write_enable_bwd),
        .write_address (write_address_bias_bwd),
        .write_data (write_data_bwd),
        .read_enable (candidate_bias_read_enable_bwd),
        .input_Pointer (candidate_bias_pointer_bwd),
        .input_element (candidate_gate_bias_element_bwd)
    ); 

    forget_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_FORGET_BIAS_FWD)
    ) forget_gate_bias_fwd (
        .clk (clk),
        .write_enable (write_enable_fwd),
        .write_address (write_address_bias_fwd),
        .write_data (write_data_fwd),
        .read_enable (forget_bias_read_enable_fwd),
        .input_Pointer (forget_bias_pointer_fwd),
        .input_element (forget_gate_bias_element_fwd)
    );

    forget_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_FORGET_BIAS_BWD)
    ) forget_gate_bias_bwd (
        .clk (clk),
        .write_enable (write_enable_bwd),
        .write_address (write_address_bias_bwd),
        .write_data (write_data_bwd),
        .read_enable (forget_bias_read_enable_bwd),
        .input_Pointer (forget_bias_pointer_bwd),
        .input_element (forget_gate_bias_element_bwd)
    ); 

    output_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_OUTPUT_BIAS_FWD)
    ) output_gate_bias_fwd (
        .clk (clk),
        .write_enable (write_enable_fwd),
        .write_address (write_address_bias_fwd),
        .write_data (write_data_fwd),
        .read_enable (output_bias_read_enable_fwd),
        .input_Pointer (output_bias_pointer_fwd),
        .input_element (output_gate_bias_element_fwd)
    );

    output_bias_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (7),   // 8 locations
        .READ_BURST (1),
        .MEM_FILE (MEM_FILE_OUTPUT_BIAS_BWD)
    ) output_gate_bias_bwd (
        .clk (clk),
        .write_enable (write_enable_bwd),
        .write_address (write_address_bias_bwd),
        .write_data (write_data_bwd),
        .read_enable (output_bias_read_enable_bwd),
        .input_Pointer (output_bias_pointer_bwd),
        .input_element (output_gate_bias_element_bwd)
    );


    // Instantiate Forward LSTM Cell
    LSTM_Cell_Top #(
        .DATA_WIDTH(DATA_WIDTH),
        .MULT_OUTPUT_WIDTH(MULT_OUTPUT_WIDTH),
        .FRAC_SZ(FRAC_SZ),
        .FIFO_DEPTH(FIFO_DEPTH),
        .output_fifo_depth(output_fifo_depth_fwd),
        .INPUT_ADDR_WIDTH(INPUT_ADDR_WIDTH),
        .INPUT_HIDDEN_ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .INPUT_READ_BURST(INPUT_READ_BURST),
        .HIDDEN_ADDR_WIDTH(HIDDEN_ADDR_WIDTH),
        .HIDDEN_HIDDEN_ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .HIDDEN_READ_BURST(HIDDEN_READ_BURST),
        .CHUNK_SIZE(CHUNK_SIZE)
    ) lstm_cell_fwd (
        .clk(clk),
        .rst(rst),
        .start_cell(start_fwd_cell),
        .bilstm_done(bilstm_done),
        .seq_idx_control(seq_idx_control),
        .prev_cell_state(seq_idx_control==0?16'd0:FWD_FIFO_OUT_CELL),
        .input_element_input_gate(input_element_input_gate_fwd),
        .input_element_candidate_gate(input_element_candidate_gate_fwd),
        .input_element_forget_gate(input_element_forget_gate_fwd),
        .input_element_output_gate(input_element_output_gate_fwd),
        .ih_input_element(ih_input_element_fwd),
        .ih_candidate_element(ih_candidate_element_fwd),
        .ih_forget_element(ih_forget_element_fwd),
        .ih_output_element(ih_output_element_fwd),
        .hidden_data_1_input_gate(seq_idx_control==0?0:hidden_data_1_input_gate_fwd),
        .hidden_data_1_candidate_gate(seq_idx_control==0?0:hidden_data_1_candidate_gate_fwd),
        .hidden_data_1_forget_gate(seq_idx_control==0?0:hidden_data_1_forget_gate_fwd),
        .hidden_data_1_output_gate(seq_idx_control==0?0:hidden_data_1_output_gate_fwd),
        .input_read_data_B1(input_read_data_B1_fwd),
        .candidate_read_data_B1(candidate_read_data_B1_fwd),
        .forget_read_data_B1(forget_read_data_B1_fwd),
        .output_read_data_B1(output_read_data_B1_fwd),
        .input_gate_bias_element(input_gate_bias_element_fwd),
        .candidate_gate_bias_element(candidate_gate_bias_element_fwd),
        .forget_gate_bias_element(forget_gate_bias_element_fwd),
        .output_gate_bias_element(output_gate_bias_element_fwd),
        .input_read_enable_input_gate(input_read_enable_input_gate_fwd),
        .input_read_enable_candidate_gate(input_read_enable_candidate_gate_fwd),
        .input_read_enable_forget_gate(input_read_enable_forget_gate_fwd),
        .input_read_enable_output_gate(input_read_enable_output_gate_fwd),
        .hidden_read_enable_input_gate(hidden_read_enable_input_gate_fwd),
        .hidden_read_enable_candidate_gate(hidden_read_enable_candidate_gate_fwd),
        .hidden_read_enable_forget_gate(hidden_read_enable_forget_gate_fwd),
        .hidden_read_enable_output_gate(hidden_read_enable_output_gate_fwd),
        .input_Pointer_input_gate(input_Pointer_input_gate_fwd),
        .input_Pointer_candidate_gate(input_Pointer_candidate_gate_fwd),
        .input_Pointer_forget_gate(input_Pointer_forget_gate_fwd),
        .input_Pointer_output_gate(input_Pointer_output_gate_fwd),
        .ih_input_Pointer(ih_input_Pointer_fwd),
        .ih_candidate_Pointer(ih_candidate_Pointer_fwd),
        .ih_forget_Pointer(ih_forget_Pointer_fwd),
        .ih_output_Pointer(ih_output_Pointer_fwd),
        .hidden_Pointer_input_gate(hidden_Pointer_input_gate_fwd),
        .hidden_Pointer_candidate_gate(hidden_Pointer_candidate_gate_fwd),
        .hidden_Pointer_forget_gate(hidden_Pointer_forget_gate_fwd),
        .hidden_Pointer_output_gate(hidden_Pointer_output_gate_fwd),
        .hh_input_Pointer(hh_input_Pointer_fwd),
        .hh_candidate_Pointer(hh_candidate_Pointer_fwd),
        .hh_forget_Pointer(hh_forget_Pointer_fwd),
        .hh_output_Pointer(hh_output_Pointer_fwd),
        .input_bias_read_enable(input_bias_read_enable_fwd),
        .candidate_bias_read_enable(candidate_bias_read_enable_fwd),
        .forget_bias_read_enable(forget_bias_read_enable_fwd),
        .output_bias_read_enable(output_bias_read_enable_fwd),
        .input_bias_pointer(input_bias_pointer_fwd),
        .candidate_bias_pointer(candidate_bias_pointer_fwd),
        .forget_bias_pointer(forget_bias_pointer_fwd),
        .output_bias_pointer(output_bias_pointer_fwd),
        .hidden_state(hidden_state_fwd),
        .current_cell_state(current_cell_state_fwd),
        .cell_state_valid(cell_state_valid_fwd),
        .hidden_state_valid(hidden_state_valid_fwd),
        .cell_done(cell_done_fwd),
        .cell_fifo_empty(fwd_cell_fifo_empty),
        .cell_fifo_rd_en(fwd_cell_fifo_rd_en)
    );

    // Instantiate Backward LSTM Cell
    LSTM_Cell_Top #(
        .DATA_WIDTH(DATA_WIDTH),
        .MULT_OUTPUT_WIDTH(MULT_OUTPUT_WIDTH),
        .FRAC_SZ(FRAC_SZ),
        .FIFO_DEPTH(FIFO_DEPTH),
        .output_fifo_depth(output_fifo_depth_bwd),
        .INPUT_ADDR_WIDTH(INPUT_ADDR_WIDTH),
        .INPUT_HIDDEN_ADDR_WIDTH(INPUT_HIDDEN_ADDR_WIDTH),
        .INPUT_READ_BURST(INPUT_READ_BURST),
        .HIDDEN_ADDR_WIDTH(HIDDEN_ADDR_WIDTH),
        .HIDDEN_HIDDEN_ADDR_WIDTH(HIDDEN_HIDDEN_ADDR_WIDTH),
        .HIDDEN_READ_BURST(HIDDEN_READ_BURST),
        .CHUNK_SIZE(CHUNK_SIZE)
    ) lstm_cell_bwd (
        .clk(clk),
        .rst(rst),
        .start_cell(start_bwd_cell),
        .bilstm_done(bilstm_done),
        .seq_idx_control(seq_idx_control),
        .prev_cell_state(seq_idx_control==0?16'd0:BWD_FIFO_OUT_CELL),
        .input_element_input_gate(input_element_input_gate_bwd),
        .input_element_candidate_gate(input_element_candidate_gate_bwd),
        .input_element_forget_gate(input_element_forget_gate_bwd),
        .input_element_output_gate(input_element_output_gate_bwd),
        .ih_input_element(ih_input_element_bwd),
        .ih_candidate_element(ih_candidate_element_bwd),
        .ih_forget_element(ih_forget_element_bwd),
        .ih_output_element(ih_output_element_bwd),
        .hidden_data_1_input_gate(seq_idx_control==0?0:hidden_data_1_input_gate_bwd),
        .hidden_data_1_candidate_gate(seq_idx_control==0?0:hidden_data_1_candidate_gate_bwd),
        .hidden_data_1_forget_gate(seq_idx_control==0?0:hidden_data_1_forget_gate_bwd),
        .hidden_data_1_output_gate(seq_idx_control==0?0:hidden_data_1_output_gate_bwd),
        .input_read_data_B1(input_read_data_B1_bwd),
        .candidate_read_data_B1(candidate_read_data_B1_bwd),
        .forget_read_data_B1(forget_read_data_B1_bwd),
        .output_read_data_B1(output_read_data_B1_bwd),
        .input_gate_bias_element(input_gate_bias_element_bwd),
        .candidate_gate_bias_element(candidate_gate_bias_element_bwd),
        .forget_gate_bias_element(forget_gate_bias_element_bwd),
        .output_gate_bias_element(output_gate_bias_element_bwd),
        .input_read_enable_input_gate(input_read_enable_input_gate_bwd),
        .input_read_enable_candidate_gate(input_read_enable_candidate_gate_bwd),
        .input_read_enable_forget_gate(input_read_enable_forget_gate_bwd),
        .input_read_enable_output_gate(input_read_enable_output_gate_bwd),
        .hidden_read_enable_input_gate(hidden_read_enable_input_gate_bwd),
        .hidden_read_enable_candidate_gate(hidden_read_enable_candidate_gate_bwd),
        .hidden_read_enable_forget_gate(hidden_read_enable_forget_gate_bwd),
        .hidden_read_enable_output_gate(hidden_read_enable_output_gate_bwd),
        .input_Pointer_input_gate(input_Pointer_input_gate_bwd),
        .input_Pointer_candidate_gate(input_Pointer_candidate_gate_bwd),
        .input_Pointer_forget_gate(input_Pointer_forget_gate_bwd),
        .input_Pointer_output_gate(input_Pointer_output_gate_bwd),
        .ih_input_Pointer(ih_input_Pointer_bwd),
        .ih_candidate_Pointer(ih_candidate_Pointer_bwd),
        .ih_forget_Pointer(ih_forget_Pointer_bwd),
        .ih_output_Pointer(ih_output_Pointer_bwd),
        .hidden_Pointer_input_gate(hidden_Pointer_input_gate_bwd),
        .hidden_Pointer_candidate_gate(hidden_Pointer_candidate_gate_bwd),
        .hidden_Pointer_forget_gate(hidden_Pointer_forget_gate_bwd),
        .hidden_Pointer_output_gate(hidden_Pointer_output_gate_bwd),
        .hh_input_Pointer(hh_input_Pointer_bwd),
        .hh_candidate_Pointer(hh_candidate_Pointer_bwd),
        .hh_forget_Pointer(hh_forget_Pointer_bwd),
        .hh_output_Pointer(hh_output_Pointer_bwd),
        .input_bias_read_enable(input_bias_read_enable_bwd),
        .candidate_bias_read_enable(candidate_bias_read_enable_bwd),
        .forget_bias_read_enable(forget_bias_read_enable_bwd),
        .output_bias_read_enable(output_bias_read_enable_bwd),
        .input_bias_pointer(input_bias_pointer_bwd),
        .candidate_bias_pointer(candidate_bias_pointer_bwd),
        .forget_bias_pointer(forget_bias_pointer_bwd),
        .output_bias_pointer(output_bias_pointer_bwd),
        .hidden_state(hidden_state_bwd),
        .current_cell_state(current_cell_state_bwd),
        .cell_state_valid(cell_state_valid_bwd),
        .hidden_state_valid(hidden_state_valid_bwd),
        .cell_done(cell_done_bwd),
        .cell_fifo_empty(bwd_cell_fifo_empty),
        .cell_fifo_rd_en(bwd_cell_fifo_rd_en)
    );

    // Instantiate BiLSTM Control Unit
    BiLSTM_Control_Unit #(
        .SEQ_LEN(SEQ_LEN)
    ) control_unit (
        .clk(clk),
        .rst(rst),
        .start(start_bilstm),
        // Forward LSTM cell control
        .start_fwd_cell(start_fwd_cell),
        .fwd_cell_state_valid(cell_state_valid_fwd),
        .fwd_hidden_state_valid(hidden_state_valid_fwd),
        .fwd_cell_done(cell_done_fwd),
        // Backward LSTM cell control
        .start_bwd_cell(start_bwd_cell),
        .bwd_cell_state_valid(cell_state_valid_bwd),
        .bwd_hidden_state_valid(hidden_state_valid_bwd),
        .bwd_cell_done(cell_done_bwd),
        // FIFO forward
        .fwd_hidden_fifo_empty(fwd_hidden_fifo_empty),
        .fwd_hidden_fifo_full(fwd_hidden_fifo_full),
        .fwd_hidden_fifo_wr_en(fwd_hidden_fifo_wr_en),
        .fwd_hidden_fifo_rd_en(fwd_hidden_fifo_rd_en),
        .fwd_cell_fifo_full(fwd_cell_fifo_full),
        .fwd_cell_fifo_wr_en(fwd_cell_fifo_wr_en),
        // FIFO backward
        .bwd_hidden_fifo_empty(bwd_hidden_fifo_empty),
        .bwd_hidden_fifo_full(bwd_hidden_fifo_full),
        .bwd_hidden_fifo_wr_en(bwd_hidden_fifo_wr_en),
        .bwd_hidden_fifo_rd_en(bwd_hidden_fifo_rd_en),
        .bwd_cell_fifo_full(bwd_cell_fifo_full),
        .bwd_cell_fifo_wr_en(bwd_cell_fifo_wr_en),
        // concatenation control
        .fwd_concat_en(fwd_concat_en),
        .bwd_concat_en(bwd_concat_en),
        .done_store(done_store),
        // Sequence index and done
        .seq_idx(seq_idx_control),
        .bilstm_done(bilstm_done)
    );
 
    // Instantiate BiLSTM Concat Stream
    bilstm_concat_stream_store #(
        .HIDDEN_SIZE(HIDDEN_SIZE),
        .vector_size(200), // Concatenated size
        .SEQ_LEN(SEQ_LEN),
        .output_mem_size(output_mem_size) // Size of the output memory
    ) concat_stream (
        .clk(clk),
        .rst(rst),
        .fwd_valid(fwd_concat_en),
        .bwd_valid(bwd_concat_en),
        .bilstm_done(bilstm_done),
        .forward_in(hidden_state_fwd),
        .backward_in(hidden_state_bwd),
        .bilstm_out(bilstm_out),
        .write_enable(fully_write_enable),
        .write_address(fully_write_address),
        .done_store_concat(done_store_concat),
        .bilstm_out_vector(bilstm_out_vector),
        .done(concat_done)
    );

    // === FIFO Instantiations ===
    // Forward hidden state FIFO
    FIFO #(
        .FIFO_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) fwd_hidden_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(fwd_hidden_fifo_wr_en),
        .rd_en(fwd_hidden_fifo_rd_en), // Connect as needed
        .wr_ack(),    // Optional: connect if needed
        .overflow(),  // Optional: connect if needed
        .full(fwd_hidden_fifo_full),
        .empty(fwd_hidden_fifo_empty),     // Optional: connect if needed
        .almostfull(),// Optional: connect if needed
        .almostempty(),// Optional: connect if needed
        .underflow(), // Optional: connect if needed
        .data_in(hidden_state_fwd),
        .data_out(FWD_FIFO_OUT_HIDDEN)   // Optional: connect if needed
    );

    // Backward hidden state FIFO
    FIFO #(
        .FIFO_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) bwd_hidden_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(bwd_hidden_fifo_wr_en),
        .rd_en(bwd_hidden_fifo_rd_en), // Connect as needed
        .wr_ack(),    // Optional: connect if needed
        .overflow(),  // Optional: connect if needed
        .full(bwd_hidden_fifo_full),
        .empty(bwd_hidden_fifo_empty),     // Optional: connect if needed
        .almostfull(),// Optional: connect if needed
        .almostempty(),// Optional: connect if needed
        .underflow(), // Optional: connect if needed
        .data_in(hidden_state_bwd),
        .data_out(BWD_FIFO_OUT_HIDDEN)   // Optional: connect if needed
    );

    // Forward cell state FIFO
    FIFO #(
        .FIFO_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) fwd_cell_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(fwd_cell_fifo_wr_en),
        .rd_en(fwd_cell_fifo_rd_en), // Connect as needed
        .wr_ack(),    // Optional: connect if needed
        .overflow(),  // Optional: connect if needed
        .full(fwd_cell_fifo_full),
        .empty(fwd_cell_fifo_empty),     // Optional: connect if needed
        .almostfull(),// Optional: connect if needed
        .almostempty(),// Optional: connect if needed
        .underflow(), // Optional: connect if needed
        .data_in(current_cell_state_fwd),
        .data_out(FWD_FIFO_OUT_CELL)   // Optional: connect if needed
    );

    // Backward cell state FIFO
    FIFO #(
        .FIFO_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) bwd_cell_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(bwd_cell_fifo_wr_en),
        .rd_en(bwd_cell_fifo_rd_en), // Connect as needed
        .wr_ack(),    // Optional: connect if needed
        .overflow(),  // Optional: connect if needed
        .full(bwd_cell_fifo_full),
        .empty(bwd_cell_fifo_empty),     // Optional: connect if needed
        .almostfull(),// Optional: connect if needed
        .almostempty(),// Optional: connect if needed
        .underflow(), // Optional: connect if needed
        .data_in(current_cell_state_bwd),
        .data_out(BWD_FIFO_OUT_CELL)   // Optional: connect if needed
    );

    concat_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(fully_addr_width)
    )
    concat_memory_u0( 
        .clk(clk),
        .write_enable(fully_write_enable), 
        .write_address(fully_write_address), 
        .write_data(bilstm_out),
        .read_enable(concat_mem_read_enable),
        .read_address(concat_mem_read_address),
        .read_data(concat_mem_read_data)      
    );


always @(posedge clk or posedge rst) begin
    if (rst) begin
        pair_toggle_fwd <= 0;
        prev_hidden_state_fwd <= 0;
        concat_hidden_state_fwd <= 0;
        concat_valid_fwd <= 0;
        fwd_hidden_fifo_rd_en_d <= 0;
        fwd_hidden_fifo_empty_d<=0;
    end else begin
        fwd_hidden_fifo_rd_en_d <= fwd_hidden_fifo_rd_en; // Delay the read enable
        fwd_hidden_fifo_empty_d <= fwd_hidden_fifo_empty; // Capture the empty state
        if (fwd_hidden_fifo_rd_en_d && !fwd_hidden_fifo_empty_d) begin
            if (pair_toggle_fwd == 0) begin
                prev_hidden_state_fwd <= FWD_FIFO_OUT_HIDDEN;
                concat_valid_fwd <= 0;
                pair_toggle_fwd <= 1;
            end else begin
                concat_hidden_state_fwd <= {prev_hidden_state_fwd, FWD_FIFO_OUT_HIDDEN};
                concat_valid_fwd <= 1;
                pair_toggle_fwd <= 0;
            end
        end else begin
            concat_valid_fwd <= 0;
        end
    end
end

// --- Concatenate and store two consecutive hidden FIFO values (Backward) ---
reg pair_toggle_bwd;
reg bwd_hidden_fifo_rd_en_d; // Delayed read enable
reg bwd_hidden_fifo_empty_d; // Delayed empty state
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pair_toggle_bwd <= 0;
        prev_hidden_state_bwd <= 0;
        concat_hidden_state_bwd <= 0;
        concat_valid_bwd <= 0;
        bwd_hidden_fifo_rd_en_d <= 0;
        bwd_hidden_fifo_empty_d <=0;
    end else begin
        bwd_hidden_fifo_rd_en_d <= bwd_hidden_fifo_rd_en; // Delay the read enable
        bwd_hidden_fifo_empty_d <= bwd_hidden_fifo_empty; // Capture the empty state
        if (bwd_hidden_fifo_rd_en_d && !bwd_hidden_fifo_empty_d) begin
            if (pair_toggle_bwd == 0) begin
                prev_hidden_state_bwd <= BWD_FIFO_OUT_HIDDEN;
                concat_valid_bwd <= 0;
                pair_toggle_bwd <= 1;
            end else begin
                concat_hidden_state_bwd <= {prev_hidden_state_bwd, BWD_FIFO_OUT_HIDDEN};
                concat_valid_bwd <= 1;
                pair_toggle_bwd <= 0;
            end
        end else begin
            concat_valid_bwd <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        done_store <= 0;
        hidden_write_address_mem_fwd <= 0;
        hidden_write_address_mem_bwd <= 0;
    end else begin
        if (concat_valid_fwd) begin
            hidden_write_address_mem_fwd <= hidden_write_address_mem_fwd + 1;
         end
        if (concat_valid_bwd) begin
            hidden_write_address_mem_bwd <= hidden_write_address_mem_bwd + 1;
         end
        if ((hidden_write_address_mem_fwd == NUM_PAIRS) && (hidden_write_address_mem_bwd == NUM_PAIRS)) begin
            done_store <= 1;
            hidden_write_address_mem_fwd <= 0; // Reset write address for next sequence
            hidden_write_address_mem_bwd <= 0; // Reset write address for next sequence
        end else begin
            done_store <= 0;
        end
    end
end

endmodule