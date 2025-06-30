module bilstm_concat_stream_store #(
    parameter HIDDEN_SIZE = 16,
    parameter vector_size = 200, // Concatenated size
    parameter SEQ_LEN = 10,
    parameter output_mem_size = vector_size * SEQ_LEN // Total size for sequence buffer
)(
    input  wire clk,
    input  wire rst,
    input  wire fwd_valid,
    input  wire bwd_valid,
    input  wire bilstm_done, // Indicates that the BILSTM has finished processing the sequence
    input  wire [HIDDEN_SIZE-1:0] forward_in,
    input  wire [HIDDEN_SIZE-1:0] backward_in,
    output reg  [HIDDEN_SIZE-1:0] bilstm_out, // Output the current state of the buffer
    output reg  write_enable, // Enable writing to output memory
    output reg  [$clog2(vector_size)-1:0] write_address, // Address for writing to output memory
    output reg signed [HIDDEN_SIZE-1:0] bilstm_out_vector [0:vector_size-1],
    output reg  done_store_concat, // Indicates that storing is done
    output reg  done  // Signals that all values have been stored
);

    // Internal buffer for concatenated outputs
    reg [HIDDEN_SIZE-1:0] bilstm_buffer [0:vector_size-1];
    reg [$clog2(vector_size)-1:0] fwd_index;
    reg [$clog2(vector_size)-1:0] bwd_index;
    reg [$clog2(vector_size)-1:0] read_idx;

    reg bilstm_done_d; // For edge detection
    reg start_store_concat; // One-cycle pulse to start storing
    reg storing; // Indicates storing in progress

    integer i;

    // Synchronous logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all registers and buffer
            fwd_index         <= 0;
            bwd_index         <= 0;
            read_idx          <= 0;
            bilstm_out        <= 0;
            write_enable      <= 0;
            write_address     <= 0;
            done              <= 0;
            done_store_concat <= 0;
            start_store_concat<= 0;
            bilstm_done_d     <= 0;
            storing           <= 0;
            for (i = 0; i < vector_size; i = i + 1)
                bilstm_buffer[i] <= 0;
            for (i = 0; i < vector_size; i = i + 1)
                bilstm_out_vector[i] <= 0;                
        end else begin
            // Edge detection for bilstm_done
            bilstm_done_d <= bilstm_done;
            start_store_concat <= (bilstm_done && !bilstm_done_d);

            // Start storing on pulse, stop when done
            if (start_store_concat)
                storing <= 1;
            else if (read_idx == vector_size)
                storing <= 0;

            // Collect forward and backward outputs
            if (!done) begin
                if (fwd_valid) begin
                    bilstm_buffer[fwd_index] <= forward_in;
                    fwd_index <= fwd_index + 1;
                end
                if (bwd_valid) begin
                    bilstm_buffer[bwd_index + vector_size/2] <= backward_in;
                    bwd_index <= bwd_index + 1;
                end
                if (fwd_index == vector_size/2 && bwd_index == vector_size/2)
                    done <= 1;
            end else begin
                // Reset indices for next sequence
                fwd_index <= 0;
                bwd_index <= 0;
                done      <= 0;
            end

            // Store concatenated output to memory
            if (storing) begin
                if (read_idx < vector_size) begin
                    write_enable  <= 1;
                    write_address <= read_idx;
                    bilstm_out    <= bilstm_buffer[read_idx];
                    bilstm_out_vector[read_idx] <= bilstm_buffer[read_idx];
                    read_idx      <= read_idx + 1;
                end else begin
                    bilstm_out_vector[read_idx]<=0;
                    write_enable      <= 0;
                    write_address     <= 0;
                    bilstm_out        <= 0;
                    read_idx          <= 0;
                    done_store_concat <= 1;
                end
            end else begin
                write_enable      <= 0;
                done_store_concat <= 0;
            end
        end
    end
endmodule