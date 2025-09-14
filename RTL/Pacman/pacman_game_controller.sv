module	pacman_game_controller	(	
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,
			input logic drawingRequestPacman,
			input logic drawingRequestWalls,
			input logic drawingRequestCoin,
			output logic SingleHitPulse,
			output logic collision_with_wall
);

// logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions

assign collision_with_wall = drawingRequestPacman && drawingRequestWalls;


always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN)
	begin 
		SingleHitPulse <= 1'b0 ;
	end 
	else begin 
		
		if(startOfFrame) begin
			SingleHitPulse <= 1'b0 ; // reset for next time
		end	
				
		if (collision_with_wall  && (SingleHitPulse == 1'b0)) begin 
			SingleHitPulse <= 1'b1 ; // to enter only once 
		end 
	end 
end


endmodule 