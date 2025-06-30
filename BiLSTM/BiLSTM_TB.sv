`timescale 1ns/1ps

module BiLSTM_TOP_TB;

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

    // Inputs
    reg clk;
    reg rst;
    reg start_bilstm;
    reg [INPUT_ADDR_WIDTH-1:0] input_write_address;
    reg signed [DATA_WIDTH-1:0] input_write_data;
    reg input_write_enable;
    reg signed [DATA_WIDTH-1:0] prev_cell_state_fwd;
    reg signed [DATA_WIDTH-1:0] prev_cell_state_bwd;
    reg [DATA_WIDTH-1:0] write_data_fwd;
    reg [DATA_WIDTH-1:0] write_data_bwd;
    reg [DATA_WIDTH*2-1:0] write_data_hidden_fwd;
    reg [DATA_WIDTH*2-1:0] write_data_hidden_bwd;
    reg write_enable_fwd;
    reg write_enable_bwd;
    reg [INPUT_ADDR_WIDTH-1:0] input_write_address_fwd;
    reg [INPUT_ADDR_WIDTH-1:0] input_write_address_bwd;
    reg [INPUT_HIDDEN_ADDR_WIDTH-1:0] input_hidden_write_address_fwd;
    reg [INPUT_HIDDEN_ADDR_WIDTH-1:0] input_hidden_write_address_bwd;
    reg [HIDDEN_ADDR_WIDTH-1:0] hidden_write_address_fwd;
    reg [HIDDEN_ADDR_WIDTH-1:0] hidden_write_address_bwd;
    reg [6:0] write_address_bias_fwd;
    reg [6:0] write_address_bias_bwd;
    reg [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hidden_hidden_write_address_fwd;
    reg [HIDDEN_HIDDEN_ADDR_WIDTH-2:0] hidden_hidden_write_address_bwd;
    reg concat_mem_read_enable;
    reg [fully_addr_width-1:0] concat_mem_read_address;
    reg signed [HIDDEN_SIZE-1:0] bilstm_out_vector [0:vector_size-1];

    // Outputs
    wire signed [HIDDEN_SIZE-1:0] bilstm_out;
    wire bilstm_done;
    wire done_store_concat;
    wire signed [DATA_WIDTH-1:0] concat_mem_read_data;

    // Internal signals for monitoring
    wire signed [DATA_WIDTH-1:0] hidden_state_fwd, hidden_state_bwd;
    wire signed [DATA_WIDTH-1:0] current_cell_state_fwd, current_cell_state_bwd;
    wire hidden_state_valid_fwd, hidden_state_valid_bwd;
    wire cell_state_valid_fwd, cell_state_valid_bwd;
    wire [3:0] seq_idx_control;

    // File handles
    integer f_hidden_fwd, f_hidden_bwd, f_cell_fwd, f_cell_bwd, f_concat;
    integer f_prev_cell_fwd, f_prev_cell_bwd;

    // Input memory arrays and file handles
    integer i, j, read_count, f_input_mem, f_input_matrix_mem;
    reg [DATA_WIDTH-1:0] input_mem_data [0:1199]; // 1200 elements
    reg [DATA_WIDTH-1:0] input_matrix [0:59];     // 60 elements per batch
    integer f_bilstm_out_vector;
    integer idx;


    // Instantiate the DUT
    BiLSTM_TOP #(
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
        .output_mem_size(output_mem_size)
    ) dut (
        .clk(clk),
        .rst(rst),
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

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Assign internal signals for monitoring (assuming you can access them via hierarchical reference)
    assign hidden_state_fwd = dut.lstm_cell_fwd.hidden_state;
    assign hidden_state_bwd = dut.lstm_cell_bwd.hidden_state;
    assign current_cell_state_fwd = dut.lstm_cell_fwd.current_cell_state;
    assign current_cell_state_bwd = dut.lstm_cell_bwd.current_cell_state;
    assign hidden_state_valid_fwd = dut.hidden_state_valid_fwd;
    assign hidden_state_valid_bwd = dut.hidden_state_valid_bwd;
    assign cell_state_valid_fwd = dut.lstm_cell_fwd.cell_state_valid;
    assign cell_state_valid_bwd = dut.lstm_cell_bwd.cell_state_valid;
    assign seq_idx_control = dut.seq_idx_control;

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

    // Task to read and dump concat memory
    task read_concat_memory;
        integer f_concat_mem;
        integer addr;
        begin
            f_concat_mem = $fopen("concat_memory_dump.txt", "a");
            for (addr = 0; addr < 200; addr = addr + 1) begin
                concat_mem_read_address = addr;
                concat_mem_read_enable = 1;
                #(15)
                $fwrite(f_concat_mem, "%d\n", concat_mem_read_data);
            end
            concat_mem_read_enable = 0;
            $fclose(f_concat_mem);
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
        for (i = 0; i < 1200; i = i + 1) begin
            read_count = $fscanf(f_input_mem, "%h\n", input_mem_data[i]);
            if (read_count != 1) begin
                $display("ERROR: Failed to read element %0d from input_memory.mem", i);
                $stop;
            end
        end
        $fclose(f_input_mem);

        // Reset and initialize
        rst = 1;
        start_bilstm = 0;
        prev_cell_state_fwd = 0;
        prev_cell_state_bwd = 0;
        #20;
        rst = 0;
        f_bilstm_out_vector = $fopen("bilstm_out_vector_all_batches.txt", "w");

        for (j = 0; j < 20; j = j + 1) begin // 20 batches
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
            start_bilstm = 1;
            #10;
            start_bilstm = 0;
            #10;


            // Wait for BiLSTM to finish (done_store_concat goes high)
            wait (done_store_concat);
            // Write the whole bilstm_out_vector to a file for this chunk
            // $fwrite(f_bilstm_out_vector, "Batch %0d:\n", j);

                // Write the whole bilstm_out_vector to the file
                for (idx = 0; idx < vector_size; idx = idx + 1) begin
                    $fwrite(f_bilstm_out_vector, "%d\n", bilstm_out_vector[idx]);
                end

            // Read out the concat memory after each batch
            read_concat_memory();
            
            // Add a delay between batches
            #50;
        end
        $fclose(f_bilstm_out_vector);
        $display("All batches processed. Simulation finished.");
        $stop;
    end

    // Save hidden and cell states for both layers
    always @(posedge clk) begin
        if (!rst && seq_idx_control==9) begin
            // Forward
            if (hidden_state_valid_fwd)
                $fwrite(f_hidden_fwd, "%d\n", hidden_state_fwd);
            if (cell_state_valid_fwd)
                $fwrite(f_cell_fwd, "%d\n", current_cell_state_fwd);
            // Backward
            if (hidden_state_valid_bwd)
                $fwrite(f_hidden_bwd, "%d\n", hidden_state_bwd);
            if (cell_state_valid_bwd)
                $fwrite(f_cell_bwd, "%d\n", current_cell_state_bwd);
        end
    end

    reg [31:0] hidden_state_write_count; // 32-bit counter, adjust width as needed

    always @(posedge clk or posedge rst) begin
        if (rst)
            hidden_state_write_count <= 0;
        else if (hidden_state_valid_fwd && seq_idx_control==0) // Add your write condition if needed
            hidden_state_write_count <= hidden_state_write_count + 1;
    end

endmodule