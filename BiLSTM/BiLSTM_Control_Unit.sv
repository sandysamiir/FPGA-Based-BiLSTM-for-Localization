module BiLSTM_Control_Unit #(
    parameter SEQ_LEN = 10
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    // Forward LSTM cell control
    output reg  start_fwd_cell,
    input  wire fwd_cell_state_valid,
    input reg  fwd_hidden_state_valid,
    input reg  fwd_cell_done,

    // Backward LSTM cell control
    output reg  start_bwd_cell,
    input  wire bwd_cell_state_valid,
    input reg  bwd_hidden_state_valid,
    input reg  bwd_cell_done,

    // FIFO forward
    input wire  fwd_hidden_fifo_empty,
    input  wire fwd_hidden_fifo_full,
    output reg  fwd_hidden_fifo_wr_en,
    output reg  fwd_hidden_fifo_rd_en,

    input  wire fwd_cell_fifo_full,
    output reg  fwd_cell_fifo_wr_en,

    // FIFO backward
    input wire  bwd_hidden_fifo_empty,
    input  wire bwd_hidden_fifo_full,
    output reg  bwd_hidden_fifo_wr_en,
    output reg  bwd_hidden_fifo_rd_en,

    input  wire bwd_cell_fifo_full,
    output reg  bwd_cell_fifo_wr_en,

    // Concat control
    output reg fwd_concat_en,
    output reg bwd_concat_en,
    input wire done_store,

    // Sequence index and done
    output reg [3:0] seq_idx,
    output reg bilstm_done
);

    // Forward/Backward FSM states
    typedef enum logic [1:0] {IDLE, RUN, WAIT_DONE} state_t;
    state_t fwd_state, bwd_state;
 
   // Concat FSM states
    typedef enum logic [1:0] {IDLE_CONCAT, CONCAT} concat_t;
    concat_t fwd_concat_state, bwd_concat_state;


    // === Forward FSM ===
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fwd_state             <= IDLE;
            start_fwd_cell        <= 0;
            fwd_hidden_fifo_wr_en <= 0;
            fwd_cell_fifo_wr_en   <= 0;
        end else begin
            // Default disables
            start_fwd_cell        <= 0;
            fwd_hidden_fifo_wr_en <= 0;
            fwd_cell_fifo_wr_en   <= 0;

            case (fwd_state)
                IDLE: begin
                    fwd_hidden_fifo_wr_en <= 0;
                    fwd_cell_fifo_wr_en   <= 0;
                    if ((start || (done_store&&seq_idx!=9))) begin
                        start_fwd_cell <= 1;
                        fwd_state      <= RUN;
                    end
                end

                RUN: begin
                    if (fwd_hidden_state_valid && !fwd_hidden_fifo_full)
                        fwd_hidden_fifo_wr_en <= 1;

                    if (fwd_cell_state_valid && !fwd_cell_fifo_full &&seq_idx!=9)
                        fwd_cell_fifo_wr_en <= 1; 

                    if (fwd_cell_done)
                        fwd_state <= WAIT_DONE;
                end

                WAIT_DONE: begin
                    fwd_state <= IDLE;
                end
                default: begin
                    // Default case to handle unexpected states
                    fwd_state <= IDLE;
                end
            endcase
        end
    end

    // === Backward FSM ===
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bwd_state             <= IDLE;
            start_bwd_cell        <= 0;
            bwd_hidden_fifo_wr_en <= 0;
            bwd_cell_fifo_wr_en   <= 0;
        end else begin
            // Default disables
            start_bwd_cell        <= 0;
            bwd_hidden_fifo_wr_en <= 0;
            bwd_cell_fifo_wr_en   <= 0;

            case (bwd_state)
                IDLE: begin
                    bwd_hidden_fifo_wr_en <= 0;
                    bwd_cell_fifo_wr_en   <= 0;
                    if (start || (done_store&&seq_idx!=9)) begin
                        start_bwd_cell <= 1;
                        bwd_state      <= RUN;
                    end
                end

                RUN: begin
                    if (bwd_hidden_state_valid && !bwd_hidden_fifo_full)
                        bwd_hidden_fifo_wr_en <= 1;

                    if (bwd_cell_state_valid && !bwd_cell_fifo_full &&seq_idx!=9)
                        bwd_cell_fifo_wr_en <= 1;      

                    if (bwd_cell_done)
                        bwd_state <= WAIT_DONE;
                end

                WAIT_DONE: begin
                    bwd_state <= IDLE;
                end
                default: begin
                    // Default case to handle unexpected states
                    bwd_state <= IDLE;
                end
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fwd_concat_en <= 0;
            fwd_concat_state <= IDLE_CONCAT;
        end else begin
            case (fwd_concat_state)
                IDLE_CONCAT: begin
                    fwd_concat_en <= 0;
                    if (fwd_hidden_state_valid) begin
                        fwd_concat_state <= CONCAT;
                    end
                end
                CONCAT: begin
                    fwd_concat_en <= 1; // Reset concat enable after concat
                    fwd_concat_state <= IDLE_CONCAT;
                end
                default: begin
                    fwd_concat_state <= IDLE_CONCAT;
                end
            endcase
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bwd_concat_en <= 0;
            bwd_concat_state <= IDLE_CONCAT;
        end else begin
            case (bwd_concat_state)
                IDLE_CONCAT: begin
                    bwd_concat_en <= 0;
                    if (bwd_hidden_state_valid) begin
                        bwd_concat_state <= CONCAT;
                    end
                end
                CONCAT: begin
                    bwd_concat_en <= 1; // Reset concat enable after concat
                    bwd_concat_state <= IDLE_CONCAT;
                end
                default: begin
                    bwd_concat_state <= IDLE_CONCAT;
                end
            endcase
        end
    end

    // === Sequence Step Control ===
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seq_idx      <= 0;
            bilstm_done  <= 0;
        end else begin
            if (start) begin
                bilstm_done <= 0; // Reset bilstm_done on new start
            end else if (done_store) begin
                if (seq_idx + 1 < SEQ_LEN) begin
                    seq_idx <= seq_idx + 1;
                end else begin
                    seq_idx <= 0; // Reset for next sequence
                    bilstm_done <= 1;
                end
            end
        end
    end

    // Forward hidden FIFO read control
    reg fwd_reading_fifo;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fwd_hidden_fifo_rd_en <= 0;
            fwd_reading_fifo <= 0;
        end else begin
            if (fwd_cell_done) begin
                // Start reading when cell is done
                fwd_reading_fifo <= 1;
            end else if (fwd_hidden_fifo_empty) begin
                // Stop when FIFO is empty
                fwd_reading_fifo <= 0;
            end

            // Assert read enable while reading and FIFO not empty
            if (fwd_reading_fifo && !fwd_hidden_fifo_empty)
                fwd_hidden_fifo_rd_en <= 1;
            else
                fwd_hidden_fifo_rd_en <= 0;
        end
    end

    // Backward hidden FIFO read control
    reg bwd_reading_fifo;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bwd_hidden_fifo_rd_en <= 0;
            bwd_reading_fifo <= 0;
        end else begin
            if (bwd_cell_done) begin
                // Start reading when cell is done
                bwd_reading_fifo <= 1;
            end else if (bwd_hidden_fifo_empty) begin
                // Stop when FIFO is empty
                bwd_reading_fifo <= 0;
            end

            // Assert read enable while reading and FIFO not empty
            if (bwd_reading_fifo && !bwd_hidden_fifo_empty)
                bwd_hidden_fifo_rd_en <= 1;
            else
                bwd_hidden_fifo_rd_en <= 0;
        end
    end
endmodule