module FCs_TOP #(
  parameter DATA_WIDTH = 16,
  parameter ACC_WIDTH  = 32,
  parameter IN_DIM_200     = 200,
  parameter OUT_DIM_100    = 100,
  parameter IN_DIM_100     = 100,
  parameter OUT_DIM_3    = 3,
  parameter K = 4
)(
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   start_fc1,

  // Entire input vector at once: 1 ? IN_DIM
  input  logic signed [DATA_WIDTH-1:0] in_vector_fc1  [0:IN_DIM_200-1],
  //input  logic signed [DATA_WIDTH-1:0] in_vector_fc2  [0:IN_DIM_100-1],

  // Once computed, entire output vector: 1 ? OUT_DIM (Q4.12 values)
  output logic signed [DATA_WIDTH-1:0] out_vector_fc1 [0:OUT_DIM_100-1],
  output logic signed [DATA_WIDTH-1:0] out_vector_fc2  [0:OUT_DIM_3-1],

  output  logic                             out_done_fc1,
  output  logic                             out_done_fc2

);

  FC1_TOP #(
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH (ACC_WIDTH),
    .IN_DIM    (IN_DIM_200),
    .OUT_DIM   (OUT_DIM_100),
    .K(K)
  ) FC1 (
    .clk        (clk),
    .rst      (rst),
    .start      (start_fc1),
    .in_vector  (in_vector_fc1),
    .out_vector (out_vector_fc1),
    .out_done   (out_done_fc1)
  );



  FC2_TOP #(
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH (ACC_WIDTH),
    .IN_DIM    (IN_DIM_100),
    .OUT_DIM   (OUT_DIM_3),
    .K(K)
  ) FC2 (
    .clk        (clk),
    .rst      (rst),
    .start      (out_done_fc1),
    .in_vector  (out_vector_fc1),
    .out_vector (out_vector_fc2),
    .out_done   (out_done_fc2)
  );


endmodule



