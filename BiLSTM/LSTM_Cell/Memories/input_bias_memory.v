module input_bias_memory#(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 7,  // Matrix B: 16K locations
    parameter READ_BURST = 1,
    parameter MEM_FILE = "input_gate_bias_bilstm.l0.mem"
)(
    input  wire clk,
    input  wire write_enable,

    // Write interface 
    input  wire [ADDR_WIDTH-1:0] write_address,
    input  wire signed [DATA_WIDTH-1:0] write_data,

    // Read interface
    input  wire read_enable,
    input  wire [ADDR_WIDTH-1:0] input_Pointer,

    output reg signed [DATA_WIDTH*READ_BURST-1:0] input_element
);

  // Shared memory depth
  localparam MEM_DEPTH = (1 << ADDR_WIDTH);  // 16K 

  // Shared memory
  (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] input_memory [0:MEM_DEPTH-1];

  integer i;

initial begin
  // Load Matrix B at addresses 0 to (16K - 1)
  $readmemh(MEM_FILE, input_memory, 0, 99);
end

  // Writes to memory
  always @(posedge clk) begin
    if (write_enable) begin
      input_memory[write_address] <= write_data;
    end
  end

  // Reads from Matrix B
  always @(posedge clk) begin
    if (read_enable) begin
      for (i = 0; i < READ_BURST; i = i + 1)
        input_element[DATA_WIDTH*(READ_BURST - i) - 1 -: DATA_WIDTH] <= input_memory[input_Pointer + i];
    end
  end

endmodule
