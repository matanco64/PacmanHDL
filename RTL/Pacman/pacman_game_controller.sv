module	pacman_game_controller	(	
			input	logic	clk,
			input	logic	resetN,
			input	logic	startOfFrame,
			
			// DR
			input logic pacDR,
			input logic wallsDR,
			input logic coinDR,
			input logic blinkeyDR,
			input logic pinkeyDR,
			input logic inkyDR,
			input logic clydeDR,

			
			output logic SingleHitPulse,
			output logic collision_pac_wall,
			output logic collision_pac_coin,
			output logic [2:0] collision_pac_ghost, // 0=no-colision 1=Blinkey 2=Pinkey ...
			output logic [3:0] score0,   // score[0]
			output logic [3:0] score1,    // score[1]
			output logic [3:0] score2    // score[2]
);

// logic flag ; // a semaphore to set the output only once per frame regardless of number of collisions

assign collision_pac_wall = pacDR && wallsDR;
assign collision_pac_coin = pacDR && coinDR;

logic coin_flag;

always_comb begin
    collision_pac_ghost = 3'd0;  // default: no collision

    if (pacDR) begin
        if (blinkeyDR) begin
            collision_pac_ghost = 3'd1;
        end else if (pinkeyDR) begin
            collision_pac_ghost = 3'd2;
        end else if (inkyDR) begin
            collision_pac_ghost = 3'd3;
        end else if (clydeDR) begin
            collision_pac_ghost = 3'd4;
        end
    end
end


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
				
		if (collision_pac_wall  && (SingleHitPulse == 1'b0)) begin 
			SingleHitPulse <= 1'b1 ; // to enter only once 
		end 
		
		if (collision_pac_coin && !coin_flag) begin
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