//`include "fixed_point_adapter.sv"

module FC_CONTROLLER #(
  parameter DATA_WIDTH = 16,
  parameter ACC_WIDTH  = 32,
  parameter IN_DIM     = 200,
  parameter OUT_DIM    = 100,
  parameter K          = 4            // �? new: number of parallel neurons
)(
  input  logic                          clk,
  input  logic                          rst,
  input  logic                          start,

  // Unpacked input/output arrays
  input  logic signed [DATA_WIDTH-1:0]  in_vector  [0:IN_DIM-1],
  output logic signed [DATA_WIDTH-1:0]  out_vector [0:OUT_DIM-1],
  output logic                          out_done,   // pulses when full vector ready

  // Weight memory interface
  /*output logic                         w_req,
  output logic [$clog2(IN_DIM*OUT_DIM)-1:0] w_addr,
  input  logic signed [DATA_WIDTH-1:0]      w_data,*/

  // ** Weight memory: now K read-ports **
  output logic [K-1:0]                         w_req,
  output logic [$clog2(IN_DIM*OUT_DIM)-1:0]    w_addr  [0:K-1],
  input  logic signed [DATA_WIDTH-1:0]         w_data  [0:K-1],

  // --- BIAS memory: now K read‑ports ---
  output logic [K-1:0]                      b_req,
  output logic [$clog2(OUT_DIM)-1:0]        b_addr  [0:K-1],
  input  logic signed [DATA_WIDTH-1:0]      b_data  [0:K-1],

  // Bias memory interface
  /*output logic                         b_req,
  output logic [$clog2(OUT_DIM)-1:0]       b_addr,
  input  logic signed [DATA_WIDTH-1:0]      b_data,*/

  // MAC interface
  /*output logic                         mac_en,
  output logic signed [DATA_WIDTH-1:0]  mac_a,
  output logic signed [DATA_WIDTH-1:0]  mac_b,
  output logic signed [ACC_WIDTH-1:0]   mac_acc_in,
  input  logic signed [ACC_WIDTH-1:0]   mac_acc_out*/

  // ** MAC interfaces: arrays of lanes **
  output logic [K-1:0]                         mac_en,
  output logic signed [DATA_WIDTH-1:0]         mac_a   [0:K-1],
  output logic signed [DATA_WIDTH-1:0]         mac_b   [0:K-1],
  output logic signed [ACC_WIDTH-1:0]          mac_acc_in [0:K-1],
  input  logic signed [ACC_WIDTH-1:0]          mac_acc_out[0:K-1]
);


  // FSM states
  typedef enum logic [3:0] {
    S_IDLE,
    S_MAC_REQ,
    S_MAC_EXEC,
    S_MAC_STORE,
    S_BIAS_REQ,
    S_BIAS_STORE,
    S_PACK_OUT,
    S_DONE
  } state_t;

  state_t          state, next_state;

  // Pointers
  logic [$clog2(IN_DIM)-1:0]  in_idx;
  logic [$clog2(OUT_DIM)-1:0] base_out_idx;  // steps in increments of K
  //logic [$clog2(OUT_DIM)-1:0] out_idx;

  // Registers for datapath
  //logic signed [ACC_WIDTH-1:0]       acc_reg;
  logic signed [ACC_WIDTH-1:0] acc_reg [0:K-1];
  //logic signed [TOTAL_WIDTH-1:0]     fp_accum, fp_bias, fp_result;
  logic signed [DATA_WIDTH-1:0] fp_accum [0:K-1],fp_bias  [0:K-1];
  logic signed [DATA_WIDTH-1:0]      out_vector_reg [0:OUT_DIM-1];

  // Drive the public out_vector and out_done
  assign out_vector = out_vector_reg;
  assign out_done   = (state == S_DONE);

  // Instantiate fixed_point_adapter for each lane
logic signed [DATA_WIDTH-1:0] fixed_add_result   [0:K-1];
logic signed [DATA_WIDTH-1:0] trunc_sat_acc_result [0:K-1];

genvar i;
generate
  for (i = 0; i < K; i++) begin : fixed_point_adapters
    fixed_point_adapter #(
      .INT_WIDTH(4),
      .FRAC_WIDTH(12),
      .TOTAL_WIDTH(DATA_WIDTH),
      .ACC_WIDTH(ACC_WIDTH)
    ) fpa_inst (
      .a        (fp_accum[i]),
      .b        (fp_bias[i]),
      .acc_val  (acc_reg[i]),
      .fixed_add_result    (fixed_add_result[i]),
      .trunc_sat_acc_result(trunc_sat_acc_result[i])
    );
  end
