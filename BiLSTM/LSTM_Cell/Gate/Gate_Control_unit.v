module gate_control_unit(
    input         clk,
    input         rst,
    input         start_gate,   // Start signal for the gate control unit
    input         valid_x,      // Data from the input MAC unit (every 7 cycles, valid high)
    input         valid_h,      // Data from the input MAC unit (every 11 cycles, valid high)
    input         act_done,     // Activation done signal from the activation module
    input         mac_fifo_empty,   // FIFO empty signal
    input         mac_fifo_full,    // FIFO full signal
    input         sat_fifo_empty, // FIFO empty signal for saturated results
   // input         special_op,    //Special case for tanh and sigmoid 
    input         first_activation_reg, //first time for activation signal
    input         bilstm_done, //bilstm done signal
    // Control outputs for submodules
    output reg    mac_en,       // Enable MAC operation
    output reg    mac_fifo_wr_en,   // Written to FIFO when valid_x is high
    output reg    mac_fifo_rd_en,   // Read enable for FIFO
    output reg    sat_fifo_wr_en, // Write enable for saturated results FIFO
    output reg    sat_fifo_rd_en, // Read enable for saturated results FIFO
    output reg    sat_en,       // Enable truncation operation
    output reg    add_en,       // Enable addition operation
    output reg    act_en,       // Enable activation operation
    output reg    bias_en,      // Enable bias operation
    output reg    valid_out     // High when final activation output is valid
);

    // FSM state encoding
    localparam IDLE     = 3'd0;
    localparam MAC      = 3'd1; 
    localparam READ     = 3'd2;
    localparam ADD      = 3'd3;
    localparam TRUNC    = 3'd4;
    localparam ADD_BIAS = 3'd5;
    localparam STORE    = 3'd6;
    localparam ACTIVATE = 3'd7;

    reg [2:0] current_state, next_state;
    reg first_activation;
    reg act_done_d;

    // FSM: Sequential state register and output/data path latching
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state  <= IDLE;
            mac_en         <= 0;
            mac_fifo_rd_en <= 0;
            sat_en         <= 0;
            add_en         <= 0;
            sat_fifo_wr_en <= 0;
            bias_en <= 0; // Disable bias operation
        end else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    mac_en         <= 0; 
                    mac_fifo_rd_en <= 0;
                    sat_en         <= 0;
                    add_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en <= 0; // Disable bias operation
                end
                MAC: begin
                    mac_en         <= 1;      // Enable MAC operation
                    mac_fifo_rd_en <= 0;
                    sat_en         <= 0;
                    add_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en <= 0; // Disable bias operation
                end
                READ: begin
                    mac_fifo_rd_en <= 1;      // Read one entry from MAC FIFO
                    mac_en         <= 0; 
                    sat_en         <= 0;
                    add_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en <= 0; // Disable bias operation
                end
                ADD: begin
                    add_en         <= 1;      // Enable addition operation
                    mac_en         <= 0; 
                    mac_fifo_rd_en <= 0;
                    sat_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en <= 0; // Disable bias operation
                end
                TRUNC: begin
                    sat_en         <= 1;      // Enable saturation operation
                    mac_en         <= 0; 
                    mac_fifo_rd_en <= 0;
                    add_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en <= 0; // Disable bias operation
                end
                ADD_BIAS: begin
                    sat_en         <= 0;      // Enable saturation operation
                    mac_en         <= 0; 
                    mac_fifo_rd_en <= 0;
                    add_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en<=1;
                end
                STORE: begin
                    sat_fifo_wr_en <= 1;     // Write saturated result to FIFO
                    sat_en         <= 0;
                    mac_en         <= 0; 
                    mac_fifo_rd_en <= 0;
                    add_en         <= 0;
                    bias_en <= 0; // Disable bias operation
                end
                default: begin
                    mac_en         <= 0; 
                    mac_fifo_rd_en <= 0;
                    sat_en         <= 0;
                    add_en         <= 0;
                    sat_fifo_wr_en <= 0;
                    bias_en <= 0; // Disable bias operation
                end
            endcase
        end
    end

    // FSM: Combinational next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start_gate)
                    next_state = MAC;
                else if(bilstm_done)
                    next_state = IDLE;
                // When there is data in the FIFO and input MAC is valid, start the operation
                else if (!mac_fifo_empty && valid_h)
                    next_state = READ;
                else
                    next_state = IDLE;
            end
            MAC: begin
                // When there is data in the FIFO and input MAC is valid, start the operation
                if (!mac_fifo_empty && valid_h)
                    next_state = READ;
                else
                    next_state = MAC;
            end
            READ:     next_state = ADD;
            ADD:      next_state = TRUNC;
            TRUNC:    next_state = ADD_BIAS;
            ADD_BIAS:  next_state = STORE; // Move to STORE state if bias is done and FIFO is not full
            STORE:    next_state = IDLE;
            default:        next_state = IDLE;
        endcase
    end
reg act_done_hold,act_done_hold_enable;
    // Control signals for activation operation
    always @(posedge clk or posedge rst) begin
    if (rst) begin
        act_en         <= 0;
        sat_fifo_rd_en <= 0;
        valid_out      <= 0;
    end else begin
        if (first_activation_reg) begin
            act_en         <= 1;
            sat_fifo_rd_en <= 1;
            valid_out      <= 0;
        end 
        else if (!sat_fifo_empty && act_done) begin
            act_en         <= 1;
            sat_fifo_rd_en <= 1;
            valid_out      <= 1;
        end else if (act_done_hold_enable) begin
            act_en         <= 1;
            sat_fifo_rd_en <= 1;
            valid_out      <= 1;
        end else if (act_done) begin
            act_en         <= 0;
            sat_fifo_rd_en <= 0;
            valid_out      <= 1;
        end else begin
            act_en         <= 0;
            sat_fifo_rd_en <= 0;
            valid_out      <= 0;
        end
    end
end


always @(posedge clk or posedge rst) begin
    if (rst) begin
        act_done_hold        <= 0;
        act_done_hold_enable <= 0;
    end else begin
        // Step 1: Latch the act_done if FIFO is empty
        if (act_done && sat_fifo_empty) begin
            act_done_hold <= 1;
        end

        // Step 2: Release hold and enable when FIFO becomes non-empty
        if (act_done_hold && !sat_fifo_empty) begin
            act_done_hold        <= 0;
            act_done_hold_enable <= 1;  // fire enable for one clock
        end else begin
            act_done_hold_enable <= 0;  // clear after one clock
        end
    end 
end


    // Separate always block for FIFO write enable.
    // This block writes Z_x into the FIFO whenever valid_x is high and the FIFO is not full.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_fifo_wr_en <= 0;
        end else begin
            if (valid_x && !mac_fifo_full)
                mac_fifo_wr_en <= 1;
            else
                mac_fifo_wr_en <= 0;
        end
    end

endmodule