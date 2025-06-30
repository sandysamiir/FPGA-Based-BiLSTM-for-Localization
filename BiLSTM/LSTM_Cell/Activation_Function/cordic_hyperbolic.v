module cordic_hyperbolic #(
    parameter WIDTH = 16,
    parameter ITERATIONS = 16
)(
    input wire clk,
    input wire reset,
    input wire signed [WIDTH-1:0] Z,
    input wire start,
    output reg signed [WIDTH-1:0] sinh_out,
    output reg signed [WIDTH-1:0] cosh_out,
    output reg [4:0] iteration_trace,
    output reg done  // New signal to indicate CORDIC is done
);
    reg [2:0] state;
    localparam reg [1:0]
    IDLE    = 2'b00,
    INIT    = 2'b01,
    PROCESS = 2'b10,
    DONE    = 2'b11;

    reg signed [WIDTH-1:0] x, y, z;
    reg [3:0] i;
    reg repeat_flag;
    reg [5:0] iteration_count;

    reg signed [WIDTH-1:0] atan_table [0:ITERATIONS-1];

    initial begin
        $readmemh("atanh_q4_12.mem", atan_table);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 16'h1352;
            y <= 0;
            z <= 0;
            i <= 0;
            repeat_flag <= 0;
            sinh_out <= 0;
            cosh_out <= 0;
            iteration_count <= 0;
            iteration_trace <= 0;
            state <= IDLE;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    iteration_count <= 0;
                    if (start) state <= INIT;
                end

                INIT: begin
                    x <= 16'h1352;
                    y <= 0;
                    z <= Z;
                    i <= 0;
                    repeat_flag <= 0;
                    iteration_count <= 0;
                    iteration_trace <= 0;
                    done <= 0;  
                    state <= PROCESS;
                end

                PROCESS: begin
                    if (i < ITERATIONS && (z != 0) && iteration_count <=49) begin
                        iteration_count <= iteration_count + 1;

                        if (z >= 0) begin
                            x <= x + (y >>> (i + 1));
                            y <= y + (x >>> (i + 1));
                            z <= z - atan_table[i];
                        end else begin
                            x <= x - (y >>> (i + 1));
                            y <= y - (x >>> (i + 1));
                            z <= z + atan_table[i];
                        end

                        if ((i == 4 || i == 13) && !repeat_flag)
                            repeat_flag <= 1;
                        else begin
                            i <= i + 1;
                            repeat_flag <= 0;
                        end
                    end else begin
                        // Saturate cosh_out to 4094 if z is in [-48, 48]
                        if (Z >= -100 && Z <= 100) begin
                            sinh_out <= Z;
                        end else begin
                            sinh_out <= y;
                        end                        
                        if (Z >= -48 && Z <= 48) begin
                            cosh_out <= 16'd4096;
                        end else begin
                            cosh_out <= x;
                        end
                        iteration_trace <= iteration_count;
                        iteration_count <= 0; 
                        state <= DONE;
                    end
                end

                DONE: begin
                  iteration_count <= 0;  
                  done <= 1;  
                  state <= IDLE;
                end
            endcase
        end
    end
endmodule
