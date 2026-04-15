module argmax (
	input  wire        clk,
	input wire         reset,
	input wire         start,

	input  wire signed [15:0] y_in,    
	input  wire [3:0]  idx,            

	output reg  [3:0]  pred,           
	output reg         done
);

	reg signed [15:0] max_val;

	always @(posedge clk or posedge reset) begin
		if (reset) begin 
			pred<=0; 
			max_val<=16'sh8000; 
			done<=0; 
		end
		else if (start) begin
			if (y_in > max_val) begin 
				max_val <= y_in;
				pred <= idx; 
			end
			done <= (idx == 4'd9);
		end
	end
	
endmodule