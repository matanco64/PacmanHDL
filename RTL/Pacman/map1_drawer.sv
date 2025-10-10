module map1_drawer (
    input logic clk,
    input logic resetN,
	 input logic pauseN,
    input logic signed [10:0] pixelX,  //  current VGA pixel 
    input logic signed [10:0] pixelY,
    input logic [7:0] rnd,
	 input logic startOfFrame,
    input logic oneSec,
	 input logic [ 2:0] gameState,

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
    input logic pacmanDR,


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
	 output logic [2:0] picUpTypeFlag // 0=no, 1=banana, 2=cherry 3=str 4=strawberry 5=posion 6=fee - for jukebox

);
  // map
  localparam MAP_HEIGHT_Y = 31;
  localparam MAP_WIDTH_X = 28;
  // colors
  localparam WALL_COLOR = 8'b00000011;
  localparam GHOST_WALL_COLOR = 8'b10001111;
  localparam PORTAL_COLOR = 8'b01111111;
  localparam COIN_COLOR = 8'b11111111;
  localparam POW_COLOR1 = 8'HFE;
  localparam POW_COLOR2 = 8'hF9;
  localparam POW_RADIUS1 = 5;
  localparam POW_RADIUS2 = 4;
  
  localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;
  // tiles
  localparam TILE_SIZE = 16;  // IMPORTANT TO KEEP 2^n
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
  localparam logic [TILE_BITS-1:0] FEE = 10;
  // Pickups
  localparam PICKUPS_TO_PLACE = 9;
  localparam PICKUPS_TYPES = 5;
  localparam int FRUIT_THRESH[0:PICKUPS_TO_PLACE-1] = '{
      15,
      21,
      32,
      47,
      58,
      65,
      83,
      90,
      110  // never reached
  };  // increasing order
  
   // game states
  localparam RESET_ST = 3'b000;
  localparam START_WAIT_ST = 3'b001;
  localparam PLAYING_ST = 3'b010;
  localparam PAUSED_ST = 3'b011;
  localparam GHOST_HIT_ST = 3'b100;
  localparam WIN_ST = 3'b101;
  localparam LOSE_ST = 3'b110;
  localparam POWER_UP_ST = 3'b111;

  logic pickUpCollision;  // 1= collision
  logic fruitSpawnPending;

  logic [3:0] offsetX;
  logic [3:0] offsetY;
  logic [2:0] pickUpTimer;  // 8 sec max
  logic [8:0] coinsCollected;
  logic [8:0] powerCollected;
  logic [8:0] coinsPowTot;  // pow and coins!

  logic [$clog2(MAP_WIDTH_X)-1:0] emptyTilesX[0:TILE_SAVED-1];
  logic [$clog2(MAP_HEIGHT_Y)-1:0] emptyTilesY[0:TILE_SAVED-1];
  logic [$clog2(PICKUPS_TO_PLACE)-1:0] currPicUp;
  logic [0:MAP_HEIGHT_Y-1][0:MAP_WIDTH_X-1][TILE_BITS-1:0] pacmanMap;
  logic [TILE_BITS-1:0] tile;
  logic [PICKUPS_TO_PLACE-1:0][5:0] pickUpCollected;  //  how many of each pickup collected


    logic [0:MAP_HEIGHT_Y-1][0:MAP_WIDTH_X-1][TILE_BITS-1:0] OriginalPacmanMap = { // Since we are mutating the Original Map when coins are eaten, we want an ability to reset it
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2, 4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd3, 4'd0, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd4, 4'd0, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd3, 4'd0, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd0, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd0, 4'd4 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd3, 4'd0, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 }
  };
  
  logic [0:15] [0:15] [7:0] portal = {
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h9F,8'hDF,8'hDF,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'hfd,8'hfd,8'h9F,8'hDF,8'hDF,8'hDF,8'hDF,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h9F,8'h9F,8'h00,8'h00,8'h00,8'h00,8'h00,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h9F,8'h9F,8'h00,8'hDF,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'h00},
	{8'hd2,8'h9F,8'h00,8'h9F,8'hDF,8'hDF,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'hDF,8'hDF,8'h00,8'hfd,8'h00},
	{8'h9F,8'h00,8'h9F,8'h9F,8'hDF,8'h00,8'h00,8'h00,8'hDF,8'hDF,8'h00,8'hDF,8'hDF,8'h00,8'h00,8'h00},
	{8'h9F,8'h00,8'h9F,8'h9F,8'h00,8'hDF,8'h00,8'h00,8'hDF,8'hDF,8'h00,8'hDF,8'hDF,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h9F,8'h9F,8'h00,8'hDF,8'h00,8'h00,8'hDF,8'h00,8'h00,8'hDF,8'hDF,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h9F,8'h9F,8'h00,8'hDF,8'h00,8'h00,8'h00,8'h00,8'hDF,8'hDF,8'h00,8'hDF,8'h00,8'h00},
	{8'h00,8'h00,8'h9F,8'h9F,8'h00,8'h00,8'hDF,8'hDF,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'hDF,8'h00,8'h00},
	{8'h00,8'h00,8'h9F,8'h9F,8'h9F,8'h00,8'h00,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'hDF,8'hDF,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h9F,8'h9F,8'h9F,8'h00,8'h00,8'h00,8'h00,8'hDF,8'hDF,8'hDF,8'h00,8'h00,8'h00},
	{8'h00,8'hfd,8'h00,8'h00,8'h9F,8'h9F,8'h9F,8'h9F,8'h9F,8'h9F,8'h9F,8'hfd,8'hfd,8'h00,8'h00,8'h00},
	{8'h00,8'hfd,8'h00,8'h00,8'h00,8'h9F,8'h9F,8'h9F,8'h9F,8'h9F,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00}};

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
      },

      // fee
      {
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
        {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'he0,8'he0,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00}
      }
  };


  // ---------------------------------------------------------------------------
  // functions
  // ---------------------------------------------------------------------------

  // count coins in start map
  function automatic int countCoins();
    int total;
    begin
      total = 0;
      for (int y = 0; y < MAP_HEIGHT_Y; y++) begin
        for (int x = 0; x < MAP_WIDTH_X; x++) begin
          if (OriginalPacmanMap[y][x] == COIN || OriginalPacmanMap[y][x] == POWER) total++;
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
  
  ////power appearance control//////////////////////////////////////////////////////////////////////////////////////////////
	logic [3:0] secCnt;
	logic [7:0] frameRnd;
	logic [7:0] pulseCnt;
	logic       shine;
	logic       togglePow;

//	always_ff @(posedge clk or negedge resetN) begin
//		 if (!resetN) begin
//			  secCnt  <= 4'd0;
//			  shine <= 1'b0;
//			  togglePow <= 1'b0;
//			  frameRnd <= rnd ^ (pixelX % TILE_SIZE) ^ (pixelY % TILE_SIZE); // rnd base on power's tile
//		 end
//		 else if (pauseN && gameState != WIN_ST && gameState != LOSE_ST) begin 
//			  if(oneSec) secCnt <= secCnt + 1;
//			  if(startOfFrame) shine <= ~shine;
//			  
//			  if(secCnt == frameRnd)begin
//					frameRnd  <= rnd ^ (pixelX % TILE_SIZE) ^ (pixelY % TILE_SIZE);
//					togglePow <= ~togglePow;  
//			  end
//		 end
//	end


//------------------------------------------------------
// Random appearance & pulsing animation
//------------------------------------------------------
	always_ff @(posedge clk or negedge resetN) begin
		 if (!resetN) begin
			  secCnt     <= 0;
			  pulseCnt   <= 0;
			  shine      <= 0;
			  togglePow  <= 0;
			  frameRnd   <= rnd ^ (pixelX / TILE_SIZE) ^ (pixelY / TILE_SIZE);
		 end 
		 else if (pauseN && gameState != WIN_ST && gameState != LOSE_ST) begin
			  
			  // 1 Hz counter (if oneSec = 1 once per second)
			  if (oneSec) begin
					secCnt <= secCnt + 1;

					// random toggle: object disappears/appears
					if (secCnt >= frameRnd) begin
						 togglePow <= ~togglePow;
						 secCnt    <= 0;
						 // re-randomize interval (between 2–8 sec)
						 frameRnd  <= (rnd[2:0] + 3) + (pixelX % 5);
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
      pacmanMap <= OriginalPacmanMap;
      coinsPowTot <= countCoins();

      coinsCollected <= 0;
      powerCollected <= 0;
      pickUpCollected <= '{default: 0};  // all elements reset to 0
		fruitSpawnPending <= 1'b0;

      coinFlag <= 0;
      powFlag <= 0;
      picUpFlag <= 0;
		picUpTypeFlag <=0;
		fruitSpawnFlag <=0;
      currPicUp <= 0;
      isWin <= 0;

      pickUpTimer <= 0;
      pacSpeedChange <= NORMAL;
		pacLifeChange <= NORMAL;
    end else begin
      RGBout <= TRANSPARENT_ENCODING;
      mapDR <= 1'b0;
      coinsDR <= 1'b0;
      powerDR <= 1'b0;
      pickUpDR <= 1'b0;
		fruitSpawnFlag <= 1'b0;
		pacLifeChange <= NORMAL;
		
      isWin <= (coinsCollected + powerCollected == coinsPowTot);
      tile = pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1];


      // cherry&banana Counter
      if (pickUpTimer > 0 && oneSec) pickUpTimer <= pickUpTimer - 1;
      else if (pickUpTimer == 0) pacSpeedChange <= NORMAL;
		
		// flag up
		if (!fruitSpawnPending && currPicUp < PICKUPS_TO_PLACE && 
			 (coinsCollected * 100 / coinsPowTot) > FRUIT_THRESH[currPicUp]) begin
			  fruitSpawnPending <= 1'b1;
		end
		// place the fruit
		if (fruitSpawnPending) begin
		  logic [$clog2(TILE_SAVED)-1:0] idx;
		  idx = rnd[$clog2(TILE_SAVED)-1:0];
		  
		  // place if empty or try again next clock
		  if (pacmanMap[emptyTilesX[idx]][emptyTilesY[idx]] == EMPTY) begin
			 pacmanMap[emptyTilesX[idx]][emptyTilesY[idx]] <= CHERRY + (rnd % PICKUPS_TYPES);
			 currPicUp <= currPicUp + 1'b1;  // Increment fruit counter
			 fruitSpawnPending <= 1'b0;  // Clear flag - ready for next fruit
			 fruitSpawnFlag <= 1'b1;
		  end
		  
		end

      // colision coins
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

      // colision power
      if (powerCollision) begin
        pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
        if (!powFlag) begin
          powFlag <= 1'b1;
          powerCollected <= powerCollected + 1;
        end
      end else powFlag <= 1'b0;

      // colision pickUps
      if (pickUpCollision && !picUpFlag) begin
        pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
        picUpFlag <= 1'b1;
		  picUpTypeFlag <= tile - CHERRY +1 ;
        pickUpCollected[tile - CHERRY] <= pickUpCollected[tile - CHERRY] + 1;  // count pickups

		  case (tile)
			  CHERRY: begin
				 pickUpTimer <= 6;  //  6 sec
				 pacSpeedChange <= INCREASE;
			  end 
			  BANANA: begin
				 pickUpTimer <= 6;  // 6 sec
				 pacSpeedChange <= DECREASE;
			  end
			  STRAWBERRY: begin
				 pacLifeChange <= INCREASE;
			  end
			  POISION: begin
				 pacLifeChange <= DECREASE;
			  end
			  
			  default: begin
			  end
		  endcase
      end else begin 
			picUpFlag <= 1'b0;
			picUpTypeFlag <= 1'b0;
		end	


      // MAP CONTROL/////////////////////////////////////////////////////
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
				offsetX  = pixelX % TILE_SIZE;
            offsetY  = pixelY % TILE_SIZE;
            RGBout <= portal[offsetY][offsetX];;
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
				if(shine) begin
					if ((dx*dx + dy*dy) <= (POW_RADIUS1*POW_RADIUS1) && togglePow) begin
					 RGBout  <= POW_COLOR1;
					 powerDR <= 1'b1;
					end
				end else begin
					if ((dx*dx + dy*dy) <= (POW_RADIUS2*POW_RADIUS2) && togglePow) begin
					 RGBout  <= POW_COLOR2;
					 powerDR <= 1'b1;
					end
				end 
			
          end

          CHERRY, BANANA, STRAWBERRY, POISION, FEE: begin
            logic [$clog2(PICKUPS_TYPES)-1:0] fruitIdx;
            fruitIdx = tile - CHERRY;
            offsetX  = pixelX % TILE_SIZE;
            offsetY  = pixelY % TILE_SIZE;

            if (pickUpsMaps[fruitIdx][offsetY][offsetX] != TRANSPARENT_ENCODING) begin
              RGBout   <= pickUpsMaps[fruitIdx][offsetY][offsetX];
              pickUpDR <= 1'b1;
            end
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

  assign pickUpCollision = (pickUpDR && pacmanDR) ? 1 : 0;
  assign partialScore = coinsCollected + powerCollected * 10 + pickUpCollected[0] * 4  // cherry
      + pickUpCollected[1] * 10  // banana
      + pickUpCollected[2] * 2  // strawberry
      - pickUpCollected[3] * 20  // poision
      - pickUpCollected[4] * 50;  //  fee

endmodule
