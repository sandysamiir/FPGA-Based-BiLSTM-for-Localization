module input_memory#(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 6,   // 64 locations
    parameter READ_BURST  = 1,
    parameter SEQ_LEN = 10, // Sequence length
    parameter MEM_FILE = "input_matrix.mem"

  )(
    input  wire clk,
    input wire [3:0] timestamp_idx, 
    // input wire reload,

    // Write interface 
    input  wire write_enable,
    input  wire [ADDR_WIDTH-1:0] write_address,
    input  wire signed [DATA_WIDTH-1:0] write_data,

    // Read interface fwd
    input  wire read_enable_1_fwd,
    input  wire read_enable_2_fwd,
    input  wire read_enable_3_fwd,
    input  wire read_enable_4_fwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_1_fwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_2_fwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_3_fwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_4_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_1_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_2_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_3_fwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_4_fwd,

    //Read interface bwd
    input  wire read_enable_1_bwd,
    input  wire read_enable_2_bwd,
    input  wire read_enable_3_bwd,
    input  wire read_enable_4_bwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_1_bwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_2_bwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_3_bwd,
    input  wire [ADDR_WIDTH-1:0] input_Pointer_4_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_1_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_2_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_3_bwd,
    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element_4_bwd


  );

    // Parameters
    localparam INPUTS_PER_TIMESTEP = 6;
    localparam MEM_DEPTH = SEQ_LEN * INPUTS_PER_TIMESTEP;  // 60 locations

    // Shared memory
    (* ram_style = "distributed" *) reg signed [DATA_WIDTH-1:0] input_memory [0:MEM_DEPTH-1];

    integer i, j, k, l;

  // Writes to Matrix A (offset 0)
  always @(posedge clk) begin
    if (write_enable) begin
      input_memory[write_address] <= write_data;
    end
  end

  // Reads from Matrix A to first gate
  always @(posedge clk) begin
    if (read_enable_1_fwd) begin
      for (i = 0; i < READ_BURST; i = i + 1)
        input_element_1_fwd[DATA_WIDTH*(READ_BURST - i) - 1 -: DATA_WIDTH] <= input_memory[timestamp_idx * 6 + input_Pointer_1_fwd + i];
    end
  end

  // Reads from Matrix A to second gate
  always @(posedge clk) begin
    if (read_enable_2_fwd) begin
      for (j = 0; j < READ_BURST; j = j + 1)
        input_element_2_fwd[DATA_WIDTH*(READ_BURST - j) - 1 -: DATA_WIDTH] <= input_memory[timestamp_idx * 6 + input_Pointer_2_fwd + j];
    end
  end

  // Reads from Matrix A to third gate
  always @(posedge clk) begin
    if (read_enable_3_fwd) begin
      for (k = 0; k < READ_BURST; k = k + 1)
        input_element_3_fwd[DATA_WIDTH*(READ_BURST - k) - 1 -: DATA_WIDTH] <= input_memory[timestamp_idx * 6 + input_Pointer_3_fwd + k];
    end
  end

  // Reads from Matrix A to fourth gate
  always @(posedge clk) begin
    if (read_enable_4_fwd) begin
      for (l = 0; l < READ_BURST; l = l + 1)
        input_element_4_fwd[DATA_WIDTH*(READ_BURST - l) - 1 -: DATA_WIDTH] <= input_memory[timestamp_idx * 6 + input_Pointer_4_fwd + l];
    end
  end
 

  // Reads from Matrix A to first gate (bwd)
  always @(posedge clk) begin
    if (read_enable_1_bwd) begin
      for (i = 0; i < READ_BURST; i = i + 1)
        input_element_1_bwd[DATA_WIDTH*(READ_BURST - i) - 1 -: DATA_WIDTH] <= input_memory[(SEQ_LEN-1 - timestamp_idx) * 6 + input_Pointer_1_bwd + i];
    end
  end

  // Reads from Matrix A to second gate (bwd)
  always @(posedge clk) begin
    if (read_enable_2_bwd) begin
      for (j = 0; j < READ_BURST; j = j + 1)
        input_element_2_bwd[DATA_WIDTH*(READ_BURST - j) - 1 -: DATA_WIDTH] <= input_memory[(SEQ_LEN-1 - timestamp_idx) * 6 + input_Pointer_2_bwd + + j];
    end
  end

  // Reads from Matrix A to third gate (bwd)
  always @(posedge clk) begin
    if (read_enable_3_bwd) begin
      for (k = 0; k < READ_BURST; k = k + 1)
        input_element_3_bwd[DATA_WIDTH*(READ_BURST - k) - 1 -: DATA_WIDTH] <= input_memory[(SEQ_LEN-1 - timestamp_idx) * 6 + input_Pointer_3_bwd + + k];
    end
  end

  // Reads from Matrix A to fourth gate (bwd)
  always @(posedge clk) begin
    if (read_enable_4_bwd) begin
      for (l = 0; l < READ_BURST; l = l + 1)
        input_element_4_bwd[DATA_WIDTH*(READ_BURST - l) - 1 -: DATA_WIDTH] <= input_memory[(SEQ_LEN-1 - timestamp_idx) * 6 + input_Pointer_4_bwd + + l];
    end
  end

endmodule
