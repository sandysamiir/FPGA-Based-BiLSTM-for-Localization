module LSTM_Cell_Control_Unit (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [3:0] seq_idx_control, // Sequence index
    input wire input_gate_valid,
    input wire candidate_gate_valid,
    input wire forget_gate_valid,
    input wire output_gate_valid,
    input wire input_fifo_empty, 
    input wire input_fifo_full,
    input wire candidate_fifo_empty,
    input wire candidate_fifo_full,
    input wire forget_fifo_empty,
    input wire forget_fifo_full,
    input wire output_fifo_empty,
    input wire output_fifo_full,
    input wire cell_fifo_empty,
    input wire hyperbolic_done,
    input reg cell_state_valid,
    input reg hidden_state_valid,
    output reg start_gate,
    output reg start_EW,
    output reg input_fifo_wr_en, 
    output reg input_fifo_rd_en,
    output reg candidate_fifo_wr_en,
    output reg candidate_fifo_rd_en,
    output reg forget_fifo_wr_en,
    output reg forget_fifo_rd_en,
    output reg output_fifo_wr_en, 
    output reg output_fifo_rd_en,
    output reg cell_fifo_rd_en,
    output reg cell_done
);

    reg [7:0] count_validation = 0; // Counter for validation checks
    reg [7:0] count_validation_reg = 0; // Register to hold the count for FSM 3
    // FSM 1 - Gate & FIFO Write
    typedef enum reg [2:0] {
        START_GATE      = 3'b000,
        WAIT_GATES     = 3'b001
    } fsm1_state_t;

    fsm1_state_t fsm1_state, fsm1_next;

    // FSM 2 - EW & FIFO Read
    typedef enum reg [1:0] {
        READ_FIFOs       = 2'b00,
        ENABLE_EW        = 2'b01,
        WAIT_CELL_STATE  = 2'b10
    } fsm2_state_t;

    fsm2_state_t fsm2_state, fsm2_next;

    // FSM 3 - Final phase
    typedef enum reg [1:0] {
        WAIT_Hyperbolic     = 2'b00,
        READ_OUTPUT_FIFO    = 2'b01,
        WAIT_HIDDEN_STATE   = 2'b10,
        DONE                = 2'b11
    } fsm3_state_t;

    fsm3_state_t fsm3_state, fsm3_next;         

    // FSM 1 - Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            fsm1_state <= START_GATE;
        else
            fsm1_state <= fsm1_next;
    end

    // FSM 2 - Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            fsm2_state <= READ_FIFOs;
        else
            fsm2_state <= fsm2_next;
    end

    // FSM 3 - Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            fsm3_state <= WAIT_Hyperbolic;
        else
            fsm3_state <= fsm3_next;
    end

    // FSM 1 - Combinational logic 
    always @(*) begin
        fsm1_next = fsm1_state;
        start_gate = 0;
        input_fifo_wr_en = 0;
        candidate_fifo_wr_en = 0;
        forget_fifo_wr_en = 0;
        output_fifo_wr_en = 0;
        case (fsm1_state)
            START_GATE: begin
                if (start) begin
                    start_gate = 1;
                    fsm1_next = WAIT_GATES;
                end
            end
            WAIT_GATES: begin
                // Write any valid gate to its FIFO if not full
                if (input_gate_valid && !input_fifo_full)
                    input_fifo_wr_en = 1;
                if (candidate_gate_valid && !candidate_fifo_full)
                    candidate_fifo_wr_en = 1;
                if (forget_gate_valid && !forget_fifo_full)
                    forget_fifo_wr_en = 1;
                if (output_gate_valid && !output_fifo_full)
                    output_fifo_wr_en = 1;

                // Only move on when all gates have been written (all valid and all written)
                if (cell_done) begin
                    fsm1_next = START_GATE; // or next phase if needed
                end
            end
        endcase
    end

    // FSM 2 - Combinational logic 
    always @(*) begin
        fsm2_next = fsm2_state;
        input_fifo_rd_en = 0;
        candidate_fifo_rd_en = 0;   
        forget_fifo_rd_en = 0;
        cell_fifo_rd_en = 0;
        start_EW = 0;
        case (fsm2_state)
            READ_FIFOs: begin
                if (seq_idx_control == 0) begin
                    if (!input_fifo_empty && !candidate_fifo_empty && !forget_fifo_empty) begin
                        input_fifo_rd_en = 1;
                        candidate_fifo_rd_en = 1;
                        forget_fifo_rd_en = 1;
                        fsm2_next = ENABLE_EW;
                    end
                end
                else begin 
                    if (!input_fifo_empty && !candidate_fifo_empty && !forget_fifo_empty && !cell_fifo_empty) begin
                        input_fifo_rd_en = 1;
                        candidate_fifo_rd_en = 1;
                        forget_fifo_rd_en = 1;
                        cell_fifo_rd_en = 1;
                        fsm2_next = ENABLE_EW;
                    end
                end
            end
            ENABLE_EW: begin
                start_EW = 1;
                fsm2_next = WAIT_CELL_STATE;
            end
            WAIT_CELL_STATE: begin
                if (cell_state_valid) begin
                    fsm2_next = READ_FIFOs;
                end 
            end
        endcase
    end
    reg hyperbolic_done_latched,hidden_state_valid_latched;
    reg hyperbolic_done_latched_next, hidden_state_valid_latched_next;

    // FSM 3 - Combinational logic 
    always @(*) begin
        fsm3_next = fsm3_state;
        output_fifo_rd_en = 0;
        cell_done = 0;
        count_validation = count_validation_reg;

        // Default: hold previous values
        hyperbolic_done_latched_next = hyperbolic_done_latched;
        hidden_state_valid_latched_next = hidden_state_valid_latched;

        case (fsm3_state)
            WAIT_Hyperbolic: begin
                if (hyperbolic_done && !output_fifo_empty) begin
                    hyperbolic_done_latched_next = 0;
                    fsm3_next = READ_OUTPUT_FIFO;
                end 
                else if(count_validation == 100) begin
                    fsm3_next = DONE;
                    hyperbolic_done_latched_next = 0;
                end
                else if (hyperbolic_done && output_fifo_empty) begin
                    hyperbolic_done_latched_next = 1;
                end
                else if(hyperbolic_done_latched && !output_fifo_empty) begin
                    fsm3_next = READ_OUTPUT_FIFO;
                end
                if(hyperbolic_done_latched && hidden_state_valid) begin
                    hidden_state_valid_latched_next = 1;
                end
            end
            READ_OUTPUT_FIFO: begin
                output_fifo_rd_en = 1;
                // Hold hyperbolic_done_latched_next
                if(hyperbolic_done_latched && hidden_state_valid) begin
                    hidden_state_valid_latched_next = 1;
                end
                fsm3_next = WAIT_HIDDEN_STATE;
            end
            WAIT_HIDDEN_STATE: begin
                hyperbolic_done_latched_next = 0;
                if (hidden_state_valid) begin
                    count_validation = count_validation + 1;
                    fsm3_next = WAIT_Hyperbolic;  
                end 
                else if (hidden_state_valid_latched) begin
                    count_validation = count_validation + 1;
                    fsm3_next = WAIT_Hyperbolic;  
                end
                hidden_state_valid_latched_next=0;
            end
            DONE: begin
                hyperbolic_done_latched_next = 0;
                cell_done = 1;
                count_validation = 0;
                fsm3_next = WAIT_Hyperbolic; 
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
        count_validation_reg<=0;
        end else begin
            count_validation_reg <= count_validation;    
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hyperbolic_done_latched <= 0;
            hidden_state_valid_latched <= 0;
        end else begin
            hyperbolic_done_latched <= hyperbolic_done_latched_next;
            hidden_state_valid_latched <= hidden_state_valid_latched_next;
        end
    end

endmodule