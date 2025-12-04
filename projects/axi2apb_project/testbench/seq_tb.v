module seq_tb;
	reg clk,rst,x;
	wire y;
	initial clk=0;
	always #2.5 clk = ~clk;
	seq_design uut(.clk(clk),.rst(rst),.in(x),.out(y));
	initial begin
		$display("time\tclk\trst\tx\ty\t");
		$monitor("%0t\t%b\t%b\t%b\t%b\t",$time,clk,rst,x,y);
		x=1;rst=1;#10;
		x=1;rst=0;#10;
		x=0;#5;
		x=1;#5;
		x=1;#5;
		x=0;#5;
		x=1;#5;
		x=1;#5;
		x=0;#5;
		x=0;#5;
		x=1;#5;
		x=0;#5;
		$finish;
	end
endmodule
