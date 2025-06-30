//`include "fixed_point_adapter.sv"

module FC2_TOP #(
  parameter MEM_FILE_WEIGHT = "fc2_weight.mem",
  parameter MEM_FILE_BIAS   = "fc2_bias.mem",
  parameter DATA_WIDTH = 16,
  parameter ACC_WIDTH  = 32,
  parameter IN_DIM     = 200,
  parameter OUT_DIM    = 100,
  parameter K = 4
)(
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   start,

  // Entire input vector at once: 1 ? IN_DIM
  input  logic signed [DATA_WIDTH-1:0] in_vector  [0:IN_DIM-1],

  // Once computed, entire output vector: 1 ? OUT_DIM (Q4.12 values)
  output logic signed [DATA_WIDTH-1:0] out_vector [0:OUT_DIM-1],
  output  logic                             out_done
);


  //? Internal wires between modules ?//
  /*logic                         mac_en;
  logic signed [DATA_WIDTH-1:0] mac_a, mac_b;
  logic signed [ACC_WIDTH-1:0]  mac_acc_in, mac_acc_out;
  logic                         w_req, b_req;
  logic [$clog2(IN_DIM*OUT_DIM)-1:0] w_addr;
  logic [$clog2(OUT_DIM)-1:0]        b_addr;
  logic signed [DATA_WIDTH-1:0]      w_data, b_data;*/


   //?? After  (add parameter K) ??//
   // Weight read ports
   logic           [K-1:0]                         w_req;
   logic [$clog2(IN_DIM*OUT_DIM)-1:0] w_addr  [0:K-1];
   logic signed [DATA_WIDTH-1:0]      w_data  [0:K-1];
 
   // Bias read ports
   logic           [K-1:0]                         b_req;
   logic [$clog2(OUT_DIM)-1:0]        b_addr  [0:K-1];
   logic signed [DATA_WIDTH-1:0]      b_data  [0:K-1];
 
   // MAC lanes
   logic           [K-1:0]                         mac_en;
   logic signed [DATA_WIDTH-1:0]  mac_a   [0:K-1];
   logic signed [DATA_WIDTH-1:0]  mac_b   [0:K-1];
   logic signed [ACC_WIDTH-1:0]   mac_acc_in  [0:K-1];
   logic signed [ACC_WIDTH-1:0]   mac_acc_out [0:K-1];


  //? Unflatten input: indexed by controller FSM ?//
  //   The controller will use in_vector[ i*DATA_WIDTH +: DATA_WIDTH ] as mac_a

  //? Instantiate Memories & MAC ?//
  /*WEIGHT_MEM #( .MEM_FILE("fc1_weight.mem"), .DATA_WIDTH(DATA_WIDTH), .IN_DIM(IN_DIM), .OUT_DIM(OUT_DIM) ) fc1_weight_mem (
    .clk    (clk), .rst(rst),
    .rd_en  (w_req), .rd_addr(w_addr),
    .rd_data(w_data)
  );*/
  genvar i;
  for (i = 0; i < K; i++) begin : fc2_weight_mem
    WEIGHT_MEM #(
      .MEM_FILE    (MEM_FILE_WEIGHT),
      .DATA_WIDTH(DATA_WIDTH),
      .IN_DIM    (IN_DIM),
      .OUT_DIM   (OUT_DIM)
    ) wt_mem_i (
      .clk    (clk),
      .rst  (rst),
      .rd_en  (w_req[i]),
      .rd_addr(w_addr[i]),
      .rd_data(w_data[i])
    );
  end

  /*BIAS_MEM #( .MEM_FILE("fc1_bias.mem"), .DATA_WIDTH(DATA_WIDTH), .OUT_DIM(OUT_DIM) ) fc1_bias_mem (
    .clk    (clk), .rst(rst),
    .rd_en  (b_req), .rd_addr(b_addr),
    .rd_data(b_data)
  );*/
  
  for (i = 0; i < K; i++) begin : fc2_bias_mem
    BIAS_MEM #(
      .MEM_FILE    (MEM_FILE_BIAS),
      .DATA_WIDTH(DATA_WIDTH),
      .OUT_DIM   (OUT_DIM)
    ) b_mem_i (
      .clk    (clk),
      .rst  (rst),
      .rd_en  (b_req[i]),
      .rd_addr(b_addr[i]),
      .rd_data(b_data[i])
    );
  end

  /*MAC_UNIT #( .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH) ) fc1_mac_u (
    .clk    (clk), .rst(rst),
    .en     (mac_en),
    .a      (mac_a),
    .b      (mac_b),
    .acc_in (mac_acc_in),
    .acc_out(mac_acc_out)
  );*/

  genvar j;
  for (j = 0; j < K; j++) begin : fc2_mac_u
    MAC_UNIT #(
      .DATA_WIDTH(DATA_WIDTH),
      .ACC_WIDTH (ACC_WIDTH)
    ) mac_u_i (
      .clk    (clk),
      .rst  (rst),
      .en     (mac_en[j]),
      .a      (mac_a[j]),
      .b      (mac_b[j]),
      .acc_in (mac_acc_in[j]),
      .acc_out(mac_acc_out[j])
    );
  end


  //? Controller FSM ?//
  //  Takes `in_vector` in one go, then:
  //   ? for each out_idx = 0..OUT_DIM-1
  //       ? for in_idx = 0..IN_DIM-1: drive mac_a = in_vector[?], mac_b = w_data
  //       ? accumulate in mac_acc_in/reg
  //     ? once done, fetch b_data, add+truncate to Q4.12
  //     ? pack result into out_vector chunk
FC_CONTROLLER #(
  .DATA_WIDTH(DATA_WIDTH),
  .ACC_WIDTH (ACC_WIDTH),
  .IN_DIM    (IN_DIM),
  .OUT_DIM   (OUT_DIM),
  .K(K)
) fc2_ctrl (
  .clk        (clk),
  .rst      (rst),
  .start      (start),
  .in_vector  (in_vector),

  // Weight memory interface
  .w_req      (w_req),     // logic [K-1:0]
  .w_addr     (w_addr),    // [0:K-1]
  .w_data     (w_data),    // [0:K-1]

  // Bias memory interface
  .b_req      (b_req),     // logic [K-1:0]
  .b_addr     (b_addr),    // [0:K-1]
  .b_data     (b_data),    // [0:K-1]

  // MAC interface
  .mac_en     (mac_en),        // [K-1:0]
  .mac_a      (mac_a),         // [0:K-1]
  .mac_b      (mac_b),         // [0:K-1]
  .mac_acc_in(mac_acc_in),     // [0:K-1]
  .mac_acc_out(mac_acc_out),   // [0:K-1]

  // Output bus
  .out_vector (out_vector),
  .out_done  (out_done)
);


endmodule