endgenerate

  //------------------------------------------------------------------------
  // 1) State & Datapath Registers
  //------------------------------------------------------------------------
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state          <= S_IDLE;
      in_idx         <= '0;
      //out_idx        <= '0;
      base_out_idx   <= '0;
      //acc_reg        <= '0;
      //fp_accum       <= '0;
      //fp_bias        <= '0;
      for (int k = 0; k < K; k++) begin
        fp_accum[k]      <= '0;
        fp_bias[k]       <= '0;
      end
      for (int k = 0; k < K; k++)
        acc_reg[k] <= '0;
      for (int i = 0; i < OUT_DIM; i++)
        out_vector_reg[i] <= '0;
    end else begin
      state <= next_state;
      case (state)
        S_IDLE: if (start) begin
          in_idx  <= '0;
          //out_idx <= '0;
          base_out_idx   <= '0;   // start at neuron 0
        end

        S_MAC_STORE: begin
          //acc_reg <= mac_acc_out;
          for (int k = 0; k < K; k++)
            acc_reg[k] <= mac_acc_out[k];
          in_idx  <= in_idx + 1;
        end

        S_BIAS_REQ: begin
        // nothing to capture yet
        end

        S_BIAS_STORE: begin
          // Truncate each accumulator to fixed format:
          for (int k = 0; k < K; k++) begin
            fp_accum[k] <= trunc_sat_acc_result[k];
            fp_bias[k]  <= b_data[k];
          end
        end

        S_PACK_OUT: begin
          // Add bias and write all K outputs in parallel
          for (int k = 0; k < K; k++) begin
            out_vector_reg[base_out_idx + k] <= fixed_add_result[k];
          end
          base_out_idx <= base_out_idx + K;
        end

        default: ;
      endcase
    end
  end

  //------------------------------------------------------------------------
  // 2) Next‑State Logic
  //------------------------------------------------------------------------
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE:
        if (start) next_state = S_MAC_REQ;

      S_MAC_REQ:
        next_state = S_MAC_EXEC;

      S_MAC_EXEC:
        next_state = S_MAC_STORE;

      S_MAC_STORE:
        if (in_idx + 1 == IN_DIM)
          next_state = S_BIAS_REQ;
        else
          next_state = S_MAC_REQ;

      S_BIAS_REQ:
        next_state = S_BIAS_STORE;

      S_BIAS_STORE:
        next_state = S_PACK_OUT;  

      S_PACK_OUT:
        if (base_out_idx + K >= OUT_DIM) //out_idx + 1 == OUT_DIM
          next_state = S_DONE;
        else
          next_state = S_MAC_REQ;

      S_DONE:
        if (!start)
          next_state = S_IDLE;


      default:
        next_state = S_IDLE;
    endcase
  end

  //------------------------------------------------------------------------
  // 3) Output Logic (combinational)
  //------------------------------------------------------------------------
  always_comb begin
    // defaults
    w_req      = 0;
    for (int k = 0; k < K; k++) begin
      w_addr[k]     = '0;
      mac_en[k]     = 1'b0;
      mac_a[k]      = '0;
      mac_b[k]      = '0;
      mac_acc_in[k] = '0;
    end
    /*w_addr     = '0;
    mac_en     = 0;
    mac_a      = '0;
    mac_b      = '0;
    mac_acc_in = '0;*/
    b_req      = 0;
    b_addr     = '{default:'0};

    case (state)
      S_MAC_REQ: begin
        w_req  = 1;
        //w_addr = out_idx * IN_DIM + in_idx;
        // issue K weight requests in parallel:
        for (int k = 0; k < K; k++) begin
          w_req[k]  = 1'b1;
          // each lane reads its own weight:
          w_addr[k] = (base_out_idx + k) * IN_DIM + in_idx;
        end
      end

      S_MAC_EXEC: begin
        for (int k = 0; k < K; k++) begin
          mac_en[k]     = 1'b1;
          mac_a[k]      = in_vector[in_idx];
          mac_b[k]      = w_data[k];
          // first MAC in each dot-product chain starts from zero:
          mac_acc_in[k] = (in_idx == 0) ? '0 : acc_reg[k];
        end
        /*mac_en     = 1; 
        mac_a      = in_vector[in_idx];
        mac_b      = w_data;
        mac_acc_in = (in_idx == 0) ? '0 : acc_reg;*/
      end

      S_BIAS_REQ: begin
        for (int k = 0; k < K; k++) begin
          b_req[k]  = 1'b1;
          b_addr[k] = base_out_idx + k;
        end
      end

      default: ;
    endcase
  end


endmodule
