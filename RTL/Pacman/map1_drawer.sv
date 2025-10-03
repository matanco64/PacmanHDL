module map1_drawer (
    input logic clk,
    input logic resetN,
    input logic signed [10:0] pixelX,  //  current VGA pixel 
    input logic signed [10:0] pixelY,
    input logic [7:0] rnd,
	 input logic oneSec,

    // Collisions
    input logic coinCollision,
    input logic powerCollision,
    input logic fruitCollision,

    //Ghosts - inputs//
    input logic [10:0] BlinkytopLeftX,
    input logic [10:0] BlinkytopLeftY,

    input logic [10:0] PinkytopLeftX,
    input logic [10:0] PinkytopLeftY,

    input logic [10:0] InkytopLeftX,
    input logic [10:0] InkytopLeftY,

    input logic [10:0] ClydetopLeftX,
    input logic [10:0] ClydetopLeftY,

    input logic [10:0] pactopLeftX,
    input logic [10:0] pactopLeftY,

    //outputs//
    output logic mapDR,
    output logic coinsDR,  // ouput Whether a coin is drawn or not
    output logic powerDR,
    output logic fruitDR,
    output logic [7:0] RGBout,

    //Ghosts - outputs - change if TILE_SIZE changes
    output logic [11:0] aroundBlinky,
    output logic [11:0] aroundPinky,
    output logic [11:0] aroundInky,
    output logic [11:0] aroundClyde,
    output logic [11:0] aroundPac,
    output logic [8:0] coinsPowTot,  // pow and coins!
    output logic [8:0] coinsCollected,
    output logic [8:0] powerCollected,
    output logic [8:0] fruitsCollected,
	 output logic [1:0] pacSpeedChange // 0=normal, 1=fast, 2=slow
);

  localparam MAP_HEIGHT_Y = 31;
  localparam MAP_WIDTH_X = 28;

  localparam WALL_COLOR = 8'b00000011;
  localparam GHOST_WALL_COLOR = 8'b10001111;
  localparam PORTAL_COLOR = 8'b01111111;
  localparam COIN_COLOR = 8'b11111111;
  localparam POW_COLOR = 8'b11111101;

  localparam TILE_SIZE = 16;  // IMPORTANT TO KEEP 2^n
  localparam TILE_BITS = 3; // 8 types of tiles, 3 bits each - if changed, change the map encoding too

  localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;
  
  localparam logic [TILE_BITS-1:0] EMPTY = 0;
  localparam logic [TILE_BITS-1:0] COIN = 1;
  localparam logic [TILE_BITS-1:0] WALL = 2;
  localparam logic [TILE_BITS-1:0] GHOST_WALL = 3;
  localparam logic [TILE_BITS-1:0] PORTAL = 4;
  localparam logic [TILE_BITS-1:0] POWER = 5;
  localparam logic [TILE_BITS-1:0] FRUIT = 6;
  

  // chery
  localparam NUM_FRUITS = 5;
  localparam int FRUIT_THRESH[0:NUM_FRUITS-1] = '{30, 45, 60, 75, 90};
  
  // pacman speed 
  localparam NORMAL_SPEED = 0;
  localparam FAST_SPEED = 1;
  localparam Slow_SPEED = 2;

  localparam TILE_SAVED = 16;  // IMPORTANT TO KEEP 2^n 
  logic [$clog2(MAP_WIDTH_X)-1:0] emptyTilesX[0:TILE_SAVED-1];
  logic [$clog2(MAP_HEIGHT_Y)-1:0] emptyTilesY[0:TILE_SAVED-1];
  logic [$clog2(NUM_FRUITS)-1:0] currFruit;
  logic [2:0] cherryCounter;     // 0..8
  
  logic [0:MAP_HEIGHT_Y-1][0:MAP_WIDTH_X-1][TILE_BITS-1:0] pacmanMap;
  logic [TILE_BITS-1:0] tile;

  logic [3:0] offsetX;
  logic [3:0] offsetY;
  logic coinFlag;
  logic powFlag;
  logic fruitFlag;


    logic [0:MAP_HEIGHT_Y-1][0:MAP_WIDTH_X-1][TILE_BITS-1:0] OriginalPacmanMap = { // Since we are mutating the Original Map when coins are eaten, we want an ability to reset it
    { 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2 },
    { 3'd2, 3'd5, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd2, 3'd2, 3'd5, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2 },
    { 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2 },
    { 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0 },
    { 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0 },
    { 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0 },
    { 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd3, 3'd0, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2 },
    { 3'd4, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd3, 3'd0, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd0, 3'd4 },
    { 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd3, 3'd0, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2 },
    { 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0 },
    { 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd2, 3'd2, 3'd1, 3'd2, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0 },
    { 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0 },
    { 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2 },
    { 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd2 },
    { 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2 },
    { 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2 },
    { 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2, 3'd2, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd1, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd1, 3'd2 },
    { 3'd2, 3'd5, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd1, 3'd1, 3'd5, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd2 },
    { 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2, 3'd2 }
  };

  logic [0:15] [0:15] [7:0] cherryMap = {
  {8'he3,8'he3,8'h10,8'h10,8'h10,8'h10,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'h10,8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he0,8'hff,8'he0,8'he0,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'hff,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3}};

  
  // ---------------------------------------------------------------------------
  // functions
  // ---------------------------------------------------------------------------

  // count coins in start map
  function automatic int countCoins(
      input logic [0:MAP_HEIGHT_Y-1][0:MAP_WIDTH_X-1][TILE_BITS-1:0] map);
    int total;
    begin
      total = 0;
      for (int y = 0; y < MAP_HEIGHT_Y; y++) begin
        for (int x = 0; x < MAP_WIDTH_X; x++) begin
          if (map[y][x] == COIN || map[y][x] == POWER) total++;
        end
      end
      return total;
    end
  endfunction

  // Around me 
  function automatic [4*TILE_BITS-1:0] aroundGhost(input [10:0] ghostTopLeftX,
                                                   input [10:0] ghostTopLeftY);
    logic [10:0] gx, gy;
    begin
      gx = ghostTopLeftX / TILE_SIZE;
      gy = ghostTopLeftY / TILE_SIZE - 1;  // in y axis there is a gap row

      aroundGhost = {  // bitmap is rotated!
        (gy > 0) ? pacmanMap[gx][gy-1] : WALL,  // Up
        (gy < MAP_HEIGHT_Y - 1) ? pacmanMap[gx][gy+1] : WALL,  // Down
        (gx > 0) ? pacmanMap[gx-1][gy] : WALL,  // Left
        (gx < MAP_WIDTH_X - 1) ? pacmanMap[gx+1][gy] : WALL  // Right
      };
    end
  endfunction


 


	// fruit collection and counter
	always_ff @(posedge clk or negedge resetN) begin
		 if (!resetN) begin
			  cherryCounter   <= 0;
			  pacSpeedChange  <= 0;
		 end else begin
			  if (fruitCollision && !fruitFlag) begin
					cherryCounter   <= 6;   // load timer for 6 seconds
					pacSpeedChange  <= 1;   // activate turbo
			  end else if (cherryCounter > 0 && oneSec) begin
					cherryCounter   <= cherryCounter - 1;
					if (cherryCounter == 1) begin
						 pacSpeedChange <= 0; // when counter reaches 0, return to normal
					end
			  end
		 end
	end

 // ---------------------------------------------------------------------------
  // rgb output logic + map update
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk or negedge resetN) begin

    if (!resetN) begin
      RGBout <= 8'b0;
      mapDR <= 1'b0;
      pacmanMap <= OriginalPacmanMap;
      coinsPowTot <= countCoins(OriginalPacmanMap);

      coinsCollected <= 0;
      powerCollected <= 0;
      fruitsCollected <= 0;

      coinFlag <= 0;
      powFlag <= 0;
      fruitFlag <= 0;
      currFruit <= 0;
		
    end else begin
      RGBout  <= TRANSPARENT_ENCODING;
      mapDR   <= 1'b0;
      coinsDR <= 1'b0;
      powerDR <= 1'b0;
      fruitDR <= 1'b0;
		
      tile = pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1];

      // FRUIT LOGIC - place fruit when enough coins collected
      if (currFruit < NUM_FRUITS && (coinsCollected * 100 / coinsPowTot) > FRUIT_THRESH[currFruit] ) begin
        logic [$clog2(TILE_SAVED)-1:0] idx;
        idx = rnd[$clog2(TILE_SAVED)-1:0];  // index in [0 .. TILE_SAVED-1]
        pacmanMap[emptyTilesX[idx]][emptyTilesY[idx]] <= FRUIT;  
        currFruit <= currFruit + 1'b1;
      end

      if (pixelY / TILE_SIZE >= 1) begin
        case (tile)
          GHOST_WALL: begin
            RGBout <= GHOST_WALL_COLOR;
            mapDR  <= 1'b1;
          end

          WALL: begin
            RGBout <= WALL_COLOR;
            mapDR  <= 1'b1;
          end

          PORTAL: begin
            RGBout <= PORTAL_COLOR;
            mapDR  <= 1'b1;
          end

          COIN: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            if (offsetX >= 6 && offsetX < 10 && offsetY >= 6 && offsetY < 10) begin
              RGBout  <= COIN_COLOR;
              coinsDR <= 1'b1;
            end
            if (coinCollision) begin
              pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
              if (!coinFlag) begin
                coinFlag <= 1'b1;
                coinsCollected <= coinsCollected + 1;

                ///add fruit logic - coinsCollected = empty tiles found
                if (coinsCollected < TILE_SAVED) begin
                  emptyTilesX[coinsCollected] <= pixelX / TILE_SIZE;
                  emptyTilesY[coinsCollected] <= pixelY / TILE_SIZE - 1;
                end else if (rnd[1:0] == 2'b10) begin  // 25% for a swap
                  emptyTilesX[rnd[3:0]] <= pixelX / TILE_SIZE;
                  emptyTilesY[rnd[3:0]] <= pixelY / TILE_SIZE - 1;
                end
              end
            end else coinFlag <= 1'b0;
          end

          POWER: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            if (offsetX >= 4 && offsetX < 12 && offsetY >= 4 && offsetY < 12) begin
              RGBout  <= POW_COLOR;
              powerDR <= 1'b1;
            end
            if (powerCollision) begin
              pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
              if (!powFlag) begin
                powFlag <= 1'b1;
                powerCollected <= powerCollected + 1;
              end
            end else powFlag <= 1'b0;
          end

          FRUIT: begin

            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;

            if (cherryMap[offsetY][offsetX] != TRANSPARENT_ENCODING) begin
              RGBout  <= cherryMap[offsetY][offsetX];
              fruitDR <= 1'b1;
            end

            if (fruitCollision) begin
              pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
              if (!fruitFlag) begin
                fruitFlag <= 1'b1;
                fruitsCollected <= fruitsCollected + 1;
              end
            end else fruitFlag <= 1'b0;
          end

          default: begin
            mapDR   <= 1'b0;
            coinsDR <= 1'b0;
            powerDR <= 1'b0;
            RGBout  <= TRANSPARENT_ENCODING;
          end
        endcase

      end
    end
  end


  // ---------------------------------------------------------------------------
  //  outputs
  // ---------------------------------------------------------------------------

  assign aroundBlinky = aroundGhost(BlinkytopLeftX, BlinkytopLeftY);
  assign aroundPinky = aroundGhost(PinkytopLeftX, PinkytopLeftY);
  assign aroundInky = aroundGhost(InkytopLeftX, InkytopLeftY);
  assign aroundClyde = aroundGhost(ClydetopLeftX, ClydetopLeftY);
  assign aroundPac = aroundGhost(pactopLeftX, pactopLeftY);

endmodule
