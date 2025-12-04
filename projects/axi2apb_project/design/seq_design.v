module seq_design(input in,clk,rst,output reg out);
	parameter s0=0,
		  s1=1,
		  s2=2,
		  s3=3,
		  s4=4;	
	reg [2:0] state;
	always @(posedge clk or posedge rst) begin
	if(rst)
		state <= s0;
	else begin
		case(state)
			s0:state<=(in==1)?s1:s0;
			s1:state<=(in==0)?s2:s1;
			s2:state<=(in==1)?s3:s0;
			s3:state<=(in==1)?s4:s2;
			s4:state<=(in==0)?s2:s1;
		endcase
		out = state == 3'b100;
	end
	end
endmodule
