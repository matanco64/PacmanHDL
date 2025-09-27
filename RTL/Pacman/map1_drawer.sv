module map1_drawer (
    input logic clk,
    input logic resetN,
    input logic signed [10:0] pixelX,  //  current VGA pixel 
    input logic signed [10:0] pixelY,
    input logic coinCollision,  // Marks collision with pacman and coin, relevant cell should be disabled.
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

    //outputs//
    output logic drawingRequest,  // output that the pixel should be displayed
    output logic drawingCoin,  // ouput Whether a coin is drawn or not
    output logic drawingPow,
    output logic [7:0] RGBout,  // rgb value from the bitmap

    //Ghosts - outputs - change if TILE_SIZE changes
    output logic [11:0] aroundBlinky,
    output logic [11:0] aroundPinky,
    output logic [11:0] aroundInky,
    output logic [11:0] aroundClyde,
    output logic [11:0] aroundPac,
    output logic [ 8:0] coinsPowTot, // pow and coins!
    output logic [ 8:0] coinsCollected,
    output logic [ 8:0] powerCollected
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

  localparam logic [7:0] TRANSPARENT_ENCODING = 0;
  localparam logic [TILE_BITS-1:0] EMPTY = 0;
  localparam logic [TILE_BITS-1:0] COIN = 1;
  localparam logic [TILE_BITS-1:0] WALL = 2;
  localparam logic [TILE_BITS-1:0] GHOST_WALL = 3;
  localparam logic [TILE_BITS-1:0] PORTAL = 4;
  localparam logic [TILE_BITS-1:0] POWER = 5;

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
    { 3'd4, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd5, 3'd3, 3'd0, 3'd2, 3'd2, 3'd2, 3'd5, 3'd2, 3'd2, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd0, 3'd4 },
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

  logic [0:MAP_HEIGHT_Y-1][0:MAP_WIDTH_X-1][TILE_BITS-1:0] pacmanMap;
  logic [TILE_BITS-1:0] tile;

  logic [3:0] offsetX;
  logic [3:0] offsetY;
  logic coinFlag;
  logic powFlag;

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

  // Ghosts
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

  assign aroundBlinky = aroundGhost(BlinkytopLeftX, BlinkytopLeftY);
  assign aroundPinky = aroundGhost(PinkytopLeftX, PinkytopLeftY);
  assign aroundInky = aroundGhost(InkytopLeftX, InkytopLeftY);
  assign aroundClyde = aroundGhost(ClydetopLeftX, ClydetopLeftY);
  assign aroundPac = aroundGhost(pactopLeftX, pactopLeftY);
  

  // ---------------------------------------------------------------------------
  // always_ff blocks
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk or negedge resetN) begin

    if (!resetN) begin
      RGBout <= 8'b0;
      drawingRequest <= 1'b0;
      pacmanMap <= OriginalPacmanMap;
      coinsPowTot <= countCoins(OriginalPacmanMap);
      coinsCollected <= 0;
      powerCollected <= 0;
      coinFlag <= 0;
    end else begin
      RGBout <= TRANSPARENT_ENCODING;
      drawingRequest <= 1'b0;
      drawingCoin <= 1'b0;
      drawingPow <= 1'b0;
      tile = pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1];

      if (pixelY / TILE_SIZE >= 1) begin
        case (tile)
          GHOST_WALL: begin
            RGBout <= GHOST_WALL_COLOR;
            drawingRequest <= 1'b1;
          end

          WALL: begin
            RGBout <= WALL_COLOR;
            drawingRequest <= 1'b1;
          end

          PORTAL: begin
            RGBout <= PORTAL_COLOR;
            drawingRequest <= 1'b1;
          end

          COIN: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            if (offsetX >= 6 && offsetX < 10 && offsetY >= 6 && offsetY < 10) begin
              RGBout <= COIN_COLOR;
              drawingCoin <= 1'b1;
            end
            if (coinCollision) begin
              pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
              if (!coinFlag) begin
                coinFlag <= 1'b1;
                coinsCollected <= coinsCollected + 1;
              end
            end else coinFlag <= 1'b0;
          end

          POWER: begin
            offsetX = pixelX % TILE_SIZE;
            offsetY = pixelY % TILE_SIZE;
            if (offsetX >= 4 && offsetX < 12 && offsetY >= 4 && offsetY < 12) begin
              RGBout <= POW_COLOR;
              drawingPow <= 1'b1;
            end
            if (powerCollision) begin
              pacmanMap[pixelX/TILE_SIZE][pixelY/TILE_SIZE-1] <= EMPTY;
              if (!powFlag) begin
                powFlag <= 1'b1;
                powerCollected <= powerCollected + 1;
              end
            end else powFlag <= 1'b0;
          end


          default: begin
            drawingRequest <= 1'b0;
            drawingCoin <= 1'b0;
            drawingPow <= 1'b0;
            RGBout <= TRANSPARENT_ENCODING;
          end
        endcase

      end
    end
  end

endmodule
