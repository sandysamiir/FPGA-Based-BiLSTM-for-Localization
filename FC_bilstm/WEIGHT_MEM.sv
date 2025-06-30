// Weight Memory Module: Single-Port BRAM for Weight Matrix Storage
// Stores a flattened 2D weight matrix of dimensions OUT_DIM x IN_DIM
// Preloaded from external .mem file for simulation and synthesis

module WEIGHT_MEM #(
    parameter MEM_FILE    = "fc1_weight.mem",
    parameter DATA_WIDTH = 16,      // Width of each weight element
    parameter IN_DIM     = 200,     // Number of inputs per neuron (columns)
    parameter OUT_DIM    = 100      // Number of output neurons (rows)
) (
    // Global signals
    input  logic                   clk,
    input  logic                   rst,
    
    // Read interface (inference FSM)
    input  logic                   rd_en,         // Read enable
    input  logic [$clog2(OUT_DIM*IN_DIM)-1:0] rd_addr, // Address for weight fetch
    output logic signed [DATA_WIDTH-1:0]        rd_data  // Data read
);

    // Internal memory array
    logic signed [DATA_WIDTH-1:0] mem [0:OUT_DIM*IN_DIM-1];

    // Simulation and synthesis preload
    initial begin
        // Load weights from hex file (16-bit two's-complement) into mem
        $readmemh(MEM_FILE, mem);
    end

    // Read logic (registered output)
    logic signed [DATA_WIDTH-1:0] rd_data_reg;
    assign rd_data = rd_data_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            rd_data_reg <= '0;
        end else if (rd_en) begin
            rd_data_reg <= mem[rd_addr];
        end
    end

endmodule

