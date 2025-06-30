module concat_memory #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8
)(
    input  wire clk,
    input  wire write_enable,
    input  wire [ADDR_WIDTH-1:0] write_address,
    input  wire signed [DATA_WIDTH-1:0] write_data,

    input  wire read_enable,
    input  wire [ADDR_WIDTH-1:0] read_address, 
    output reg signed [DATA_WIDTH-1:0] read_data
);

    (* ram_style = "distributed" *) reg signed [DATA_WIDTH:0] concat_mem [0:199];

    always @(posedge clk) begin
        if (write_enable)
            concat_mem[write_address] <= write_data;
    end

     always @(posedge clk) begin
        if (read_enable) begin
            read_data <= concat_mem[read_address];  
        end
    end

endmodule