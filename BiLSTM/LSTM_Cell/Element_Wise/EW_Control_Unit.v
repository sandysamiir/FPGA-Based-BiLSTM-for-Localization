module EW_Control_Unit (
    input wire clk,
    input wire rst,
    input wire start,
    input wire mult1_done,
    input wire mult2_done,
    input wire sat1_done,
    input wire fifo_full,
    input wire fifo_empty,
    input wire hyperbolic_done,
    input wire sat2_done,
    output reg mult_enable,
    output reg sat1_enable,
    output reg fifo_wr_en,
    output reg fifo_rd_en,
    output reg start_hyp,
    output reg sat2_enable
);

    // Input FSM states
    reg [1:0] input_state, input_next_state;

    localparam IN_IDLE = 2'b00,
               IN_MULTIPLY = 2'b01,
               IN_SATURATE1 = 2'b10,
               IN_WRITE_FIFO = 2'b11;

    // Output FSM states
    reg [2:0] output_state, output_next_state;

    localparam OUT_IDLE = 3'b000,
               OUT_READ_FIFO = 3'b001,
               OUT_START_ACTIVATE = 3'b010,
               OUT_ACTIVATE = 3'b011,
               OUT_SATURATE2 = 3'b100,
               OUT_DONE = 3'b101;


    // Input FSM sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            input_state <= IN_IDLE;
        else
            input_state <= input_next_state;
    end

    // Output FSM sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            output_state <= OUT_IDLE;
        else
            output_state <= output_next_state;
    end


    // Input FSM combinational logic
    always @(*) begin
        case (input_state)
            IN_IDLE: begin
                if (start)
                    input_next_state = IN_MULTIPLY;
                else
                    input_next_state = IN_IDLE;
            end
            IN_MULTIPLY: begin
                if (mult1_done && mult2_done)
                    input_next_state = IN_SATURATE1;
                else
                    input_next_state = IN_MULTIPLY;
            end
            IN_SATURATE1: begin
                if (sat1_done && !fifo_full)
                    input_next_state = IN_WRITE_FIFO;
                else
                    input_next_state = IN_SATURATE1;
            end
            IN_WRITE_FIFO: begin
                input_next_state = IN_IDLE;
            end
            default: input_next_state = IN_IDLE;
        endcase
    end

    // Output FSM combinational logic
    always @(*) begin
        case (output_state)
            OUT_IDLE: begin
                if (!fifo_empty)
                    output_next_state = OUT_READ_FIFO;
                else
                    output_next_state = OUT_IDLE;
            end
            OUT_READ_FIFO: begin
                output_next_state = OUT_START_ACTIVATE;
            end
            OUT_START_ACTIVATE: begin
                output_next_state = OUT_ACTIVATE;
            end
            OUT_ACTIVATE: begin
                if (hyperbolic_done)
                    output_next_state = OUT_SATURATE2;
                else
                    output_next_state = OUT_ACTIVATE;
            end
            OUT_SATURATE2: begin
                if (sat2_done)
                    output_next_state = OUT_DONE;
                else
                    output_next_state = OUT_SATURATE2;
            end
            OUT_DONE: begin
                output_next_state = OUT_IDLE;
            end
            default: output_next_state = OUT_IDLE;
        endcase
    end

    // Input FSM output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mult_enable <= 0;
            sat1_enable <= 0;
            fifo_wr_en  <= 0;
        end else begin
            case (input_state)
                IN_IDLE: begin
                    mult_enable <= 0;
                    sat1_enable <= 0;
                    fifo_wr_en  <= 0;
                end
                IN_MULTIPLY: begin
                    mult_enable <= 1;
                end
                IN_SATURATE1: begin
                    mult_enable <= 0;
                    sat1_enable <= 1;
                end
                IN_WRITE_FIFO: begin
                    sat1_enable <= 0;
                    fifo_wr_en <= 1;
                end
            endcase
        end
    end


    // Input FSM output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fifo_rd_en  <= 0;
            start_hyp   <= 0;
            sat2_enable <= 0;
        end else begin
            case (output_state)
                OUT_IDLE: begin
                    fifo_rd_en  <= 0;
                    start_hyp   <= 0;
                    sat2_enable <= 0;
                end
                OUT_READ_FIFO: begin
                    fifo_rd_en <= 1;
                end
                OUT_START_ACTIVATE: begin
                    fifo_rd_en <= 0;
                    start_hyp <= 1;
                end
                OUT_ACTIVATE: begin
                    start_hyp <= 0;
                end
                OUT_SATURATE2: begin
                    start_hyp <= 0;
                    sat2_enable <= 1;
                end
                OUT_DONE: begin
                    sat2_enable <= 0;
                end
            endcase
        end
    end

endmodule