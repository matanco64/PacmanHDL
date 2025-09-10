module	objects_mux	(	
//		--------	Clock Input	 	
					input		logic	clk,
					input		logic	resetN,
		   // pacman 
					input		logic PacmanDrawingRequest, 
					input		logic	[7:0] PacmanRGB, 
					     
		  // add the box here 
					
			  
		  ////////////////////////
		  // background   
//					input		logic	[7:0] backGroundRGB, 
//					input		logic	BGDrawingRequest, 
					input		logic	[7:0] RGB_MIF, 
			  
				   output	logic	[7:0] RGBOut
);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
			RGBOut	<= 8'b0;
	end
	
	else begin
		if (PacmanDrawingRequest == 1'b1 )   
			RGBOut <= PacmanRGB;  //first priority 
		else RGBOut <= RGB_MIF ;// last priority 
		end ; 
	end

endmodule


