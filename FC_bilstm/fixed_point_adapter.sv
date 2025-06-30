// Q4.12 Fixed-Point Adapter as a combinational logic module
module fixed_point_adapter #(
    parameter INT_WIDTH   = 4,
    parameter FRAC_WIDTH  = 12,
    parameter TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH,
    parameter ACC_WIDTH   = 32
)(
    // Inputs for fixed_add
    input  logic signed [TOTAL_WIDTH-1:0] a,
    input  logic signed [TOTAL_WIDTH-1:0] b,
    // Input for trunc_sat_acc
    input  logic signed [ACC_WIDTH-1:0]   acc_val,
    // Output for fixed_add
    output logic signed [TOTAL_WIDTH-1:0] fixed_add_result,
    // Output for trunc_sat_acc
    output logic signed [TOTAL_WIDTH-1:0] trunc_sat_acc_result
);

    // Fixed-point addition with saturation
    always_comb begin
        logic signed [TOTAL_WIDTH:0] sum_ext;
        logic signed [TOTAL_WIDTH-1:0] max_pos, min_neg;

        sum_ext = {a[TOTAL_WIDTH-1], a} + {b[TOTAL_WIDTH-1], b};
        max_pos = {1'b0, {TOTAL_WIDTH-1{1'b1}}};  // 0x7FFF = +7.999756
        min_neg = {1'b1, {TOTAL_WIDTH-1{1'b0}}};  // 0x8000 = -8.000000

        if (sum_ext > $signed({1'b0, max_pos}))
            fixed_add_result = max_pos;
        else if (sum_ext < $signed({1'b1, min_neg}))
            fixed_add_result = min_neg;
        else
            fixed_add_result = sum_ext[TOTAL_WIDTH-1:0];
    end

    // Truncate+sat the ACC_WIDTH-bit accumulator into Q4.12
    always_comb begin
        localparam logic signed [ACC_WIDTH-1:0] ACC_MAX = (16'sh7FFF <<< FRAC_WIDTH);
        localparam logic signed [ACC_WIDTH-1:0] ACC_MIN = (16'sh8000 <<< FRAC_WIDTH);

        if (acc_val > ACC_MAX)
            trunc_sat_acc_result = 16'sh7FFF;         // clamp to +7.999
        else if (acc_val < ACC_MIN)
            trunc_sat_acc_result = 16'sh8000;         // clamp to –8.000
        else
            trunc_sat_acc_result = acc_val >>> FRAC_WIDTH; // normal truncation
    end

endmodule