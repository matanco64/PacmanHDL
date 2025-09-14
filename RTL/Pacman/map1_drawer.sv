module map1_drawer (
	input	logic	clk,
	input logic resetN,
	input logic signed	[10:0] pixelX,//  current VGA pixel 
	input 	logic signed	[10:0] pixelY,
	input logic coinCollision,  // Marks collision with pacman and coin, relevant cell should be disabled.
	output	logic	drawingRequest, // output that the pixel should be displayed
	output	logic	drawingCoin, // ouput Whether a coin is drawn or not
	output	logic	[7:0] RGBout  // rgb value from the bitmap
	
	//Ghosts - inputs//
	input logic [10:0] PinkyOffsetX,
	input logic [10:0] PinkyOffsetY,
	
	////
	output	logic	drawingRequest, // output that the pixel should be displayed
	output	logic	[7:0] RGBout,  // rgb value from the bitmap
	
	//Ghosts - outputs//
	output	logic	[7:0] aroundPinky
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
  localparam COIN_COLOR = 8'b11000000;
  localparam TILE_SIZE = 16; // IMPORTANT TO KEEP 2^n
  localparam logic [7:0] TRANSPARENT_ENCODING = 8'h0;
  localparam logic [1:0] WALL = 2'd2;
  localparam logic [1:0] GHOST_WALL = 2'd3;
  localparam logic [1:0] COIN = 2'd1;
  localparam logic [1:0] EMPTY = 2'd0;
  

  logic [0:30][0:27][1:0] OriginalPacmanMap = { // Since we are mutating the Original Map when coins are eaten, we want an ability to reset it
  { 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2 },
  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd0, 2'd0, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
  { 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2 },
  { 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1 },
  { 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2 },
  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
  { 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
  { 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2 },
  { 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2, 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd1, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd1, 2'd2 },
  { 2'd2, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd2 },
  { 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2 },
};

logic [0:30][0:27][1:0] pacmanMap;





logic [1:0] tile;

assign Utile = pacmanMap[pixelX / TILE_SIZE][pixelY / TILE_SIZE - 2];
assign Dtile = pacmanMap[pixelX / TILE_SIZE][pixelY / TILE_SIZE];
assign Ltile = pacmanMap[pixelX / TILE_SIZE - 1][pixelY / TILE_SIZE];
assign Rtile = pacmanMap[pixelX / TILE_SIZE + 1][pixelY / TILE_SIZE];
//logic	[7:0] RGBDraw;

//maze_part maze_part ( .symbol(tile), .USymbol(Utile), .DSymbol(Dtile), .LSymbol(Ltile), .RSymbol(Rtile), .offsetX(pixelX % TILE_SIZE), .offsetY(pixelY % TILE_SIZE), .RGBout(RGBDraw));

logic [3:0] offsetX;
logic [3:0] offsetY;

  // Ghosts
	function automatic [7:0] aroundGhost(
		 input [10:0] ghostOffsetX,
		 input [10:0] ghostOffsetY
	);
		 logic [10:0] gx, gy;
		 begin
			  gx = ghostOffsetX / TILE_SIZE;
			  gy = ghostOffsetY / TILE_SIZE;
			  aroundGhost = {
					pacmanMap[gy - 1][gx], // Up
					pacmanMap[gy + 1][gx], // Down
					pacmanMap[gy][gx - 1], // Left
					pacmanMap[gy][gx + 1]  // Right
			  };
		 end
	endfunction
	
	assign aroundPinky = aroundGhost(PinkyOffsetX, PinkyOffsetY);

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout			<=	8'b0;
		drawingRequest	<=	1'b0;
		pacmanMap <= OriginalPacmanMap;
	end
	else begin 
		RGBout <= TRANSPARENT_ENCODING ;
		drawingRequest <= 1'b0 ;
		drawingCoin <= 1'b0;
		tile = pacmanMap[pixelX / TILE_SIZE][pixelY / TILE_SIZE - 1];
		if (pixelY / TILE_SIZE >= 1) begin 
			if(tile == WALL || tile == GHOST_WALL) begin
//				RGBout <= RGBDraw;
				RGBout <= OBJECT_COLOR;
				drawingRequest <= 1'b1;
				
			end
			
			if (tile == COIN) begin
				offsetX = pixelX % TILE_SIZE;
				offsetY = pixelY % TILE_SIZE;
				if (offsetX >= 6 && offsetX < 10 && offsetY >= 6 && offsetY < 10) begin
					RGBout <= COIN_COLOR;
					drawingCoin <= 1'b1;
				end
				if (coinCollision)
					pacmanMap[pixelX / TILE_SIZE][pixelY / TILE_SIZE - 1] <= EMPTY;
			end
			
		end
	end 
	
	
end

endmodule