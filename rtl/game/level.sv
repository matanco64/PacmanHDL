module level (
    input  logic clk,
    input  logic resetN,
    input  logic level_key,      // Button input (active high)
	 input  logic isWin,
	 input  logic [2:0] gameState,
    output logic [3:0] level,     // Output level: 1 to 3 (4 bits for display)
	 output logic levelChange     // Output level: 1 to 3 (4 bits for display)
);

	 localparam N_LEVELS = 5;
	 // game state
	 localparam RESET_ST = 3'b000;
    logic level_key_prev;
	 logic winFlag;

    always_ff @(posedge clk) begin
        if (!resetN) begin
            level <= 4'd1;           // Start at level 1
            level_key_prev <= 1'b1;  // Assume button is released (high)
				levelChange <=0;
				winFlag <= 0;
        end else begin
				if (isWin) winFlag <=1;
				if(winFlag && gameState == RESET_ST) begin // WIN_ST will lead to RESET_ST no need to cause it from here
					level <= (level == N_LEVELS)?  4'd1 : level + 1;
					winFlag <= 0;
				end
            if (!level_key && level_key_prev) begin // falling edge of btn
					level <= (level == N_LEVELS)?  4'd1 : level + 1;
					levelChange <=1;  // causes the RESET_ST
				end else levelChange<=0;
            level_key_prev <= level_key;
        end
    end

endmodule
