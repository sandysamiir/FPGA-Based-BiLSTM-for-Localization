`timescale 1ns/1ps

module Inertial_network_TOP_TB;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter MULT_OUTPUT_WIDTH = 32;
    parameter fully_addr_width=8;
    parameter FRAC_SZ = 12;
    parameter FIFO_DEPTH = 128;
    parameter output_FIFO_DEPTH_fwd = 32;
    parameter output_FIFO_DEPTH_bwd = 32;
    parameter INPUT_ADDR_WIDTH = 6;
    parameter INPUT_HIDDEN_ADDR_WIDTH = 10;
    parameter INPUT_READ_BURST = 1;
    parameter HIDDEN_ADDR_WIDTH = 8;
    parameter HIDDEN_HIDDEN_ADDR_WIDTH = 14;
    parameter HIDDEN_READ_BURST = 2;
    parameter CHUNK_SIZE = 4;
    parameter HIDDEN_SIZE = 16;
    parameter SEQ_LEN = 10;
    parameter vector_size = 200; // Size of the input vector
    parameter output_mem_size = $clog2(vector_size*SEQ_LEN);
	parameter K = 4;
    parameter fc1_IN_DIM     = 200;
    parameter fc1_OUT_DIM    = 100;
    parameter fc2_IN_DIM     = 100;
    parameter fc2_OUT_DIM    = 3;

    // Inputs
    reg clk;
    reg rst;
    reg start_bilstm;
    reg [INPUT_ADDR_WIDTH-1:0] input_write_address;
    reg signed [DATA_WIDTH-1:0] input_write_data;
    reg input_write_enable;
    logic start_inertial;
    logic signed [DATA_WIDTH-1:0] X_position;
    logic signed [DATA_WIDTH-1:0] y_position;
    logic signed [DATA_WIDTH-1:0] z_position;
    logic done_inertial;

    // File handles
    integer f_hidden_fwd, f_hidden_bwd, f_cell_fwd, f_cell_bwd, f_concat;
    integer f_prev_cell_fwd, f_prev_cell_bwd;

    // Input memory arrays and file handles
    integer i, j, k, read_count, f_input_mem, f_input_matrix_mem;
    reg [DATA_WIDTH-1:0] input_mem_data [0:2999]; 
    reg [DATA_WIDTH-1:0] input_matrix [0:59];     // 60 elements per batch
    integer f_bilstm_out_vector;
    integer idx;


    // Instantiate the DUT
    Inertial_Network_System_Top #(
        .DATA_WIDTH(DATA_WIDTH),
        .MULT_OUTPUT_WIDTH(MULT_OUTPUT_WIDTH),
        .fully_addr_width(fully_addr_width),
        .FRAC_SZ(FRAC_SZ),
        .FIFO_DEPTH(FIFO_DEPTH),
        .output_fifo_depth_fwd(output_FIFO_DEPTH_fwd),
        .output_fifo_depth_bwd(output_FIFO_DEPTH_bwd),
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
		.K(K),
        .fc1_IN_DIM(fc1_IN_DIM),
        .fc1_OUT_DIM(fc1_OUT_DIM),
        .fc2_IN_DIM(fc2_IN_DIM),
        .fc2_OUT_DIM(fc2_OUT_DIM)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start_inertial(start_inertial),
        .input_write_address(input_write_address),
        .input_write_data(input_write_data),
        .input_write_enable(input_write_enable),
        .X_position(X_position),
        .y_position(y_position),
        .z_position(z_position),
        .done_inertial(done_inertial)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // Task to load 60 elements from input_mem_data to input_matrix
    task load_input_matrix(input integer batch_idx);
        integer k;
        begin
            for (k = 0; k < 60; k = k + 1) begin
                input_matrix[k] = input_mem_data[batch_idx*60 + k];
            end
        end
    endtask

    // Task to write input_matrix to input_matrix.mem
    task write_input_matrix_mem;
        integer k;
        begin
            f_input_matrix_mem = $fopen("input_matrix.mem", "w");
            for (k = 0; k < 60; k = k + 1) begin
                $fwrite(f_input_matrix_mem, "%h\n", input_matrix[k]);
            end
            $fclose(f_input_matrix_mem);
        end
    endtask


    // Main stimulus loop for 20 batches
    initial begin
        // Open files
        f_hidden_fwd = $fopen("hidden_state_fwd.txt", "w");
        f_hidden_bwd = $fopen("hidden_state_bwd.txt", "w");
        f_cell_fwd   = $fopen("cell_state_fwd.txt", "w");
        f_cell_bwd   = $fopen("cell_state_bwd.txt", "w");
        f_concat     = $fopen("bilstm_concat_out.txt", "w");
        f_input_mem = $fopen("input_memory.mem", "r");
        if (f_input_mem == 0) begin
            $display("ERROR: Cannot open input_memory.mem");
            $finish;
        end
        // Skip the first 3000 lines
        //for (i = 0; i < 3000; i = i + 1) begin
        //    read_count = $fscanf(f_input_mem, "%*s\n");
        //end

        for (i = 0; i < 3000; i = i + 1) begin
            read_count = $fscanf(f_input_mem, "%h\n", input_mem_data[i]);
            if (read_count != 1) begin
                $display("ERROR: Failed to read element %0d from input_memory.mem", i);
                $stop;
            end
        end
        $fclose(f_input_mem);

        // Reset and initialize
        rst = 1;
        #20;
        rst = 0;
        start_inertial = 0;
        for (j = 0; j < 50; j = j + 1) begin
            // Load and write 60 elements to input_matrix.mem
            load_input_matrix(j);
            // write_input_matrix_mem;
            // Write 60 elements to DUT input memory using input_write_enable
            for (int k = 0; k < 60; k = k + 1) begin
                input_write_enable = 1;
                input_write_address = k;
                input_write_data = input_matrix[k];
                #10;
            end
            input_write_enable = 0;
            #10;

            // Start BiLSTM for this batch
            start_inertial = 1;
            #10;
            start_inertial = 0;
            #10;

            // Wait for BiLSTM to finish (done_store_concat goes high)
            wait (dut.done_store_concat);
            // Add a delay between batches
            #50;
        end
    end

    // Write X, Y, Z positions in floating point (divide by 4096) each time done_inertial is high
    integer f_xyz_positions;
    initial begin
        f_xyz_positions = $fopen("xyz_positions.txt", "w");
        for (k = 0; k < 50; k = k + 1) begin // 3 positions
            wait(done_inertial);
            $fwrite(f_xyz_positions, "%f %f %f\n", 
                $itor(X_position) / 4096.0, 
                $itor(y_position) / 4096.0, 
                $itor(z_position) / 4096.0);
            #30; // Wait for a bit before next position
        end
        $fclose(f_xyz_positions);
        #30;
        $stop;
    end


endmodule