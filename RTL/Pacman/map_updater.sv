// this module updates the map based on the current pixel being scanned and other data
// the reason for this module is to ensure only one place updates the map to avoid conflicts and extra logic
module map_updater # (
    TILE_BITS = 4,
    MAP_WIDTH_X = 31,
    MAP_HEIGHT_Y = 28
  ) (
    input  logic         clk,
    input  logic         resetN,
    input  logic [7:0]   rnd,
    input  logic [3:0]   level,
    input  logic [4:0]   currentTileX,
    input  logic [4:0]   currentTileY,
    input logic [10:0] pactopLeftX,
    input logic [10:0] pactopLeftY,

    // coins
    input  logic [8:0] coinsCollected,
    input  logic [8:0] powerCollected,
    input  logic [8:0] coinsPowTot,


    input logic [TILE_BITS -1:0]   currentTileValue,
    output  logic [TILE_BITS -1:0]   newTileValue,
    output logic        placeBreakFlag

  );

  parameter logic [TILE_BITS-1:0] BREAK1 = 13;
  parameter logic [TILE_BITS-1:0] BREAK2 = 14;
  parameter logic [TILE_BITS-1:0] BREAK3 = 15;
  parameter logic [TILE_BITS-1:0] COIN = 1;

  localparam MAP_WIDTH_X_BITS = $clog2(MAP_WIDTH_X);
  localparam MAP_HEIGHT_Y_BITS = $clog2(MAP_HEIGHT_Y);

  localparam BASE_BREAKABLES = 15; // walls at level 1
  logic [7:0] wallsToGenerate;

  logic [MAP_WIDTH_X_BITS - 1:0] pacX;
  logic [MAP_HEIGHT_Y_BITS - 1:0] pacY;

  assign wallsToGenerate = BASE_BREAKABLES + (level * 6);

  typedef enum logic [1:0] {
            PRE_PLACE,
            PLACING,
            POST_PLACE
          } wall_placement_st;

  wall_placement_st addBreak_st;  // 0 = pre-placement 1=placing 2=post-placement
  logic [7:0] amountOfBreakableWallsPlaced;
  logic [TILE_BITS:0] randTileType;

  // previous tileX and tileY to detect when we move to a new tile
  logic [4:0] prevTileX;
  logic [4:0] prevTileY;
  logic canPlaceWall;

  


  always_ff @(posedge clk or negedge resetN)
  begin
    if (!resetN) begin
      addBreak_st <= PRE_PLACE;
      prevTileX <= 5'd0;
      prevTileY <= 5'd0;
      amountOfBreakableWallsPlaced <= 8'd0;
      // coinsCollected <= 0;
      // powerCollected <= 0;
    end
    else begin
      newTileValue = currentTileValue;
      if (currentTileX != prevTileX || currentTileY != prevTileY) begin
        prevTileX <= currentTileX;
        prevTileY <= currentTileY;


        case (addBreak_st)
          PRE_PLACE: begin
            if ((coinsCollected * 100) > (5  * coinsPowTot)) begin
                amountOfBreakableWallsPlaced <= 8'd0;
                addBreak_st <= PLACING;
            end
          end
          PLACING: begin
            if ((amountOfBreakableWallsPlaced < wallsToGenerate) && canPlaceWall) begin
              if ((rnd % 8) == 0) begin// 1 in 8 chance to place a breakable wall
                newTileValue = randTileType;
                amountOfBreakableWallsPlaced <= amountOfBreakableWallsPlaced + 1;
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

  always_comb begin
    pacX = pactopLeftX >> TILE_BITS;
    pacY = (pactopLeftY >> TILE_BITS) - 1;
    canPlaceWall = ($unsigned(currentTileX - pacX) > 1) && ($unsigned(currentTileY - pacY) > 1)
    && currentTileValue == COIN;
    
    case(rnd[1:0])
      2'b00: randTileType = BREAK3; 
      2'b01: randTileType = BREAK2;
      default: randTileType = BREAK1; 
    endcase
  end

  assign placeBreakFlag = (addBreak_st == PLACING); 

endmodule
