module	objects_mux	(	
//		--------	Clock Input	 	
					input		logic	clk,
					input		logic	resetN,
					input		logic	[7:0] RGB_MIF, 
		   // pacman 
					input		logic PacmanDrawingRequest, 
					input		logic	[7:0] PacmanRGB, 
			// pinky 
					input		logic pinkyDR, 
					input		logic	[7:0] pinkyRGB,	
			// inky 
					input		logic inkyDR, 
					input		logic	[7:0] inkyRGB,	
			// pinky 
					input		logic clydeDR, 
					input		logic	[7:0] clydeRGB,			
					     
		  // ScoreMSB 
					input		logic ScoreMSBDrawingRequest, 
					input		logic	[7:0] ScoreMSBRGB, 
		  // ScoreLSB 
					input		logic ScoreLSBDrawingRequest, 
					input		logic	[7:0] ScoreLSBRGB,
		  // ScoreTxt 
					input		logic ScoreTxtDrawingRequest, 
					input		logic	[7:0] ScoreTxtRGB,		
			  
		  
		  
					input		logic MapDrawingRequest, 
					input		logic	[7:0] MapRGB,
		  // background   
//					input		logic	[7:0] backGroundRGB, 
//					input		logic	BGDrawingRequest, 
			  
				   output	logic	[7:0] RGBOut
);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
			RGBOut	<= 8'b0;
	end
	
	else begin	
		if (PacmanDrawingRequest) 
			RGBOut <= PacmanRGB;  //first priority 
		else if (pinkyDR)
			RGBOut <= pinkyRGB;
		else if (inkyDR)
			RGBOut <= inkyRGB;
		else if (clydeDR)
			RGBOut <= clydeRGB;
			
		else if (ScoreMSBDrawingRequest)
			RGBOut <= ScoreMSBRGB;	
		else if (ScoreLSBDrawingRequest)
			RGBOut <= ScoreLSBRGB;
		else if (ScoreTxtDrawingRequest)
			RGBOut <= ScoreTxtRGB;		
		else if (MapDrawingRequest == 1'b1 )
			RGBOut <= MapRGB;
		else RGBOut <= RGB_MIF ;// last priority 
		end ; 
	end

endmodule


