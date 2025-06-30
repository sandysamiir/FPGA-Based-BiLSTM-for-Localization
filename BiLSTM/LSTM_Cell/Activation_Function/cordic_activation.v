module cordic_activation #(
    parameter WIDTH = 16,
    parameter ITERATIONS = 16,
    parameter FRAC_SZ = 10
)(
    input wire clk,
    input wire reset,
    input wire start_hyperbolic,
    input wire signed [WIDTH-1:0] Z,
    input wire select,  // 0 for tanh, 1 for sigmoid
    output reg signed [WIDTH-1:0] result,
    output reg done
);

    // Internal wires and registers
    wire signed [WIDTH-1:0] sinh_z, cosh_z;
    wire signed [WIDTH-1:0] division_result;
    wire done_cordic;
    wire done_div;
    reg start_div;
    reg start_cordic;
    reg signed [WIDTH-1:0] Z_reg;
    wire [4:0] iteration_trace;
    reg start_cordic_reg;

    wire signed [WIDTH-1:0] Z_half = Z_reg >>> 1;

    // FSM states
    reg [2:0] state,next_state;
    localparam reg [1:0]
    IDLE          = 2'b00,
    CORDIC_RUN    = 2'b01,
    DIV_RUN       = 2'b10,
    DONE          = 2'b11;

        // tanh limits (select == 0)
    wire is_pos_limit_tanh = (Z[15] == 0 && Z[14:FRAC_SZ] >= 3);
    wire is_neg_limit_tanh = (Z[15] == 1 && Z[14:FRAC_SZ] <= 4);

    // sigmoid limits (select == 1) → check Z_half
    wire is_pos_limit_sigmoid = (Z_half[15] == 0 && Z_half[14:FRAC_SZ] >= 3);
    wire is_neg_limit_sigmoid = (Z_half[15] == 1 && Z_half[14:FRAC_SZ] <= 4);

    // combined conditions depending on select
    wire is_pos_limit = (select == 0) ? is_pos_limit_tanh : is_pos_limit_sigmoid;
    wire is_neg_limit = (select == 0) ? is_neg_limit_tanh : is_neg_limit_sigmoid;


    // Instantiate CORDIC hyperbolic module
    cordic_hyperbolic #(.WIDTH(WIDTH), .ITERATIONS(ITERATIONS)) cordic (
        .clk(clk),
        .reset(reset),
        .Z(select ? Z_half : Z_reg),
        .start(start_cordic),
        .sinh_out(sinh_z),
        .cosh_out(cosh_z),
        .iteration_trace(iteration_trace),
        .done(done_cordic)
    );

    // Instantiate divider module
    cordic_div #(.WIDTH(WIDTH), .FRAC_SZ(FRAC_SZ)) div (
        .clk(clk),
        .reset(reset),
        .numerator(sinh_z),
        .denominator(cosh_z),
        .quotient(division_result),
        .start(start_div),
        .done(done_div)
    );

    reg [2:0] prev_state; // Add this line

    // FSM register block
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            prev_state <= IDLE; // Add this line
            result <= 0;
            start_cordic <= 0;
            start_div <= 0;
            Z_reg <= 0;
            done <= 0;
            start_cordic_reg <= 0;
        end else begin
            prev_state <= state; // Add this line
            state <= next_state;
            case (state)
                IDLE: begin
                    start_cordic <= 0;
                    start_div <= 0;
                    done <= 0;
                    start_cordic_reg <= 0; // Always 0 in IDLE
                end

                CORDIC_RUN: begin
                    Z_reg <= Z;
                    // Pulse start_cordic_reg for one cycle when entering CORDIC_RUN
                    if (prev_state != CORDIC_RUN)
                        start_cordic_reg <= 1;
                    else
                        start_cordic_reg <= 0;

                    if (start_cordic_reg) begin
                        start_cordic <= 1;
                    end else begin
                        start_cordic <= 0;
                    end
                end

                DIV_RUN: begin
                    start_cordic <= 0;
                    start_div <= 1;
                    start_cordic_reg <= 0;
                end

                DONE: begin
                    start_cordic <= 0;
                    start_div <= 0;
                    done <= 1;
                    start_cordic_reg <= 0;
                    if (select && !is_pos_limit && !is_neg_limit) 
                        result <= ((1 << FRAC_SZ) + division_result) >>> 1;
                    else if (!select && !is_pos_limit && !is_neg_limit) 
                        result <= division_result;
                    else if (!select && is_pos_limit)
                        result <= (1 << FRAC_SZ);
                    else if (!select && is_neg_limit)
                        result <= -(1 << FRAC_SZ);
                    else if (select && is_pos_limit)
                        result <= (1 << FRAC_SZ);
                    else if (select && is_neg_limit)
                        result <= 0;
                    else
                        result <= 0; // Default case, should not happen
                end
            endcase
        end
    end

        // FSM next state logic
        always @(*) begin
            case (state)
                IDLE:
                    next_state = (start_hyperbolic) ? CORDIC_RUN : IDLE;

                CORDIC_RUN:
                    //next_state = (is_pos_limit || is_neg_limit) ? DONE :
                                //(done_cordic ? DIV_RUN : CORDIC_RUN);
                    next_state = (done_cordic) ? DIV_RUN : CORDIC_RUN;

                DIV_RUN:
                    next_state = done_div ? DONE : DIV_RUN;

                DONE:
                    next_state = IDLE;

                default: next_state = IDLE;
            endcase
        end


endmodule
