// Pacman_Player: converted from the Quartus schematic RTL/Pacman/Pacman_Player.bdf (see DE-10 branch).
module Pacman_Player (
  input logic keyPadValid,
  input logic [3:0] KeyPadCode,
  input logic [10:0] pixelX,
  input logic [10:0] pixelY,
  input logic collisionPacWall,
  input logic [2:0] collisionPacGhost,
  input logic [2:0] gameState,
  input logic [1:0] speedChange,
  input logic [15:0] aroundPac,
  input logic clk,
  input logic resetN,
  input logic startOfFrame,
  input logic oneSec,
  output logic pacmanDR,
  output logic [7:0] pacmanRGB,
  output logic [10:0] pacmanX,
  output logic [10:0] pacmanY,
  output logic [1:0] pacmanDir,
  output logic recovering
);
  logic [3:0] DirKey;
  logic inst6_drawingRequest;
  logic [10:0] inst6_offsetX;
  logic [10:0] inst6_offsetY;
  logic [10:0] topLeftX;
  logic [10:0] topLeftY;
  assign pacmanX = topLeftX[10:0];
  assign pacmanY = topLeftY[10:0];

  square_object #(.OBJECT_WIDTH_X(16), .OBJECT_HEIGHT_Y(16), .OBJECT_COLOR(2'b00)) inst6 (
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
  pacman_move #(.INITIAL_X(224), .INITIAL_Y(304), .WALL(2), .GHOST_WALL(3), .PORTAL(4), .SCREEN_HEIGHT(480), .SCREEN_WIDTH(640), .TILE_PIXELS(16), .RESET_ST(3'b000), .START_WAIT_ST(3'b001), .PLAYING_ST(3'b010), .PAUSED_ST(3'b011), .GHOST_HIT_ST(3'b100), .WIN_ST(3'b101), .LOSE_ST(3'b110), .POWER_UP_ST(3'b111)) inst_pacman (
    .clk(clk),
    .resetN(resetN),
    .startOfFrame(startOfFrame),
    .oneSec(oneSec),
    .keyPadCode(KeyPadCode[3:0]),
    .keyPadValid(keyPadValid),
    .collision_pac_wall(collisionPacWall),
    .collision_pac_ghost(collisionPacGhost[2:0]),
    .aroundPac(aroundPac[15:0]),
    .gameState(gameState[2:0]),
    .speedChange(speedChange[1:0]),
    .topLeftX(topLeftX[10:0]),
    .topLeftY(topLeftY[10:0]),
    .curDirKey(DirKey[3:0]),
    .curDir(pacmanDir[1:0]),
    .recovering(recovering)
  );
  pacman_mouth_openBitMap inst (
    .clk(clk),
    .resetN(resetN),
    .offsetX(inst6_offsetX),
    .offsetY(inst6_offsetY),
    .InsideRectangle(inst6_drawingRequest),
    .inputDirection(DirKey[3:0]),
    .startOfFrame(startOfFrame),
    .recovering(recovering),
    .drawingRequest(pacmanDR),
    .RGBout(pacmanRGB),
    .HitEdgeCode()
  );
endmodule
