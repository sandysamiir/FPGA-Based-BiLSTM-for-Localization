module hidden_hidden_forget_memory #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 14,
    parameter READ_BURST = 2,
    parameter MEM_FILE = "bilstm_weight_hh_l0_forget_gate.mem"
)(
    input  wire clk,
    input  wire write_enable,
    input  wire [ADDR_WIDTH-2:0] write_address,
    input  wire signed [DATA_WIDTH*2-1:0] write_data,

    input  wire read_enable,
    input  wire [(ADDR_WIDTH-2):0] read_pointer,  // Word index (each word = 5 elements)
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_B1
);

 // Each memory word holds 5 � 16-bit = 80-bit
    (* ram_style = "block" *) reg signed [31:0] matrix_B_mem [0:8192-1];

    initial begin
        $readmemh(MEM_FILE, matrix_B_mem);
    end

    always @(posedge clk) begin
        if (write_enable)
            matrix_B_mem[write_address] <= write_data;
    end

     always @(posedge clk) begin
        if (read_enable) begin
            read_data_B1 <= matrix_B_mem[read_pointer];  // 64-bit read
        end
    end

endmodule