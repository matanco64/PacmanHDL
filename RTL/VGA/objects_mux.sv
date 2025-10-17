module	objects_mux	(	
//		--------	Clock Input	 	
					input		logic	clk,
					input		logic	resetN,
					input		logic	[7:0] RGB_MIF, 
					
			// fog 
					input		logic fogDR, 
					input		logic	[7:0] fogRGB, 
					
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
			// blinky 
					input		logic blinkyDR, 
					input		logic	[7:0] blinkyRGB,			
					     

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
			// heart 
					input		logic heartDR, 
					input		logic	[7:0] heartRGB,	
			// end 
					input		logic endDR, 
					input		logic	[7:0] endRGB,	
			// level
					input		logic levelTxtDR, 
					input		logic	[7:0] levelTxtRGB,	
			// Num
					input		logic levelNumDR, 
					input		logic	[7:0] levelNumRGB,		
			  
		   // Map
					input		logic MapDR, 
					input		logic CoinDR, 
					input		logic powerDR, 
					input		logic pickUpDR, 
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
		
		// fog	
		else if (fogDR)
			RGBOut <= fogRGB;	
			
		// ghosts	
		else if (pinkyDR)
			RGBOut <= pinkyRGB;
		else if (inkyDR)
			RGBOut <= inkyRGB;
		else if (clydeDR)
			RGBOut <= clydeRGB;
		else if (blinkyDR)
			RGBOut <= blinkyRGB;	
			
		// text	
		else if (Score0DR)
			RGBOut <= Score0RGB;
		else if (Score1DR)
			RGBOut <= Score1RGB;	
		else if (Score2DR)
			RGBOut <= Score2RGB;		
		else if (ScoreTxtDR)
			RGBOut <= ScoreTxtRGB;	
		else if (levelTxtDR)
			RGBOut <= levelTxtRGB;	
		else if (levelNumDR)
			RGBOut <= levelNumRGB;	
			
		// map	
		else if (MapDR || CoinDR || powerDR || pickUpDR)
			RGBOut <= MapRGB;
		
		// side	
		else if (endDR)
			RGBOut <= endRGB;
		else if (heartDR)
			RGBOut <= heartRGB;

			
		else RGBOut <= RGB_MIF ;// last priority 
		end ; 
	end

endmodule

