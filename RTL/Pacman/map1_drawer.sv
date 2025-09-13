module map1_drawer (
	input	logic	clk,
	input logic resetN,
	input logic signed	[10:0] pixelX,//  current VGA pixel 
	input 	logic signed	[10:0] pixelY,
	output	logic	drawingRequest, // output that the pixel should be displayed
	output	logic	[7:0] RGBout  // rgb value from the bitmap
);




  // ---- Coordinates for spawns (0-based: x in [0..27], y in [0..30]) ----
  // Pac-Man spawns below the house, centered.
  localparam int PAC_X = 13;
  localparam int PAC_Y = 23;

  // Ghosts start inside the house (roughly center area).
  // 3=Blinky, 4=Pinky, 5=Inky, 6=Clyde
  localparam int BLINKY_X = 13, BLINKY_Y = 14;
  localparam int PINKY_X  = 13, PINKY_Y  = 15;
  localparam int INKY_X   = 12, INKY_Y   = 15;
  localparam int CLYDE_X  = 14, CLYDE_Y  = 15;
  localparam MAP_HEIGHT_Y = 31;
  localparam MAP_WIDTH_X = 28;
  localparam OBJECT_COLOR = 8'b00000011;
  localparam TILE_SIZE = 16; // IMPORTANT TO KEEP 2^n
  
	
	logic [0:30][0:27][1:0] pacmanMap = {
	  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 3'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd0, 2'd0, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
	  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1 },
	  { 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1, 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd0, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd0, 2'd1 },
	  { 2'd1, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd1 },
	  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
	};



logic [1:0] tile;
	

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout			<=	8'b0;
		drawingRequest	<=	1'b0;
	end
	else begin 
		RGBout <= 8'b0 ;
		drawingRequest <= 1'b0 ;
		if (pixelY / TILE_SIZE >= 1) begin 
			tile = pacmanMap[pixelX / TILE_SIZE][pixelY / TILE_SIZE - 1];
			if(tile == 2'd1 || tile == 2'd2) begin
				RGBout <= OBJECT_COLOR ;
				drawingRequest <= 1'b1;
				
			end
		end
	end 
end

endmodule