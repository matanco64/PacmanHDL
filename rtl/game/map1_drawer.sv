module map1_drawer (
    input logic clk,
    input logic resetN,
    input logic pauseN,
    input logic signed [10:0] pixelX,  //  current VGA pixel 
    input logic signed [10:0] pixelY,
    input logic [10:0] pixelXAhead,     // scan position one clock ahead of pixelX/Y
    input logic [10:0] pixelYAhead,
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
    output logic [2:0] picUpTypeFlag, // 0=no, 1=banana, 2=cherry 3=str 4=strawberry 5=poison - for jukebox
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
  localparam logic [TILE_BITS-1:0] POISON = 9;
  localparam logic [TILE_BITS-1:0] EMPTY_BUT_WASNT = 10;
  localparam logic [TILE_BITS-1:0] BREAK1 = 13;
  localparam logic [TILE_BITS-1:0] BREAK2 = 14;
  localparam logic [TILE_BITS-1:0] BREAK3 = 15;
  // Pickups
  localparam PICKUPS_TO_PLACE = 9;
  localparam PICKUPS_TYPES = 4;  // cherry, banana, strawberry, poison

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
  logic [8:0] coinsTot;  // pow and coins!
  

  logic [$clog2(PICKUPS_TO_PLACE)-1:0] currPicUp;
  // ---------------------------------------------------------------------------
  // Tile map storage
  // On the DE-10 this was a 31x28 flip-flop array read combinationally, which
  // costs ~25k LUTs of read multiplexers. Here it is block RAM addressed by
  // {x, y} (rows 28..31 unused, read as EMPTY), with
  //   * a scan read port addressed one clock ahead, so data arrives in step
  //     with currentTileX/Y,
  //   * a write-first bypass, so a tile written on the previous clock reads
  //     back the new value exactly like the flip-flops did,
  //   * a second read port for the wall-break lookup in front of Pacman.
  // ---------------------------------------------------------------------------
  localparam int MAP_AW = 10;  // {x[4:0], y[4:0]}
  logic [TILE_BITS-1:0] pacmanMap [0:(1<<MAP_AW)-1];
  initial for (int i = 0; i < (1<<MAP_AW); i++) pacmanMap[i] = EMPTY;

  logic                 mapWe;
  logic [MAP_AW-1:0]    mapWaddr;
  logic [TILE_BITS-1:0] mapWdata;
  logic [MAP_AW-1:0]    scanRaddr, scanRaddrQ;
  logic [TILE_BITS-1:0] scanRdata, scanTileValue;
  logic                 bypassValid;
  logic [TILE_BITS-1:0] bypassData;

  // wall-break lookup (see the wall breaking section)
  logic                 breakCheck;   // RAM data for the latched target is valid
  logic [MAP_AW-1:0]    breakAddr;
  logic                 breakStar, breakSlash, breakNum;
  logic [TILE_BITS-1:0] breakTile;
  logic                 breakWe;
  logic [TILE_BITS-1:0] breakWdata;

  // tile under the un-delayed scan position (same math as currentTileX/Y)
  logic [4:0] aheadTileX, aheadTileY;
  assign aheadTileX = pixelXAhead / TILE_SIZE;
  assign aheadTileY = (pixelYAhead / TILE_SIZE) - 1;
  assign scanRaddr  = {aheadTileX, aheadTileY};

  always_ff @(posedge clk) begin
    if (mapWe) pacmanMap[mapWaddr] <= mapWdata;
    scanRdata   <= pacmanMap[scanRaddr];
    scanRaddrQ  <= scanRaddr;
    bypassValid <= mapWe && (mapWaddr == scanRaddr);
    bypassData  <= mapWdata;
  end
  assign scanTileValue = bypassValid ? bypassData : scanRdata;
  logic [PICKUPS_TO_PLACE-1:0][5:0] pickUpCollected;  //  how many of each pickup collected
    
  // map loading
  logic newMapAvailable;
  logic finishedLoading;
  logic [2:0] newMapData;


  // map updater data
  logic [3:0] currentTileValue;
  logic [3:0] nextTileValue;
  logic updateValueForTile;
  logic [4:0] currentTileX;
  logic [4:0] currentTileY;
  logic isScanInsideMap;

  always_comb begin
    currentTileX = pixelX / TILE_SIZE;
    currentTileY = (pixelY / TILE_SIZE) - 1;  // in y axis there is a gap row
    isScanInsideMap = (pixelX < MAP_WIDTH_X * TILE_SIZE) && (pixelY < (MAP_HEIGHT_Y  + 1) * TILE_SIZE);
    currentTileValue = isScanInsideMap ? scanTileValue : EMPTY;

    offsetX  = pixelX % TILE_SIZE;
    offsetY  = pixelY % TILE_SIZE;

  end
  
  map_updater updater_inst (
    .clk(clk),
    .resetN(resetN && (gameState != RESET_ST)),
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
    .coinsTot(coinsTot),
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
		 .raddrX(currentTileX),
		 .raddrY(currentTileY),
       .rdata(newMapData),
		 .coinsTot(coinsTot),
		 .newMapAvailable(newMapAvailable)
	);




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

  // cherry ROM
  logic [7:0] cherry_data_out;

  rom #(
    .WIDTH(8),
    .DEPTH(256),
    .INIT_FILE("assets/pickups/cherry.hex")
  ) rom_inst (
    .addr(offsetY * TILE_SIZE + offsetX),
    .clk(clk),
    .q(cherry_data_out)
  );

  //banana ROM
  logic [7:0] banana_data_out;

  rom #(
    .WIDTH(8),
    .DEPTH(256),
    .INIT_FILE("assets/pickups/banana.hex")
  ) rom_banana_inst (
    .addr(offsetY * TILE_SIZE + offsetX),
    .clk(clk),
    .q(banana_data_out)
  );

  // strawberry ROM
  logic [7:0] strawberry_data_out;

  rom #(
    .WIDTH(8),
    .DEPTH(256),
    .INIT_FILE("assets/pickups/strawberry.hex")
  ) rom_strawberry_inst (
    .addr(offsetY * TILE_SIZE + offsetX),
    .clk(clk),
    .q(strawberry_data_out)
  );

  // poison ROM
  logic [7:0] poison_data_out;
  rom #(
    .WIDTH(8),
    .DEPTH(256),
    .INIT_FILE("assets/pickups/skull.hex")
  ) rom_poison_inst (
    .addr(offsetY * TILE_SIZE + offsetX),
    .clk(clk),
    .q(poison_data_out)
  );

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
      finishedLoading <= 1'b1;

      
      pickUpCollected <= '{default: 0};  // all elements reset to 0

      picUpTypeFlag <= 0;
      breakFlag <= 0;
      isWin <= 0;

      pickUpTimer <= 0;
      pacSpeedChange <= NORMAL;
      pacLifeChange <= NORMAL;

    end else if(gameState == RESET_ST) begin
		RGBout <= 8'b0;
		mapDR <= 1'b0;
		pickUpDR <= 1'b0;

      pickUpCollected <= '{default: 0};  // all elements reset to 0
		// map loading control
      if(newMapAvailable) begin
            finishedLoading <= 1'b0;
      end


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
      isWin <= (coinsCollected == coinsTot);

      // We should try to update the map only here to avoid complicated logic
      // map writes themselves go through the RAM write port (see below)
      if (!finishedLoading && isScanInsideMap) begin
        if (currentTileX == MAP_WIDTH_X - 1 && currentTileY == MAP_HEIGHT_Y - 1) begin
          finishedLoading <= 1'b1;
        end
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
        picUpTypeFlag <= currentTileValue - CHERRY + 1;
        pickUpCollected[currentTileValue - CHERRY] <= pickUpCollected[currentTileValue - CHERRY] + 1;  // count pickups
        case (currentTileValue)
          CHERRY: begin
            pickUpTimer <= 6;  //  6 sec
            pacSpeedChange <= INCREASE;
          end
          BANANA: begin
            pickUpTimer <= 6;  // 6 sec
            pacSpeedChange <= DECREASE;
          end
          STRAWBERRY: pacLifeChange <= INCREASE;
          POISON: pacLifeChange <= DECREASE;
        endcase
      end else begin
        picUpFlag <= 1'b0;
        picUpTypeFlag <= 1'b0;
      end


      // ---------------------------------------------------------------------------
      // Breaking walls
      // ---------------------------------------------------------------------------

      
      if (breakFlag && oneSec) breakFlag <= 0;

      // the target tile was latched at startOfFrame and read from RAM; now the
      // same decision the flip-flop version made in the startOfFrame cycle
      if (breakCheck && !breakFlag) begin
        if (breakTile == BREAK3 && breakStar) begin
          breakFlag <= 1'b1;
        end else if (breakTile == BREAK2 && breakSlash) begin
          breakFlag <= 1'b1;
        end else if (breakTile == BREAK1 && breakNum) begin
          breakFlag <= 1'b1;
        end
      end


      // ---------------------------------------------------------------------------
      // MAP CONTROL - VISUALIZATION
      // ---------------------------------------------------------------------------

      if (pixelY / TILE_SIZE >= 1) begin
        case (currentTileValue)
          GHOST_WALL: begin
            RGBout <= GHOST_WALL_COLOR;
            mapDR  <= 1'b1;
          end

          WALL: begin
            RGBout <= WALL_COLOR;
            mapDR  <= 1'b1;
          end

          COIN: begin
            if (offsetX >= 6 && offsetX < 10 && offsetY >= 6 && offsetY < 10) begin
              RGBout  <= COIN_COLOR;
              coinsDR <= 1'b1;
            end
          end

          PORTAL: begin
            RGBout <= PORTAL_COLOR;
            mapDR  <= 1'b1;
          end

          POWER: begin
            int dx, dy;
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
          
          CHERRY: begin
            RGBout <= cherry_data_out;
            pickUpDR <= 1'b1;
          end
          BANANA: begin
            RGBout <= banana_data_out;
            pickUpDR <= 1'b1;
          end
          STRAWBERRY: begin
            RGBout <= strawberry_data_out;
            pickUpDR <= 1'b1;
          end
          POISON: begin
            RGBout <= poison_data_out;
            pickUpDR <= 1'b1;
          end

          BREAK1: begin
            RGBout <= break_shape[offsetY][offsetX] == 1 ? BREAK1_COLOR : BREAK_BKG_COLOR;
            mapDR  <= 1'b1;
          end

          BREAK2: begin
            RGBout <= break_shape[offsetY][offsetX] == 1 ? BREAK2_COLOR : BREAK_BKG_COLOR;
            mapDR  <= 1'b1;
          end

          BREAK3: begin
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
      
    end
  end


  // ---------------------------------------------------------------------------
  // Wall breaking: at startOfFrame (vertical blanking, no scan writes possible)
  // latch the tile in front of Pacman, read it on the second RAM port, then
  // decide and write back one clock later.
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      breakCheck <= 1'b0;
      breakAddr  <= '0;
      breakStar  <= 1'b0;
      breakSlash <= 1'b0;
      breakNum   <= 1'b0;
    end else begin
      breakCheck <= 1'b0;
      if (gameState != RESET_ST && (numLockKey || starKey || slashKey) && startOfFrame) begin
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

        breakCheck <= (targetX < MAP_WIDTH_X && targetY < MAP_HEIGHT_Y);  // bounds checking
        breakAddr  <= {targetX, targetY};
        breakStar  <= starKey;
        breakSlash <= slashKey;
        breakNum   <= numLockKey;
      end
    end
  end

  always_ff @(posedge clk) breakTile <= pacmanMap[breakAddr];

  always_comb begin
    breakWe    = 1'b0;
    breakWdata = breakTile;
    if (breakCheck && !breakFlag && gameState != RESET_ST) begin
      if (breakTile == BREAK3 && breakStar)       {breakWe, breakWdata} = {1'b1, BREAK2};
      else if (breakTile == BREAK2 && breakSlash) {breakWe, breakWdata} = {1'b1, BREAK1};
      else if (breakTile == BREAK1 && breakNum)   {breakWe, breakWdata} = {1'b1, COIN};
    end
  end

  // single RAM write port: map loading / updater at the scan tile, or a break
  always_comb begin
    mapWe    = 1'b0;
    mapWaddr = {currentTileX, currentTileY};
    mapWdata = nextTileValue;
    if (resetN && gameState != RESET_ST) begin
      if (!finishedLoading && isScanInsideMap) begin
        mapWe    = currentTileY < MAP_HEIGHT_Y;
        mapWdata = TILE_BITS'(newMapData);
      end else if (updateValueForTile) begin
        mapWe    = currentTileX < MAP_WIDTH_X && currentTileY < MAP_HEIGHT_Y;
      end
      if (breakWe) begin
        mapWe    = 1'b1;
        mapWaddr = breakAddr;
        mapWdata = breakWdata;
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
    .charTileX(BlinkytopLeftX / TILE_SIZE),
    .charTileY((BlinkytopLeftY / TILE_SIZE) - 5'd1),
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
    .charTileX(PinkytopLeftX / TILE_SIZE),
    .charTileY((PinkytopLeftY / TILE_SIZE) - 5'd1),
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
    .charTileX(InkytopLeftX / TILE_SIZE),
    .charTileY((InkytopLeftY / TILE_SIZE) - 5'd1),
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
    .charTileX(ClydetopLeftX / TILE_SIZE),
    .charTileY((ClydetopLeftY / TILE_SIZE) - 5'd1),
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
    .charTileX(pactopLeftX / TILE_SIZE),
    .charTileY((pactopLeftY / TILE_SIZE) -  5'd1),
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
      - pickUpCollected[3] * 20;  // poison

endmodule

