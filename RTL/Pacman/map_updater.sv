// this module updates the map based on the current pixel being scanned and other data
// the reason for this module is to ensure only one place updates the map to avoid conflicts and extra logic
module map_updater # (
    TILE_BITS = 4,
    MAP_WIDTH_X = 31,
    MAP_HEIGHT_Y = 28,
    PICKUPS_TO_PLACE = 9,
    PICKUPS_TYPES = 4
  ) (
    input  logic         clk,
    input  logic         resetN,
    input  logic [7:0]   rnd,
    input  logic [3:0]   level,
    input  logic [4:0]   currentTileX,
    input  logic [4:0]   currentTileY,
    input logic [10:0] pactopLeftX,
    input logic [10:0] pactopLeftY,
    input logic        startOfFrame,

    // coins and power-ups
    input logic coinCollision,
    input logic powerCollision, 
    output  logic [8:0] coinsCollected,
    output  logic [8:0] powerCollected,
    input  logic [8:0] coinsPowTot,

    // pickups
    input logic pickUpCollision,
    

    input logic [TILE_BITS -1:0]   currentTileValue,
    input logic                    isScanInsideMap,
    output logic [TILE_BITS -1:0]   newTileValue,
    output logic updateValueForTile,
    output logic [TILE_BITS -1:0]   placeBreakFlag,

    output logic [$clog2(PICKUPS_TO_PLACE)-1:0] currPicUp,

    // melody selection outputs
    output logic coinFlag,
    output logic powFlag,
    output logic fruitSpawnFlag

  );

  parameter logic [TILE_BITS-1:0] EMPTY_BUT_WASNT = 10;
  parameter logic [TILE_BITS-1:0] COIN = 1;
  parameter logic [TILE_BITS-1:0] CHERRY = 6;
  parameter logic [TILE_BITS-1:0] BREAK1 = 13;
  parameter logic [TILE_BITS-1:0] BREAK2 = 14;
  parameter logic [TILE_BITS-1:0] BREAK3 = 15;

  localparam MAP_WIDTH_X_BITS = $clog2(MAP_WIDTH_X);
  localparam MAP_HEIGHT_Y_BITS = $clog2(MAP_HEIGHT_Y);

  localparam BASE_BREAKABLES = 15; // walls at level 1
  logic [7:0] wallsToGenerate;

  logic [MAP_WIDTH_X_BITS - 1:0] pacX;
  logic [MAP_HEIGHT_Y_BITS - 1:0] pacY;

  assign wallsToGenerate = BASE_BREAKABLES + (level * 6);

  logic [7:0]   betterRand;

  typedef enum logic [1:0] {
            PRE_PLACE,
            PLACING,
            POST_PLACE
          } wall_placement_st;

  wall_placement_st addBreak_st;  // 0 = pre-placement 1=placing 2=post-placement
  logic [7:0] amountOfBreakableWallsPlaced;
  logic [TILE_BITS:0] randTileType;
  logic [TILE_BITS:0] wallTypeToPlace;
  logic [TILE_BITS:0] pickUpTypeToPlace;

  // previous tileX and tileY to detect when we move to a new tile
  logic [4:0] prevTileX;
  logic [4:0] prevTileY;
  logic [4:0] lastPlacedX;
  logic [4:0] lastPlacedY;
  logic [4:0] lastPlacedYForPickUp;
  logic isFarFromLastPlacement;
  logic canPlaceWall;
  logic isInBounds;
  logic hasPlacedInThisFrame; // this flag creates cool wall apperance effect and ensures random is better
  logic wallUpdate;
  logic coinValueUpdate;
  logic collisionFlag;
  logic isFarFromPacman;
  logic canPlacePickup;
  logic isFarFromLastPickUp;
  

  // pickups
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
  logic fruitSpawnPending;
  logic picUpFlag;

  

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      prevTileX <= 5'd0;
      prevTileY <= 5'd0;
    end
    else if ((currentTileX != prevTileX || currentTileY != prevTileY) && isScanInsideMap) begin
      prevTileX <= currentTileX;
      prevTileY <= currentTileY;
    end
  end

  // Breakable walls placement state machine
