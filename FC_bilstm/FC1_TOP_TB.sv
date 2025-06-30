`timescale 1ns/1ps

module FC1_TOP_TB;

  // ------------------------------------------------------------------
  // Parameters for this TB
  localparam DATA_WIDTH = 16;
  localparam ACC_WIDTH  = 32;
  localparam IN_DIM     = 200;
  localparam OUT_DIM    = 100;
  localparam TOTAL_WIDTH = 4 + 12;  // Q4.12

  // ------------------------------------------------------------------
  // Clock, reset, and control
  logic clk;
  logic rst_n;
  logic start;
  logic signed [DATA_WIDTH-1:0] in_vector  [0:IN_DIM-1];
  logic signed [DATA_WIDTH-1:0] out_vector [0:OUT_DIM-1];
  logic                         out_done;

  // ------------------------------------------------------------------
  // Instantiate DUT
  FC1_TOP #(
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH (ACC_WIDTH),
    .IN_DIM    (IN_DIM),
    .OUT_DIM   (OUT_DIM)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start),
    .in_vector  (in_vector),
    .out_vector (out_vector),
    .out_done   (out_done)
  );

  // ------------------------------------------------------------------
  // Clock generation: 10 ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // ------------------------------------------------------------------
  // Monitor out_done signal for debugging
  always @(posedge clk) begin
    if (out_done) begin
      $display("Time %0t: out_done asserted", $time);
    end
  end

  // ------------------------------------------------------------------
  // Test sequence
  initial begin
    integer i;
    logic signed [TOTAL_WIDTH-1:0] expected [0:OUT_DIM-1];
    logic signed [TOTAL_WIDTH-1:0] received [0:OUT_DIM-1];

    $display("Starting FC_TOP testbench...");

    // 1) Apply reset
    rst_n     = 0;
    start     = 0;
    #20;
    rst_n = 1;
    #20;

    // 2) Load input vector from input.mem
    $display("Loading input vector from input.mem...");
    $readmemh("input.mem", in_vector);
    
    // Display first few input values for verification
    $display("First 10 input values:");
    for (i = 0; i < 10 && i < IN_DIM; i++) begin
      $display("in_vector[%0d] = %h", i, in_vector[i]);
    end
    
    #10;

    // 3) Set expected values (adjust these based on your actual expected results)
    expected[0] = 16'h7fff;
    expected[1] = 16'h7fff;

    // 4) Pulse start
    $display("Starting computation at time %0t", $time);
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;
    $display("Start pulse completed at time %0t", $time);

    // 5) Wait for done pulse with timeout
    fork
      begin
        // Wait for out_done to go high
        @(posedge out_done);
        $display("out_done detected at time %0t", $time);
        
        // Capture outputs immediately when done goes high
        for (i = 0; i < OUT_DIM; i++) begin
          received[i] = out_vector[i];
        end
        
        // Display output vector immediately
        $display("\n=== OUTPUT VECTOR (captured on out_done) ===");
        for (i = 0; i < OUT_DIM; i++) begin
          $display("out_vector[%0d] = %h (%0d)", i, out_vector[i], $signed(out_vector[i]));
        end
        $display("==========================================\n");
      end
      begin
        // Timeout after reasonable time
        #2000000; // Adjust timeout as needed
        $display("ERROR: Timeout waiting for out_done!");
        $finish;
      end
    join_any
    disable fork;

    // 6) Additional sampling after a few clock cycles (in case timing is critical)
    repeat(3) @(posedge clk);
    
    $display("\n=== OUTPUT VECTOR (after 3 clocks) ===");
    for (i = 0; i < OUT_DIM; i++) begin
      $display("out_vector[%0d] = %h (%0d)", i, out_vector[i], $signed(out_vector[i]));
    end
    $display("=====================================\n");

    // 7) Optionally save outputs to file
    begin
      integer file;
      file = $fopen("output_results.txt", "w");
      if (file) begin
        $fwrite(file, "Output Vector Results:\n");
        for (i = 0; i < OUT_DIM; i++) begin
          $fwrite(file, "out_vector[%d] = %h (%d)\n", i, out_vector[i], $signed(out_vector[i]));
        end
        $fclose(file);
        $display("Results saved to output_results.txt");
      end
    end

    $display("Testbench completed successfully!");
    #50;
    $finish;
  end

  // ------------------------------------------------------------------
  // Additional monitoring for debugging
  initial begin
    // Monitor key signals
    $monitor("Time=%0t rst_n=%b start=%b out_done=%b", 
             $time, rst_n, start, out_done);
  end

endmodule
