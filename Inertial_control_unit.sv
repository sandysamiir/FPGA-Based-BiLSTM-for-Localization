module Inertial_control_unit (
    input  logic clk,
    input  logic rst,
    input  logic start, // Start the whole system
    input  logic done_store_concat,
    input  logic out_done_fc1,
    input  logic out_done_fc2,
    output logic start_bilstm,
    output logic start_fc1,
    output logic start_fc2,
    output logic done // High when all operations are finished
);

    // BiLSTM FSM
    typedef enum logic [1:0] {
        B_IDLE,
        B_START,
        B_WAIT_DONE
    } bilstm_state_t;

    bilstm_state_t bilstm_state, bilstm_next;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            bilstm_state <= B_IDLE;
        else
            bilstm_state <= bilstm_next;
    end

    always_comb begin
        bilstm_next = bilstm_state;
        case (bilstm_state)
            B_IDLE:      bilstm_next = start ? B_START : B_IDLE;
            B_START:     bilstm_next = B_WAIT_DONE;
            B_WAIT_DONE: bilstm_next = done_store_concat ? B_START : B_WAIT_DONE;
            default:     bilstm_next = B_IDLE;
        endcase
    end

    assign start_bilstm = (bilstm_state == B_START)?1:0;

    // FC1 FSM
    typedef enum logic [1:0] {
        FC1_IDLE,
        FC1_START,
        FC1_WAIT,
        FC1_DONE
    } fc1_state_t;

    fc1_state_t fc1_state, fc1_next;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            fc1_state <= FC1_IDLE;
        else
            fc1_state <= fc1_next;
    end

    always_comb begin
        fc1_next = fc1_state;
        case (fc1_state)
            FC1_IDLE:  fc1_next = done_store_concat ? FC1_START : FC1_IDLE;
            FC1_START: fc1_next = FC1_WAIT;
            FC1_WAIT:  fc1_next = out_done_fc1 ? FC1_DONE : FC1_WAIT;
            FC1_DONE:  fc1_next = FC1_IDLE;
            default:   fc1_next = FC1_IDLE;
        endcase
    end

    assign start_fc1 = (fc1_state == FC1_START);

    // FC2 FSM
    typedef enum logic [1:0] {
        FC2_IDLE,
        FC2_START,
        FC2_WAIT,
        FC2_DONE
    } fc2_state_t;

    fc2_state_t fc2_state, fc2_next;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            fc2_state <= FC2_IDLE;
        else
            fc2_state <= fc2_next;
    end

    always_comb begin
        fc2_next = fc2_state;
        case (fc2_state)
            FC2_IDLE:  fc2_next = out_done_fc1 ? FC2_START : FC2_IDLE;
            FC2_START: fc2_next = FC2_WAIT;
            FC2_WAIT:  fc2_next = out_done_fc2 ? FC2_DONE : FC2_WAIT;
            FC2_DONE:  fc2_next = FC2_IDLE;
            default:   fc2_next = FC2_IDLE;
        endcase
    end

    assign start_fc2 = (fc2_state == FC2_START);

    // Done when both FC1 and FC2 are done
    assign done = fc2_state == FC2_DONE;

endmodule