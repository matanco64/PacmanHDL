module	objects_mux	(	
//		--------	Clock Input	 	
					input		logic	clk,
					input		logic	resetN,
					input		logic	[7:0] RGB_MIF, 
		   // pacman 
					input		logic PacmanDR, 
					input		logic	[7:0] PacmanRGB, 
			// pinky 
					input		logic pinkyDR, 
					input		logic	[7:0] pinkyRGB,	
			// inky 
					input		logic inkyDR, 
					input		logic	[7:0] inkyRGB,	
			// clyde 
					input		logic clydeDR, 
					input		logic	[7:0] clydeRGB,			
					     

		   // Score0 
					input		logic Score0DR, 
			 		input		logic	[7:0] Score0RGB,
		   // Score1 
					input		logic Score1DR, 
					input		logic	[7:0] Score1RGB, 	
		   // Score2 
					input		logic Score2DR, 
					input		logic	[7:0] Score2RGB, 		
		   // ScoreTxt 
					input		logic ScoreTxtDR, 
					input		logic	[7:0] ScoreTxtRGB,		
			  
		  
		  
					input		logic MapDR, 
					input		logic CoinDR, 
					input		logic	[7:0] MapRGB,
			  
				   output	logic	[7:0] RGBOut
);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
			RGBOut	<= 8'b0;
	end
	
	else begin	
		if (PacmanDR) 
			RGBOut <= PacmanRGB;  //first priority 
			
		// ghosts	
		else if (pinkyDR)
			RGBOut <= pinkyRGB;
		else if (inkyDR)
			RGBOut <= inkyRGB;
		else if (clydeDR)
			RGBOut <= clydeRGB;
			
		// score	
		else if (Score0DR)
			RGBOut <= Score0RGB;
		else if (Score1DR)
			RGBOut <= Score1RGB;	
		else if (Score2DR)
			RGBOut <= Score2RGB;		
		else if (ScoreTxtDR)
			RGBOut <= ScoreTxtRGB;
			
		// map	
		else if (MapDR || CoinDR)
			RGBOut <= MapRGB;
		else RGBOut <= RGB_MIF ;// last priority 
		end ; 
	end

endmodule


