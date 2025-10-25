module map1_drawer (
    input logic clk,
    input logic resetN,
    input logic pauseN,
    input logic signed [10:0] pixelX,  //  current VGA pixel 
    input logic signed [10:0] pixelY,
    input logic [7:0] rnd,
    input logic startOfFrame,
    input logic oneSec,
    input logic [2:0] gameState,

    input logic coinCollision,
    input logic powerCollision,

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
    input logic [1:0] pacDir,
    input logic pacmanDR,
	  input logic starKey,
	  input logic slashKey,
    input logic numLockKey,
	 input logic [3:0] level,

    //outputs//
    output logic isWin,
    output logic mapDR,
    output logic coinsDR,  // ouput Whether a coin is drawn or not
    output logic powerDR,
    output logic pickUpDR,
    output logic [7:0] RGBout,

    //Ghosts - outputs - change if TILE_SIZE changes
    output logic [15:0] aroundBlinky,
    output logic [15:0] aroundPinky,
    output logic [15:0] aroundInky,
    output logic [15:0] aroundClyde,
    output logic [15:0] aroundPac,

    output logic signed [10:0] partialScore,  // controller will add aten ghosts score
    output logic [1:0] pacSpeedChange,  // 0=normal, 1=fast, 2=slow
    output logic [1:0] pacLifeChange,  // 0=no, 1=incr, 2=decr up for 1 clk

    // for melody selection
    output logic coinFlag,
    output logic powFlag,
    output logic picUpFlag,
    output logic fruitSpawnFlag,
    output logic [2:0] picUpTypeFlag, // 0=no, 1=banana, 2=cherry 3=str 4=strawberry 5=posion - for jukebox
    output logic breakFlag,
    output logic placeBreakFlag 

);
  // map
  localparam MAP_WIDTH_X = 31;
  localparam MAP_HEIGHT_Y = 28;
  // colors
  localparam WALL_COLOR = 8'b00000011;
  localparam GHOST_WALL_COLOR = 8'b10001111;
  localparam PORTAL_COLOR = 8'b01111111;
  localparam COIN_COLOR = 8'b11111111;
  localparam POW_COLOR1 = 8'HFE;
  localparam POW_COLOR2 = 8'hF9;
  localparam POW_RADIUS1 = 5;
  localparam POW_RADIUS2 = 4;

  localparam [7:0] BREAK_BKG_COLOR = WALL_COLOR;  // changed from 8'hff;
  localparam [7:0] BREAK1_COLOR = 8'hf0;
  localparam [7:0] BREAK2_COLOR = 8'hEA;
  localparam [7:0] BREAK3_COLOR = 8'ha4;
  localparam NUM_KEY = 77;

  localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;
  // tiles
  localparam TILE_SIZE_BITS = 4;  // IMPORTANT TO KEEP 2^n
  localparam TILE_SIZE = 1 << TILE_SIZE_BITS;  // IMPORTANT TO KEEP 2^n
  localparam TILE_BITS = 4; // 16 types of tiles, 4 bits each - if changed, change the map encoding too
  localparam TILE_SAVED = 16;  // IMPORTANT TO KEEP 2^n 
  // speed & life
  localparam NORMAL = 0;
  localparam INCREASE = 1;
  localparam DECREASE = 2;
  // map encoding
  localparam logic [TILE_BITS-1:0] EMPTY = 0;
  localparam logic [TILE_BITS-1:0] COIN = 1;
  localparam logic [TILE_BITS-1:0] WALL = 2;
  localparam logic [TILE_BITS-1:0] GHOST_WALL = 3;
  localparam logic [TILE_BITS-1:0] PORTAL = 4;
  localparam logic [TILE_BITS-1:0] POWER = 5;
  localparam logic [TILE_BITS-1:0] CHERRY = 6;
  localparam logic [TILE_BITS-1:0] BANANA = 7;
  localparam logic [TILE_BITS-1:0] STRAWBERRY = 8;
  localparam logic [TILE_BITS-1:0] POISION = 9;
  localparam logic [TILE_BITS-1:0] BREAK1 = 13;
  localparam logic [TILE_BITS-1:0] BREAK2 = 14;
  localparam logic [TILE_BITS-1:0] BREAK3 = 15;
  // Pickups
  localparam PICKUPS_TO_PLACE = 9;
  localparam PICKUPS_TYPES = 4;  // cherry, banana, strawberry, poision

  // game states
  localparam RESET_ST = 3'b000;
  localparam START_WAIT_ST = 3'b001;
  localparam PLAYING_ST = 3'b010;
  localparam PAUSED_ST = 3'b011;
  localparam GHOST_HIT_ST = 3'b100;
  localparam WIN_ST = 3'b101;
  localparam LOSE_ST = 3'b110;
  localparam POWER_UP_ST = 3'b111;

  localparam MAP_WIDTH_BITS = $clog2(MAP_WIDTH_X);
  localparam MAP_HEIGHT_BITS = $clog2(MAP_HEIGHT_Y);

  logic pickUpCollision;  // 1= collision



  logic [3:0] offsetX;
  logic [3:0] offsetY;
  logic [2:0] pickUpTimer;  // 8 sec max
  logic [8:0] coinsCollected;
  logic [8:0] powerCollected;
  logic [8:0] coinsPowTot;  // pow and coins!
  

  logic [$clog2(PICKUPS_TO_PLACE)-1:0] currPicUp;
  logic [0:MAP_WIDTH_X-1][0:MAP_HEIGHT_Y-1][TILE_BITS-1:0] pacmanMap;
  logic [TILE_BITS-1:0] tile;
  logic [PICKUPS_TO_PLACE-1:0][5:0] pickUpCollected;  //  how many of each pickup collected
    
  // map loading
  logic newMapAvailable;
  logic finishedLoading;
  logic [$clog2(MAP_WIDTH_X)-1:0] raddrX;
  logic [$clog2(MAP_HEIGHT_Y)-1:0] raddrY;
  logic [2:0] newMapData;


  // map updater data
  logic [3:0] currentTileValue;
  logic [3:0] nextTileValue;
  logic updateValueForTile;
  logic [4:0] currentTileX;
  logic [4:0] currentTileY;
  logic isScanInsideMap;

  always_comb begin
    currentTileX = pixelX >> TILE_SIZE_BITS;
    currentTileY = (pixelY >> TILE_SIZE_BITS) - 1;  // in y axis there is a gap row
    isScanInsideMap = (currentTileX < MAP_WIDTH_X) && (currentTileY < MAP_HEIGHT_Y);
    currentTileValue = currentTileY < MAP_HEIGHT_Y ? pacmanMap[currentTileX][currentTileY] : 4'b0;
  end
  
  map_updater updater_inst (
    .clk(clk),
    .resetN(resetN),
    .rnd(rnd),
    .level(level),
    .currentTileX(currentTileX),
    .currentTileY(currentTileY),
    .pactopLeftX(pactopLeftX),
    .pactopLeftY(pactopLeftY),
    .startOfFrame(startOfFrame),
    .currentTileValue(currentTileValue),
    .isScanInsideMap(isScanInsideMap),
    .coinCollision(coinCollision),
    .powerCollision(powerCollision),
    .coinsCollected(coinsCollected),
    .powerCollected(powerCollected),
    .coinsPowTot(coinsPowTot),
    .pickUpCollision(pickUpCollision),
    .newTileValue(nextTileValue),
    .updateValueForTile(updateValueForTile),
    .placeBreakFlag(placeBreakFlag),
    .currPicUp(currPicUp),
    .coinFlag(coinFlag),
    .powFlag(powFlag),
    .fruitSpawnFlag(fruitSpawnFlag)
  );

  map_manager manager_inst (
		 .clk(clk),
		 .resetN(resetN),
		 .gameState(gameState),
		 .rnd(rnd),
		 .startOfFrame(startOfFrame),
		 .raddrX(raddrX),
     .raddrY(raddrY),
     .rdata(newMapData),
		 .coinsPowTot(coinsPowTot),
		 .doneLoading(newMapAvailable)
	);



   logic [0:15] [0:15] [7:0] portal = {
  {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
  {8'h00,8'h00,8'h00,8'h00,8'h3B,8'h33,8'h33,8'h33,8'h33,8'h33,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
  {8'h00,8'hfd,8'hfd,8'h3B,8'h33,8'h33,8'h33,8'h33,8'h33,8'h33,8'h33,8'h00,8'h00,8'h00,8'h00,8'h00},
  {8'h00,8'h00,8'h3B,8'h3B,8'h00,8'h00,8'h00,8'h00,8'h00,8'h33,8'h33,8'h33,8'h00,8'h00,8'h00,8'h00},
  {8'h00,8'h3B,8'h3B,8'h00,8'h33,8'h33,8'h33,8'h33,8'h00,8'h00,8'h33,8'h33,8'h33,8'h00,8'h00,8'h00},
  {8'hd2,8'h3B,8'h00,8'h3B,8'h33,8'h33,8'h33,8'h33,8'h33,8'h00,8'h00,8'h33,8'h33,8'h00,8'hfd,8'h00},
  {8'h3B,8'h00,8'h3B,8'h3B,8'h33,8'h00,8'h00,8'h00,8'h33,8'h33,8'h00,8'h33,8'h33,8'h00,8'h00,8'h00},
  {8'h3B,8'h00,8'h3B,8'h3B,8'h00,8'h33,8'h00,8'h00,8'h33,8'h33,8'h00,8'h33,8'h33,8'h00,8'h00,8'h00},
  {8'h00,8'h00,8'h3B,8'h3B,8'h00,8'h33,8'h00,8'h00,8'h33,8'h00,8'h00,8'h33,8'h33,8'h00,8'h00,8'h00},
  {8'h00,8'h00,8'h3B,8'h3B,8'h00,8'h33,8'h00,8'h00,8'h00,8'h00,8'h33,8'h33,8'h00,8'h33,8'h00,8'h00},
  {8'h00,8'h00,8'h3B,8'h3B,8'h00,8'h00,8'h33,8'h33,8'h33,8'h33,8'h33,8'h00,8'h00,8'h33,8'h00,8'h00},
  {8'h00,8'h00,8'h3B,8'h3B,8'h3B,8'h00,8'h00,8'h33,8'h33,8'h33,8'h00,8'h00,8'h33,8'h33,8'h00,8'h00},
  {8'h00,8'h00,8'h00,8'h3B,8'h3B,8'h3B,8'h00,8'h00,8'h00,8'h00,8'h33,8'h33,8'h33,8'h00,8'h00,8'h00},
  {8'h00,8'hfd,8'h00,8'h00,8'h3B,8'h3B,8'h3B,8'h3B,8'h3B,8'h3B,8'h3B,8'hfd,8'hfd,8'h00,8'h00,8'h00},
  {8'h00,8'hfd,8'h00,8'h00,8'h00,8'h3B,8'h3B,8'h3B,8'h3B,8'h3B,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
  {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00}};

  logic [0:15] [0:15] break_shape = {
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1},
  {1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b1},
  {1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0},
  {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1},
  {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}};

  logic [0:4][0:15][0:15][7:0] pickUpsMaps = {  // 5 fruits, 16x16 pixels, 8-bit color
      // cherry
      {
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
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3}
      },

      // banana        
      {
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'h24,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'h24,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'hd8,8'hb8,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'hd8,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'hfc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'hb4,8'hfc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'hb8,8'hfc,8'hfc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'hb4,8'hb8,8'hfc,8'hfc,8'hd8,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'hb8,8'hb8,8'hb8,8'hb4,8'hfc,8'hfc,8'hfc,8'hfc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'hf8,8'hfc,8'hfc,8'hfc,8'hd8,8'hfc,8'hfc,8'hd8,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'h24,8'hfc,8'hfc,8'hfc,8'hfc,8'hfc,8'hd8,8'hfc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'hd8,8'hd8,8'hd8,8'hd8,8'hfc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'hdc,8'hfc,8'hfc,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3}
      },

      //strawberry
      {
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'h04,8'h04,8'h04,8'hff,8'h78,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'h78,8'hbc,8'h9c,8'hbd,8'hbd,8'hbd,8'hbd,8'h64,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he0,8'he0,8'h78,8'h78,8'hbd,8'hbc,8'h78,8'he0,8'he4,8'he0,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'h78,8'he0,8'he0,8'he0,8'hff,8'he0,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he0,8'hff,8'he0,8'he0,8'he0,8'he0,8'he0,8'hff,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he0,8'he0,8'he0,8'hff,8'he0,8'hfa,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'hff,8'he0,8'he0,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he0,8'hff,8'he0,8'he0,8'hfa,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'hff,8'he0,8'he0,8'hfa,8'he0,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he0,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
        {8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3}
      },

      // poision
      {
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00},
        {8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00},
        {8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00},
        {8'h00,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'h00},
        {8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00},
        {8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00},
        {8'h00,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'h00},
        {8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00},
        {8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'hda,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'hda,8'h00,8'hda,8'hda,8'h00,8'hda,8'h00,8'h00,8'h00,8'h00,8'h00}
      }
  };

  //------------------------------------------------------
  // Random appearance & pulsing animation
  //------------------------------------------------------

  logic [3:0] secCnt;
  logic [7:0] frameRnd;
  logic [7:0] pulseCnt;
  logic       shine;
  logic       togglePow;
  
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      secCnt    <= 0;
      pulseCnt  <= 0;
      shine     <= 0;
      togglePow <= 0;
      frameRnd  <= rnd ^ (pixelX / TILE_SIZE) ^ (pixelY / TILE_SIZE);
    end else if (pauseN && gameState != WIN_ST && gameState != LOSE_ST) begin

      // 1 Hz counter (if oneSec = 1 once per second)
      if (oneSec) begin
        secCnt <= secCnt + 1;

        // random toggle: object disappears/appears
        if (secCnt >= frameRnd) begin
          togglePow <= ~togglePow;
          secCnt    <= 0;
          // re-randomize interval (between 2–8 sec)
          frameRnd  <= (rnd[2:0] + 3) + (pixelX % 8);
        end
      end

      // slow pulsing (every few frames)
      if (startOfFrame) begin
        pulseCnt <= pulseCnt + 1;
        if (pulseCnt == 5) begin
          shine <= ~shine;
          pulseCnt <= 0;
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
      pickUpDR <= 1'b0;
      finishedLoading <= 1'b0;

      
      pickUpCollected <= '{default: 0};  // all elements reset to 0

      picUpTypeFlag <= 0;
      breakFlag <= 0;
      isWin <= 0;

      pickUpTimer <= 0;
      pacSpeedChange <= NORMAL;
      pacLifeChange <= NORMAL;
      raddrX <= 0;
      raddrY <= 0;

    end else if(gameState == RESET_ST) begin
		RGBout <= 8'b0;
		mapDR <= 1'b0;
		pickUpDR <= 1'b0;
		
		if(newMapAvailable) begin
            raddrX <= 5'd0;
            raddrY <= 5'd0;
            finishedLoading <= 1'b0;
    end

      pickUpCollected <= '{default: 0};  // all elements reset to 0


      picUpTypeFlag <= 0;
      breakFlag <= 0;
      isWin <= 0;

      pickUpTimer <= 0;
      pacSpeedChange <= NORMAL;
      pacLifeChange <= NORMAL;

	 end else begin
      // defaults	
      RGBout <= TRANSPARENT_ENCODING;
      mapDR <= 1'b0;
      coinsDR <= 1'b0;
      powerDR <= 1'b0;
      pickUpDR <= 1'b0;
      pacLifeChange <= NORMAL;
      isWin <= (coinsCollected + powerCollected == coinsPowTot);
      tile = pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1];

      // We should try to update the map only here to avoid complicated logic
      if (updateValueForTile) begin
        pacmanMap[currentTileX][currentTileY] <= nextTileValue;
      end

      // ---------------------------------------------------------------------------
      // pick Ups - counters & palcement
      // ---------------------------------------------------------------------------

      // cherry&banana Counter
      if (pickUpTimer > 0 && oneSec) pickUpTimer <= pickUpTimer - 1;
      else if (pickUpTimer == 0) pacSpeedChange <= NORMAL;




      // colision pickUps
      if (pickUpCollision && !picUpFlag) begin
        picUpFlag <= 1'b1;
        picUpTypeFlag <= tile - CHERRY + 1;
        pickUpCollected[tile-CHERRY] <= pickUpCollected[tile-CHERRY] + 1;  // count pickups
        case (tile)
          CHERRY: begin
            pickUpTimer <= 6;  //  6 sec
            pacSpeedChange <= INCREASE;
          end
          BANANA: begin
            pickUpTimer <= 6;  // 6 sec
            pacSpeedChange <= DECREASE;
          end
          STRAWBERRY: pacLifeChange <= INCREASE;
          POISION: pacLifeChange <= DECREASE;
        endcase
      end else begin
        picUpFlag <= 1'b0;
        picUpTypeFlag <= 1'b0;
      end


      // ---------------------------------------------------------------------------
      // Breaking walls
      // ---------------------------------------------------------------------------

      
      if (breakFlag && oneSec) breakFlag <= 0;

      if ((numLockKey || starKey || slashKey) && startOfFrame) begin
        // Determine Pacman's current tile
        logic [$clog2(MAP_WIDTH_X)-1:0] pacX, targetX;
        logic [$clog2(MAP_HEIGHT_Y)-1:0] pacY, targetY;

        pacX = pactopLeftX / TILE_SIZE;
        pacY = (pactopLeftY / TILE_SIZE) - 1;  // Account for offset
        targetX = pacX;
        targetY = pacY;

        // Find the tile in Pacman's direction
        case (pacDir)
          2'd0: targetY = pacY - 1;  // UP
          2'd1: targetY = pacY + 1;  // DOWN
          2'd2: targetX = pacX - 1;  // LEFT
          2'd3: targetX = pacX + 1;  // RIGHT
          default: ;
        endcase


        if (targetX < MAP_WIDTH_X && targetY < MAP_HEIGHT_Y) begin  // bounds checking
          logic [TILE_BITS-1:0] wallTile;
          wallTile = pacmanMap[targetX][targetY];

          // non-blocking assignments
          if (!breakFlag) begin
            if (wallTile == BREAK3 && starKey) begin
              breakFlag <= 1'b1;
              pacmanMap[targetX][targetY] <= BREAK2;
            end else if (wallTile == BREAK2 && slashKey) begin
              breakFlag <= 1'b1;
              pacmanMap[targetX][targetY] <= BREAK1;
            end else if (wallTile == BREAK1 && numLockKey) begin
              breakFlag <= 1'b1;
              pacmanMap[targetX][targetY] <= COIN;
            end
          end
        end
      end


      // ---------------------------------------------------------------------------
      // MAP CONTROL - VISUALIZATION
      // ---------------------------------------------------------------------------

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
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            RGBout <= portal[offsetY][offsetX];
            mapDR  <= 1'b1;
          end

          COIN: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            if (offsetX >= 6 && offsetX < 10 && offsetY >= 6 && offsetY < 10) begin
              RGBout  <= COIN_COLOR;
              coinsDR <= 1'b1;
            end
          end

          POWER: begin
            int dx, dy;
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            dx = offsetX - 8;
            dy = offsetY - 8;

            // POWER animation - size&color
            if (shine) begin
              if ((dx * dx + dy * dy) <= (POW_RADIUS1 * POW_RADIUS1) && togglePow) begin
                RGBout  <= POW_COLOR1;
                powerDR <= 1'b1;
              end
            end else begin
              if ((dx * dx + dy * dy) <= (POW_RADIUS2 * POW_RADIUS2) && togglePow) begin
                RGBout  <= POW_COLOR2;
                powerDR <= 1'b1;
              end
            end

          end

          CHERRY, BANANA, STRAWBERRY, POISION: begin
            logic [$clog2(PICKUPS_TYPES)-1:0] fruitIdx;
            fruitIdx = tile - CHERRY;
            offsetX  = pixelX % TILE_SIZE;
            offsetY  = pixelY % TILE_SIZE;

            if (pickUpsMaps[fruitIdx][offsetY][offsetX] != TRANSPARENT_ENCODING) begin
              RGBout   <= pickUpsMaps[fruitIdx][offsetY][offsetX];
              pickUpDR <= 1'b1;
            end
          end

          BREAK1: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            RGBout <= break_shape[offsetY][offsetX] == 1 ? BREAK1_COLOR : BREAK_BKG_COLOR;
            mapDR  <= 1'b1;
          end

          BREAK2: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            RGBout <= break_shape[offsetY][offsetX] == 1 ? BREAK2_COLOR : BREAK_BKG_COLOR;
            mapDR  <= 1'b1;
          end

          BREAK3: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            RGBout <= break_shape[offsetY][offsetX] == 1 ? BREAK3_COLOR : BREAK_BKG_COLOR;
            mapDR  <= 1'b1;
          end

          default: begin
            mapDR   <= 1'b0;
            coinsDR <= 1'b0;
            powerDR <= 1'b0;
            RGBout  <= TRANSPARENT_ENCODING;
          end
        endcase

      end
      // map loading control
      if(newMapAvailable) begin
            raddrX <= 5'd0;
            raddrY <= 5'd0;
            finishedLoading <= 1'b0;
      end
      if (!finishedLoading) begin
            pacmanMap[raddrX][raddrY] <= newMapData;
            if (raddrX == MAP_WIDTH_X - 1) begin
                raddrX <= 5'd0;
                if (raddrY == MAP_HEIGHT_Y - 1) begin
                    raddrY <= 5'd0;
                    finishedLoading <= 1'b1;
                end else begin
                    raddrY <= raddrY + 1'b1;
                end
            end else begin
                raddrX <= raddrX + 1'b1;
            end
      end

    end
  end


  // ---------------------------------------------------------------------------
  //  outputs
  // ---------------------------------------------------------------------------
  // around_character module

  around_character around_blinky_inst (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .charTileX(BlinkytopLeftX >> TILE_SIZE_BITS),
    .charTileY((BlinkytopLeftY >> TILE_SIZE_BITS) - 5'd1),
    .currTileX(currentTileX),
    .currTileY(currentTileY),
    .currTileData(currentTileValue),
    .isScanInsideMap(isScanInsideMap),
    .tiles_around(aroundBlinky)
  );

  around_character around_pinky_inst (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .charTileX(PinkytopLeftX >> TILE_SIZE_BITS),
    .charTileY((PinkytopLeftY >> TILE_SIZE_BITS) - 5'd1),
    .currTileX(currentTileX),
    .currTileY(currentTileY),
    .currTileData(currentTileValue),
    .isScanInsideMap(isScanInsideMap),
    .tiles_around(aroundPinky)
  );

  around_character around_inky_inst (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .charTileX(InkytopLeftX >> TILE_SIZE_BITS),
    .charTileY((InkytopLeftY >> TILE_SIZE_BITS) - 5'd1),
    .currTileX(currentTileX),
    .currTileY(currentTileY),
    .currTileData(currentTileValue),
    .isScanInsideMap(isScanInsideMap),
    .tiles_around(aroundInky)
  );
  
  around_character around_clyde_inst (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .charTileX(ClydetopLeftX >> TILE_SIZE_BITS),
    .charTileY((ClydetopLeftY >> TILE_SIZE_BITS) - 5'd1),
    .currTileX(currentTileX),
    .currTileY(currentTileY),
    .currTileData(currentTileValue),
    .isScanInsideMap(isScanInsideMap),
    .tiles_around(aroundClyde)
  );

  around_character around_pacman_inst (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .charTileX(pactopLeftX >> TILE_SIZE_BITS),
    .charTileY((pactopLeftY >> TILE_SIZE_BITS) - 5'd1),
    .currTileX(currentTileX),
    .currTileY(currentTileY),
    .currTileData(currentTileValue),
    .isScanInsideMap(isScanInsideMap),
    .tiles_around(aroundPac)
  );



 


  assign pickUpCollision = (pickUpDR && pacmanDR) ? 1 : 0;
  assign partialScore = coinsCollected + powerCollected * 10 + pickUpCollected[0] * 4  // cherry
      + pickUpCollected[1] * 10  // banana
      + pickUpCollected[2] * 2  // strawberry
      - pickUpCollected[3] * 20;  // poision

endmodule

