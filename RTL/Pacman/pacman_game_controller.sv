module	pacman_game_controller	(	
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,
			input logic drawingRequestPacman,
			input logic drawingRequestWalls,
			input logic drawingRequestCoin,
			output logic SingleHitPulse,
			output logic collision_with_wall,
			output logic collision_with_coin,
			output logic [3:0] score0,   // score[0]
			output logic [3:0] score1,    // score[1]
			output logic [3:0] score2    // score[2]
);

// logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions

assign collision_with_wall = drawingRequestPacman && drawingRequestWalls;
assign collision_with_coin = drawingRequestPacman && drawingRequestCoin;
logic coin_flag;


always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN)
	begin 
		SingleHitPulse <= 1'b0 ;
		coin_flag <= 1'b0;
		score0 <= 4'd0;
		score1 <= 4'd0;
		score2 <= 4'd0;
	end 
	else begin 
		
		if(startOfFrame) begin
			SingleHitPulse <= 1'b0 ; // reset for next time
			coin_flag <= 1'b0;
		end	
				
		if (collision_with_wall  && (SingleHitPulse == 1'b0)) begin 
			SingleHitPulse <= 1'b1 ; // to enter only once 
		end 
		
		if (collision_with_coin && !coin_flag) begin
			if (score0 == 4'd9) begin
				if (score1 == 4'd9) begin
					score0 <= 4'd0;
					score1 <= 4'd0;
					score2 <= score2 + 4'd1;
				end else begin
					score0 <= 4'd0;
					score1 <= score1 + 4'd1;
				end
			end else begin
				score0 <=  score0 + 4'd1;
			end
			coin_flag <= 1'b1;
		end
			
	end 
end


endmodule 