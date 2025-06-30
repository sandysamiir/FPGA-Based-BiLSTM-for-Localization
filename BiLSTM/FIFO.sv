module FIFO #(
	parameter FIFO_WIDTH = 32,
    parameter FIFO_DEPTH = 8)
	(clk, rst, wr_en, rd_en, wr_ack, overflow, full, empty, almostfull, almostempty, underflow, data_in, data_out);
	input clk, rst, wr_en, rd_en;
	input signed [FIFO_WIDTH-1:0] data_in;
	output reg wr_ack, overflow, full, empty, almostfull, almostempty, underflow;
	output reg signed [FIFO_WIDTH-1:0] data_out;
 
	localparam max_fifo_addr = $clog2(FIFO_DEPTH);
	reg signed [FIFO_WIDTH-1:0] mem [FIFO_DEPTH-1:0];
	reg [max_fifo_addr-1:0] wr_ptr, rd_ptr;
	reg [max_fifo_addr:0] count;
    integer i;
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			wr_ptr <= 0;
			wr_ack <= 0;
			overflow <= 0;
			for( i = 0; i < FIFO_DEPTH; i = i + 1) begin
				mem[i] <= 0;
			end
		end
		else if (wr_en && !full) begin
			mem[wr_ptr] <= data_in;
			wr_ack <= 1;
			wr_ptr <= wr_ptr + 1;
			overflow <= 0;
		end
		else begin 
			wr_ack <= 0; 
			if (full && wr_en) 
				overflow <= 1;
			else
				overflow <= 0;
		end
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			rd_ptr <= 0;
			underflow <= 0;
			data_out <= 0;
		end
		else if (rd_en && !empty) begin
			data_out <= mem[rd_ptr];
			rd_ptr <= rd_ptr + 1;
			underflow <= 0;
		end
		else if (rd_en && empty)
			underflow <= 1;
		else	
			underflow <= 0;
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			count <= 0;
		end
		else begin
			if	( (({wr_en, rd_en} == 2'b10) && !full)) 
				count <= count + 1;
			else if ( (({wr_en, rd_en} == 2'b01) && !empty))
				count <= count - 1;
			else if ( (({wr_en, rd_en} == 2'b11) && empty))
				count <= count + 1;	
			else if ( (({wr_en, rd_en} == 2'b11) && full))
				count <= count - 1;	
		end
	end

	assign full = (count == FIFO_DEPTH)? 1 : 0;
	assign empty = (count == 0)? 1 : 0;
	assign almostfull = (count == FIFO_DEPTH-1)? 1 : 0; 
	assign almostempty = (count == 1)? 1 : 0;

endmodule