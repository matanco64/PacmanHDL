module level (
    input  logic clk,
    input  logic resetN,
    input  logic level_key,      // Button input (active high)
    output logic [3:0] level,     // Output level: 1 to 3 (4 bits for display)
	 output logic levelChange     // Output level: 1 to 3 (4 bits for display)
);

	 localparam N_LEVELS = 5;
    logic level_key_prev;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            level <= 4'd1;           // Start at level 1
            level_key_prev <= 1'b1;  // Assume button is released (high)
				levelChange <=0;
        end else begin
            // Detect falling edge of button
            if (!level_key && level_key_prev) begin
					level <= (level == N_LEVELS)?  4'd1 : level + 1;
					levelChange <=1;
				end else levelChange<=0;
            level_key_prev <= level_key;
        end
    end

endmodule