always_ff @(posedge clk or negedge resetN)
	begin
	  if (!resetN) begin
		 addBreak_st <= PRE_PLACE;
		 amountOfBreakableWallsPlaced <= 8'd0;
		 wallTypeToPlace <= BREAK1;
		 wallUpdate <= 1'b0;
		 lastPlacedX <= 5'd0;
		 lastPlacedY <= 5'd0;
	  end
	  else begin
		 wallUpdate <= 1'b0;
		 
		 if ((currentTileX != prevTileX || currentTileY != prevTileY) && isScanInsideMap) begin
			case (addBreak_st)
			  PRE_PLACE: begin
				 if ((coinsCollected * 100) > (5 * coinsPowTot)) begin
					amountOfBreakableWallsPlaced <= 8'd0;
					addBreak_st <= PLACING;
				 end
			  end
			  
			  PLACING: begin
				 if (amountOfBreakableWallsPlaced < wallsToGenerate) begin
					if ((betterRand == 137) && canPlaceWall) begin
					  wallTypeToPlace <= randTileType;
					  wallUpdate <= 1'b1;
					  amountOfBreakableWallsPlaced <= amountOfBreakableWallsPlaced + 1;
					  lastPlacedX <= currentTileX;
					  lastPlacedY <= currentTileY;
					end
				 end else begin
					addBreak_st <= POST_PLACE;
				 end
			  end
			  
			  POST_PLACE: begin
				 // Do nothing, placement complete
			  end
			endcase
		 end
	  end
	end

  // collision detection
always_ff @(posedge clk or negedge resetN) begin
  if (!resetN) begin
    coinsCollected      <= 0;
    powerCollected      <= 0;
    coinFlag          <= 1'b0;
    powFlag           <= 1'b0;
    picUpFlag        <= 1'b0;
    collisionFlag       <= 1'b0;
  end else begin
    // default
    coinFlag          <= 1'b0;
    powFlag           <= 1'b0;
    picUpFlag        <= 1'b0;

    if (startOfFrame)
      collisionFlag <= 1'b0;

    if (!collisionFlag) begin
      if (coinCollision) begin
        coinsCollected      <= coinsCollected + 1;
        coinFlag <= 1'b1;
        collisionFlag       <= 1'b1;
      end else if (powerCollision) begin
        powerCollected      <= powerCollected + 1;
        powFlag           <= 1'b1;
        collisionFlag       <= 1'b1;
      end else if (pickUpCollision) begin
        picUpFlag        <= 1'b1;
        collisionFlag       <= 1'b1;
      end
    end
  end
 end

 // pickup placement logic
 always_ff @(posedge clk or negedge resetN) begin
   if (!resetN) begin
     currPicUp <= 0;
     fruitSpawnPending <= 1'b0;
     fruitSpawnFlag   <= 1'b0;
	  lastPlacedYForPickUp <= 1'b0;
   end else begin
     fruitSpawnFlag <= 1'b0;
     if (startOfFrame) begin
       if (!fruitSpawnPending && (coinsCollected * 100 >= FRUIT_THRESH[currPicUp] * coinsPowTot)) begin
         fruitSpawnPending <= 1'b1;
       end
     end

     if (fruitSpawnPending && (currentTileX != prevTileX || currentTileY != prevTileY) && isScanInsideMap) begin
       if (canPlacePickup && betterRand == 8'd145) begin
         fruitSpawnFlag <= 1'b1;
         pickUpTypeToPlace <= CHERRY + (rnd % PICKUPS_TYPES); // random pickup type
         fruitSpawnPending <= 1'b0;
         currPicUp <= currPicUp + 1;
       end
     end
   end
 end

  // wall placement logic
  always_comb begin
    pacX = pactopLeftX >> TILE_BITS;
    pacY = (pactopLeftY >> TILE_BITS) - 1;
    isInBounds = currentTileX < MAP_WIDTH_X - 1 && currentTileY < MAP_HEIGHT_Y - 1 && currentTileX > 0 && currentTileY > 0;
    isFarFromPacman = ($unsigned(currentTileX - pacX) > 1) && ($unsigned(currentTileY - pacY) > 1);
    isFarFromLastPlacement = ($unsigned(currentTileX - lastPlacedX) > 8) 
                          && ($unsigned(currentTileY - lastPlacedY) > 8);
    canPlaceWall = isInBounds && isFarFromPacman && currentTileValue == COIN && isFarFromLastPlacement;
    betterRand = rnd ^ currentTileX ^ currentTileY  ^ pactopLeftX[7:0] ^ pactopLeftY[7:0];
	 isFarFromLastPickUp = $unsigned(currentTileY - lastPlacedYForPickUp) > 10;
	 canPlacePickup = isInBounds && isFarFromPacman && currentTileValue == EMPTY_BUT_WASNT && isFarFromLastPickUp;
    case(rnd[1:0])
      2'b00: randTileType = BREAK3; 
      2'b01: randTileType = BREAK2;
      default: randTileType = BREAK1; 
    endcase
  end

  // update Logic
  always_comb begin
    updateValueForTile = wallUpdate || coinFlag || powFlag || picUpFlag || fruitSpawnFlag;
    if (wallUpdate) begin
      newTileValue = wallTypeToPlace;
    end else if (coinFlag || powFlag || picUpFlag) begin
      newTileValue = EMPTY_BUT_WASNT;
    end else if (fruitSpawnFlag) begin
      newTileValue = pickUpTypeToPlace;
    end else begin
      newTileValue = currentTileValue;
    end
  end

  assign placeBreakFlag = (addBreak_st == PLACING); 

endmodule
