// Ghost: converted from the Quartus schematic RTL/Pacman/Ghost.bdf (see DE-10 branch).
module Ghost #(
  parameter initial_X = 100,
  parameter initial_Y = 100
) (
  input logic clk,
  input logic resetN,
  input logic startOfFrame,
  input logic [10:0] pixelX,
  input logic [10:0] pixelY,
  input logic [1:0] ghostSelect,
  input logic [10:0] pacmanX,
  input logic [10:0] pacmanY,
  input logic [1:0] pacmanDir,
  input logic [2:0] collisionPacGhost,
  input logic [2:0] gameState,
  input logic [3:0] countL,
  input logic [3:0] countH,
  input logic [15:0] aroundGhost,
  input logic oneSec,
  input logic [7:0] rnd,
  output logic DR,
  output logic [7:0] RGB,
  output logic [10:0] topLeftX,
  output logic [10:0] topLeftY
);
  logic [1:0] ghostDir;
  logic inst6_drawingRequest;
  logic [10:0] inst6_offsetX;
  logic [10:0] inst6_offsetY;

  square_object #(.OBJECT_WIDTH_X(32), .OBJECT_HEIGHT_Y(32), .OBJECT_COLOR(2'b00)) inst6 (
    .clk(clk),
    .resetN(resetN),
    .pixelX(pixelX[10:0]),
    .pixelY(pixelY[10:0]),
    .topLeftX(topLeftX[10:0]),
    .topLeftY(topLeftY[10:0]),
    .offsetX(inst6_offsetX),
    .offsetY(inst6_offsetY),
    .drawingRequest(inst6_drawingRequest),
    .RGBout()
  );
  characterBitMap inst2 (
    .clk(clk),
    .resetN(resetN),
    .oneSec(oneSec),
    .rnd(rnd[7:0]),
    .offsetX(inst6_offsetX),
    .offsetY(inst6_offsetY),
    .InsideRectangle(inst6_drawingRequest),
    .startOfFrame(startOfFrame),
    .characterSelect(ghostSelect[1:0]),
    .gameState(gameState[2:0]),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .ghostDir(ghostDir[1:0]),
    .drawingRequest(DR),
    .RGBout(RGB)
  );
  ghost_move #(.FIXED_POINT_MULTIPLIER(16), .TILE_BITS(3), .MOVEMENT_SPEED(16), .TILE_PIXELS(16), .SCREEN_HEIGHT(480), .SCREEN_WIDTH(640), .EMPTY(3'b000), .WALL(3'b010), .GHOST_WALL(3'b011), .PORTAL(3'b100), .FRIGHTENED_TIME(11'b00010110100), .BLINKY_HOME_X(600), .BLINKY_HOME_Y(50), .PINKY_HOME_X(50), .PINKY_HOME_Y(50), .INKY_HOME_X(600), .INKY_HOME_Y(430), .CLYDE_HOME_X(50), .CLYDE_HOME_Y(430), .INITIAL_X(initial_X), .INITIAL_Y(initial_Y), .RESET_ST(3'b000), .START_WAIT_ST(3'b001), .PLAYING_ST(3'b010), .PAUSED_ST(3'b011), .GHOST_HIT_ST(3'b100), .WIN_ST(3'b101), .LOSE_ST(3'b110), .POWER_UP_ST(3'b111), .DIR_UP(2'b00), .DIR_DOWN(2'b01), .DIR_LEFT(2'b10), .DIR_RIGHT(2'b11), .SCATTER_DURATION(7), .CHASE_DURATION(20)) inst (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .oneSec(oneSec),
    .ghostSelect(ghostSelect[1:0]),
    .aroundGhost(aroundGhost[15:0]),
    .pacmanX(pacmanX[10:0]),
    .pacmanY(pacmanY[10:0]),
    .pacmanDir(pacmanDir[1:0]),
    .collisionPacGhost(collisionPacGhost[2:0]),
    .gameState(gameState[2:0]),
    .topLeftX(topLeftX[10:0]),
    .topLeftY(topLeftY[10:0]),
    .ghostDir(ghostDir[1:0])
  );
endmodule
