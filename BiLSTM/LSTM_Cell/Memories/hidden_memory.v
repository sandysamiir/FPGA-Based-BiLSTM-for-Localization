module hidden_memory #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8,
    parameter READ_BURST = 2,
    parameter MEM_FILE = "hidden_matrix_A.mem"
)(
    input  wire clk,
    input  wire write_enable_fwd,
    input  wire [ADDR_WIDTH-2:0] write_address_fwd,
    input  wire signed [DATA_WIDTH*READ_BURST-1:0] write_data_fwd,

    input  wire read_enable_1_fwd,
    input  wire read_enable_2_fwd,
    input  wire read_enable_3_fwd,
    input  wire read_enable_4_fwd,
    input  wire [(ADDR_WIDTH-2):0] read_pointer_1_fwd,  // Word index (each word = 5 elements)
    input  wire [(ADDR_WIDTH-2):0] read_pointer_2_fwd,  // Word index (each word = 5 elements)
    input  wire [(ADDR_WIDTH-2):0] read_pointer_3_fwd,  // Word index (each word = 5 elements)
    input  wire [(ADDR_WIDTH-2):0] read_pointer_4_fwd,  // Word index (each word = 5 elements)
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_11_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_21_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_31_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_41_fwd,
    
    input  wire write_enable_bwd,
    input  wire [ADDR_WIDTH-2:0] write_address_bwd,
    input  wire signed [DATA_WIDTH*READ_BURST-1:0] write_data_bwd,

    input  wire read_enable_1_bwd,
    input  wire read_enable_2_bwd,
    input  wire read_enable_3_bwd,
    input  wire read_enable_4_bwd,
    input  wire [(ADDR_WIDTH-2):0] read_pointer_1_bwd,
    input  wire [(ADDR_WIDTH-2):0] read_pointer_2_bwd,
    input  wire [(ADDR_WIDTH-2):0] read_pointer_3_bwd,
    input  wire [(ADDR_WIDTH-2):0] read_pointer_4_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_11_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_21_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_31_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] read_data_41_bwd
);

    // Each memory word holds 5 � 16-bit = 80-bit
    (* ram_style = "distributed" *) reg signed [DATA_WIDTH*READ_BURST-1:0] matrix_A_mem_fwd [0:(1<<(ADDR_WIDTH-1))-1];
    (* ram_style = "distributed" *) reg signed [DATA_WIDTH*READ_BURST-1:0] matrix_A_mem_bwd [0:(1<<(ADDR_WIDTH-1))-1];

    initial begin
        $readmemh(MEM_FILE, matrix_A_mem_fwd);
        $readmemh(MEM_FILE, matrix_A_mem_bwd);
    end

    // Forward direction write
    always @(posedge clk) begin
        if (write_enable_fwd)
            matrix_A_mem_fwd[write_address_fwd] <= write_data_fwd;
    end
    // Backward direction write
    always @(posedge clk) begin
        if (write_enable_bwd)
            matrix_A_mem_bwd[write_address_bwd] <= write_data_bwd;
    end


    // Forward direction reads
    always @(posedge clk) begin
        if (read_enable_1_fwd)
            read_data_11_fwd <= matrix_A_mem_fwd[read_pointer_1_fwd];
        if (read_enable_2_fwd)
            read_data_21_fwd <= matrix_A_mem_fwd[read_pointer_2_fwd];
        if (read_enable_3_fwd)
            read_data_31_fwd <= matrix_A_mem_fwd[read_pointer_3_fwd];
        if (read_enable_4_fwd)
            read_data_41_fwd <= matrix_A_mem_fwd[read_pointer_4_fwd];
    end

    // Backward direction reads
    always @(posedge clk) begin
        if (read_enable_1_bwd)
            read_data_11_bwd <= matrix_A_mem_bwd[read_pointer_1_bwd];
        if (read_enable_2_bwd)
            read_data_21_bwd <= matrix_A_mem_bwd[read_pointer_2_bwd];
        if (read_enable_3_bwd)
            read_data_31_bwd <= matrix_A_mem_bwd[read_pointer_3_bwd];
        if (read_enable_4_bwd)
            read_data_41_bwd <= matrix_A_mem_bwd[read_pointer_4_bwd];
    end

endmodule
