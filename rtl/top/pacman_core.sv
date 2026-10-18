// Board-independent Pacman game: everything from the DE-10 top-level schematic
// (RTL/Pacman.bdf on the DE-10 branch) except the PLL, PS/2 keyboard, audio
// codec, 7-segment and VGA output. Scan position in, RGB332 pixel out.
module pacman_core #(
  parameter int CLK_HZ = 31_500_000
) (
  input  logic        clk,
  input  logic        resetN,
  // raster position, same semantics as the DE-10 VGA_Controller:
  // 0..639 / 0..479 inside the picture, held at 0 outside it
  input  logic [10:0] pixelX,
  input  logic [10:0] pixelY,
  input  logic        startOfFrame,
  // controls (previously PS/2 keypad + DE-10 switches/keys)
  input  logic [3:0]  keyPad,       // 8=up 2=down 4=left 6=right
  input  logic        keyPadValid,
  input  logic        star,         // wall-break keys: * then / then NumLock
  input  logic        slash,
  input  logic        num,
  input  logic        pauseN,
  input  logic        turbo,
  input  logic        level_key,    // active low, falling edge = next level
  output logic [7:0]  RGB           // RRRGGGBB
);

  // The game runs one clock behind its inputs. The tile map lives in block
  // RAM (1 clock read latency) and is addressed with the un-delayed scan
  // position, so its data lines up with what the game logic sees. Every input,
  // reset release included, goes through the same register stage, which makes
  // the core an exact one-clock-delayed copy of the original DE-10 design.
  logic        coreResetN;
  logic [10:0] scanX, scanY;
  logic        scanStartOfFrame;
  logic [3:0]  keyPadQ;
  logic        keyPadValidQ, starQ, slashQ, numQ, pauseNQ, turboQ, level_keyQ;

  always_ff @(posedge clk)
    if (!resetN) coreResetN <= 1'b0;
    else         coreResetN <= 1'b1;

  always_ff @(posedge clk) begin
    scanX            <= pixelX;
    scanY            <= pixelY;
    scanStartOfFrame <= startOfFrame;
    keyPadQ          <= keyPad;
    keyPadValidQ     <= keyPadValid;
    starQ            <= star;
    slashQ           <= slash;
    numQ             <= num;
    pauseNQ          <= pauseN;
    turboQ           <= turbo;
    level_keyQ       <= level_key;
  end

  logic BlinkyDR;
  logic [7:0] BlinkyRGB;
  logic [10:0] BlinkytopLeftX;
  logic [10:0] BlinkytopLeftY;
  logic ClydeDR;
  logic [7:0] ClydeRGB;
  logic [10:0] ClydetopLeftX;
  logic [10:0] ClydetopLeftY;
  logic CoinsDR;
  logic GND;
  logic InkyDR;
  logic [7:0] InkyRGB;
  logic [10:0] InkytopLeftX;
  logic [10:0] InkytopLeftY;
  logic LevelNumDR;
  logic LevelTxtDR;
  logic [7:0] MIF_VGA;
  logic MapDR;
  logic [7:0] MapRGB;
  logic PacmanDR;
  logic [7:0] PacmanRGB;
  logic PinkyDR;
  logic [7:0] PinkyRGB;
  logic [10:0] PinkytopLeftX;
  logic [10:0] PinkytopLeftY;
  logic [7:0] RGBLevelNum;
  logic [7:0] RGBLevelTxt;
  logic [7:0] RGBScore0;
  logic [7:0] RGBScore1;
  logic [7:0] RGBScore2;
  logic [7:0] RGBScoreTxt;
  logic [7:0] RGBend;
  logic [7:0] RGBheart;
  logic [3:0] Score0;
  logic Score0DR;
  logic [3:0] Score1;
  logic Score1DR;
  logic [3:0] Score2;
  logic Score2DR;
  logic ScoreTxtDR;
  logic [1:0] SelectBlinkey;
  logic [1:0] SelectClyde;
  logic [1:0] SelectInky;
  logic [1:0] SelectPinkey;
  logic VCC;
  logic [15:0] aroundBlinky;
  logic [15:0] aroundClyde;
  logic [15:0] aroundInky;
  logic [15:0] aroundPac;
  logic [15:0] aroundPinky;
  logic breakFlag;
  logic coinFlag;
  logic collisionPacCoin;
  logic [2:0] collisionPacGhost;
  logic collisionPacPow;
  logic collisionPacWall;
  logic [3:0] countH;
  logic [3:0] countL;
  logic [2:0] currLives;
  logic [3:0] datainH;
  logic [3:0] datainL;
  logic endDR;
  logic fogDR;
  logic [7:0] fogRGB;
  logic fruitSpawnFlag;
  logic [2:0] gameState;
  logic ghostFlag;
  logic heartDR;
  logic isWin;
  logic [3:0] level;
  logic levelChanged;
  logic [3:0] levelNum;
  logic one_sec;
  logic [1:0] pacLifeChange;
  logic [1:0] pacSpeedChange;
  logic [1:0] pacmanDir;
  logic [10:0] pacmanX;
  logic [10:0] pacmanY;
  logic [10:0] parcialScore;
  logic picUpFlag;
  logic [2:0] picUpTypeFlag;
  logic pickUpDR;
  logic placeBreakFlag;
  logic powFlag;
  logic powerDR;
  logic recovering;
  logic [7:0] rnd;
  logic startCountN;
  logic timerEnd;
  logic [10:0] topLeftXEnd;
  logic [10:0] topLeftXHeart;
  logic [10:0] topLeftXLevelNum;
  logic [10:0] topLeftXLevelTxt;
  logic [10:0] topLeftXScore0;
  logic [10:0] topLeftXScore1;
  logic [10:0] topLeftXScore2;
  logic [10:0] topLeftXScoreTxt;
  logic [10:0] topLeftYEnd;
  logic [10:0] topLeftYHeart;
  logic [10:0] topLeftYLevelNum;
  logic [10:0] topLeftYLevelTxt;
  logic [10:0] topLeftYScore0;
  logic [10:0] topLeftYScore1;
  logic [10:0] topLeftYScore2;
  logic [10:0] topLeftYScoreTxt;

  MyConstant #(.size(2), .MyValue(1)) inst24 (
    .value(SelectPinkey[1:0])
  );
  MyConstant #(.size(2), .MyValue(2)) inst27 (
    .value(SelectInky[1:0])
  );
  MyConstant #(.size(11), .MyValue(512)) inst22 (
    .value(topLeftXScoreTxt[10:0])
  );
  MyConstant #(.size(2), .MyValue(0)) inst33 (
    .value(SelectBlinkey[1:0])
  );
  MyConstant #(.size(2), .MyValue(3)) inst29 (
    .value(SelectClyde[1:0])
  );
  heart #(.COLOR(8'b11111110), .HEIGHT(48), .WIDTH(96)) inst37 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .topLeftX(topLeftXHeart[10:0]),
    .topLeftY(topLeftYHeart[10:0]),
    .currLives(currLives[2:0]),
    .heartDrawingRequest(heartDR),
    .RGBheart(RGBheart[7:0])
  );
  assign GND = 1'b0;
  assign VCC = 1'b1;
  random2 #(.WIDTH(8)) inst38 (
    .clk(clk),
    .resetN(coreResetN),
    .rnd(rnd[7:0])
  );
  Pacman_Player inst1 (
    .clk(clk),
    .resetN(coreResetN),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .KeyPadCode(keyPadQ[3:0]),
    .keyPadValid(keyPadValidQ),
    .collisionPacWall(collisionPacWall),
    .collisionPacGhost(collisionPacGhost[2:0]),
    .pixelX(scanX),
    .pixelY(scanY),
    .aroundPac(aroundPac[15:0]),
    .gameState(gameState[2:0]),
    .speedChange(pacSpeedChange[1:0]),
    .pacmanDR(PacmanDR),
    .pacmanRGB(PacmanRGB[7:0]),
    .pacmanX(pacmanX[10:0]),
    .pacmanY(pacmanY[10:0]),
    .pacmanDir(pacmanDir[1:0]),
    .recovering(recovering)
  );
  MyConstant #(.size(11), .MyValue(32)) inst23 (
    .value(topLeftYScoreTxt[10:0])
  );
  Number #(.WIDTH(16), .HEIGHT(16), .COLOR(8'b11110111)) inst30 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .digit(Score2[3:0]),
    .topLeftX(topLeftXScore2[10:0]),
    .topLeftY(topLeftYScore2[10:0]),
    .NumDrawingRequest(Score2DR),
    .RGBNum1(RGBScore2[7:0])
  );
  Number #(.WIDTH(16), .HEIGHT(16), .COLOR(8'b11110111)) inst14 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .digit(Score1[3:0]),
    .topLeftX(topLeftXScore1[10:0]),
    .topLeftY(topLeftYScore1[10:0]),
    .NumDrawingRequest(Score1DR),
    .RGBNum1(RGBScore1[7:0])
  );
  Number #(.WIDTH(16), .HEIGHT(16), .COLOR(8'b11110111)) inst20 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .digit(Score0[3:0]),
    .topLeftX(topLeftXScore0[10:0]),
    .topLeftY(topLeftYScore0[10:0]),
    .NumDrawingRequest(Score0DR),
    .RGBNum1(RGBScore0[7:0])
  );
  MyConstant #(.size(11), .MyValue(512)) inst41 (
    .value(topLeftXEnd[10:0])
  );
  MyConstant #(.size(11), .MyValue(512)) inst35 (
    .value(topLeftXHeart[10:0])
  );
  MyConstant #(.size(11), .MyValue(512)) inst47 (
    .value(topLeftXLevelTxt[10:0])
  );
  Score #(.COLOR(8'b11110111), .HEIGHT(16), .WIDTH(64)) inst49 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .topLeftX(topLeftXLevelTxt[10:0]),
    .topLeftY(topLeftYLevelTxt[10:0]),
    .text(VCC),
    .ScoreTxtDrawingRequest(LevelTxtDR),
    .RGBScoreTxt(RGBLevelTxt[7:0])
  );
  Number #(.WIDTH(16), .HEIGHT(16), .COLOR(8'b11110111)) inst52 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .digit(level[3:0]),
    .topLeftX(topLeftXLevelNum[10:0]),
    .topLeftY(topLeftYLevelNum[10:0]),
    .NumDrawingRequest(LevelNumDR),
    .RGBNum1(RGBLevelNum[7:0])
  );
  MyConstant #(.size(4), .MyValue(1)) inst53 (
    .value(levelNum[3:0])
  );
  Score #(.COLOR(8'b11110111), .HEIGHT(16), .WIDTH(64)) inst25 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .topLeftX(topLeftXScoreTxt[10:0]),
    .topLeftY(topLeftYScoreTxt[10:0]),
    .text(GND),
    .ScoreTxtDrawingRequest(ScoreTxtDR),
    .RGBScoreTxt(RGBScoreTxt[7:0])
  );
  MyConstant #(.size(11), .MyValue(512)) inst12 (
    .value(topLeftXScore2[10:0])
  );
  MyConstant #(.size(11), .MyValue(56)) inst19 (
    .value(topLeftYScore2[10:0])
  );
  MyConstant #(.size(11), .MyValue(56)) inst11 (
    .value(topLeftYScore1[10:0])
  );
  MyConstant #(.size(11), .MyValue(56)) inst15 (
    .value(topLeftYScore0[10:0])
  );
  MyConstant #(.size(11), .MyValue(528)) inst2 (
    .value(topLeftXScore1[10:0])
  );
  MyConstant #(.size(11), .MyValue(544)) inst8 (
    .value(topLeftXScore0[10:0])
  );
  MyConstant #(.size(11), .MyValue(512)) inst50 (
    .value(topLeftXLevelNum[10:0])
  );
  MyConstant #(.size(11), .MyValue(104)) inst48 (
    .value(topLeftYLevelTxt[10:0])
  );
  MyConstant #(.size(11), .MyValue(128)) inst51 (
    .value(topLeftYLevelNum[10:0])
  );
  MyConstant #(.size(11), .MyValue(176)) inst36 (
    .value(topLeftYHeart[10:0])
  );
  sideBitMapTop #(.COLOR(8'b11111110), .WIDTH(64), .HEIGHT(64)) inst40 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .gameState(gameState[2:0]),
    .topLeftX(topLeftXEnd[10:0]),
    .topLeftY(topLeftYEnd[10:0]),
    .sideDR(endDR),
    .RGBside(RGBend[7:0])
  );
  MyConstant #(.size(11), .MyValue(240)) inst39 (
    .value(topLeftYEnd[10:0])
  );
  fog_mask #(.TILE_SIZE(16), .MAP_WIDTH_X(31), .MAP_HEIGHT_Y(28)) inst54 (
    .clk(clk),
    .resetN(coreResetN),
    .pixelX(scanX),
    .pixelY(scanY),
    .level(level[3:0]),
    .pactopLeftX(pacmanX[10:0]),
    .pactopLeftY(pacmanY[10:0]),
    .fogDR(fogDR),
    .RGBfog(fogRGB[7:0])
  );
  objects_mux inst9 (
    .clk(clk),
    .resetN(coreResetN),
    .RGB_MIF(MIF_VGA[7:0]),
    .fogDR(fogDR),
    .fogRGB(fogRGB[7:0]),
    .PacmanDR(PacmanDR),
    .PacmanRGB(PacmanRGB[7:0]),
    .pinkyDR(PinkyDR),
    .pinkyRGB(PinkyRGB[7:0]),
    .inkyDR(InkyDR),
    .inkyRGB(InkyRGB[7:0]),
    .clydeDR(ClydeDR),
    .clydeRGB(ClydeRGB[7:0]),
    .blinkyDR(BlinkyDR),
    .blinkyRGB(BlinkyRGB[7:0]),
    .Score0DR(Score0DR),
    .Score0RGB(RGBScore0[7:0]),
    .Score1DR(Score1DR),
    .Score1RGB(RGBScore1[7:0]),
    .Score2DR(Score2DR),
    .Score2RGB(RGBScore2[7:0]),
    .ScoreTxtDR(ScoreTxtDR),
    .ScoreTxtRGB(RGBScoreTxt[7:0]),
    .heartDR(heartDR),
    .heartRGB(RGBheart[7:0]),
    .endDR(endDR),
    .endRGB(RGBend[7:0]),
    .levelTxtDR(LevelTxtDR),
    .levelTxtRGB(RGBLevelTxt[7:0]),
    .levelNumDR(LevelNumDR),
    .levelNumRGB(RGBLevelNum[7:0]),
    .MapDR(MapDR),
    .CoinDR(CoinsDR),
    .powerDR(powerDR),
    .pickUpDR(pickUpDR),
    .MapRGB(MapRGB[7:0]),
    .RGBOut(RGB[7:0])
  );
  map1_drawer inst45 (
    .clk(clk),
    .pixelXAhead(pixelX),
    .pixelYAhead(pixelY),
    .resetN(coreResetN),
    .pauseN(pauseNQ),
    .pixelX(scanX),
    .pixelY(scanY),
    .rnd(rnd[7:0]),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .gameState(gameState[2:0]),
    .coinCollision(collisionPacCoin),
    .powerCollision(collisionPacPow),
    .BlinkytopLeftX(BlinkytopLeftX[10:0]),
    .BlinkytopLeftY(BlinkytopLeftY[10:0]),
    .PinkytopLeftX(PinkytopLeftX[10:0]),
    .PinkytopLeftY(PinkytopLeftY[10:0]),
    .InkytopLeftX(InkytopLeftX[10:0]),
    .InkytopLeftY(InkytopLeftY[10:0]),
    .ClydetopLeftX(ClydetopLeftX[10:0]),
    .ClydetopLeftY(ClydetopLeftY[10:0]),
    .pactopLeftX(pacmanX[10:0]),
    .pactopLeftY(pacmanY[10:0]),
    .pacDir(pacmanDir[1:0]),
    .pacmanDR(PacmanDR),
    .starKey(starQ),
    .slashKey(slashQ),
    .numLockKey(numQ),
    .level(level[3:0]),
    .isWin(isWin),
    .mapDR(MapDR),
    .coinsDR(CoinsDR),
    .powerDR(powerDR),
    .pickUpDR(pickUpDR),
    .RGBout(MapRGB[7:0]),
    .aroundBlinky(aroundBlinky[15:0]),
    .aroundPinky(aroundPinky[15:0]),
    .aroundInky(aroundInky[15:0]),
    .aroundClyde(aroundClyde[15:0]),
    .aroundPac(aroundPac[15:0]),
    .partialScore(parcialScore[10:0]),
    .pacSpeedChange(pacSpeedChange[1:0]),
    .pacLifeChange(pacLifeChange[1:0]),
    .coinFlag(coinFlag),
    .powFlag(powFlag),
    .picUpFlag(picUpFlag),
    .fruitSpawnFlag(fruitSpawnFlag),
    .picUpTypeFlag(picUpTypeFlag[2:0]),
    .breakFlag(breakFlag),
    .placeBreakFlag(placeBreakFlag)
  );
  level inst (
    .clk(clk),
    .resetN(coreResetN),
    .level_key(level_keyQ),
    .isWin(isWin),
    .gameState(gameState[2:0]),
    .level(level[3:0]),
    .levelChange(levelChanged)
  );
  pacman_game_controller inst32 (
    .clk(clk),
    .resetN(coreResetN),
    .pauseN(pauseNQ),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .timerEnd(timerEnd),
    .isWin(isWin),
    .pacDR(PacmanDR),
    .wallsDR(MapDR),
    .coinDR(CoinsDR),
    .powerDR(powerDR),
    .blinkeyDR(BlinkyDR),
    .pinkeyDR(PinkyDR),
    .inkyDR(InkyDR),
    .clydeDR(ClydeDR),
    .partialScore(parcialScore[10:0]),
    .pacLifeChange(pacLifeChange[1:0]),
    .recovering(recovering),
    .levelChanged(levelChanged),
    .collision_pac_wall(collisionPacWall),
    .collision_pac_coin(collisionPacCoin),
    .collision_pac_power(collisionPacPow),
    .collision_pac_ghost(collisionPacGhost[2:0]),
    .ghostFlag(ghostFlag),
    .gameState(gameState[2:0]),
    .currLives(currLives[2:0]),
    .score0(Score0[3:0]),
    .score1(Score1[3:0]),
    .score2(Score2[3:0]),
    .datainL(datainL[3:0]),
    .datainH(datainH[3:0]),
    .startCountN(startCountN)
  );
  topCounters #(.CLK_HZ(CLK_HZ)) inst10 (
    .clk(clk),
    .resetN(coreResetN),
    .startN(startCountN),
    .pauseN(pauseNQ),
    .turbo(turboQ),
    .datainL(datainL[3:0]),
    .datainH(datainH[3:0]),
    .HEX0(),
    .HEX1(),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .oneSec(one_sec),
    .timerEnd(timerEnd)
  );
  assign MIF_VGA[7:0] = 1'b0;
  Ghost #(.initial_X(208), .initial_Y(192)) pinky (
    .clk(clk),
    .resetN(coreResetN),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .rnd(rnd[7:0]),
    .collisionPacGhost(collisionPacGhost[2:0]),
    .pixelX(scanX),
    .pixelY(scanY),
    .ghostSelect(SelectPinkey[1:0]),
    .aroundGhost(aroundPinky[15:0]),
    .pacmanX(pacmanX[10:0]),
    .pacmanY(pacmanY[10:0]),
    .pacmanDir(pacmanDir[1:0]),
    .gameState(gameState[2:0]),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .DR(PinkyDR),
    .RGB(PinkyRGB[7:0]),
    .topLeftX(PinkytopLeftX[10:0]),
    .topLeftY(PinkytopLeftY[10:0])
  );
  Ghost #(.initial_X(224), .initial_Y(160)) blinky (
    .clk(clk),
    .resetN(coreResetN),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .rnd(rnd[7:0]),
    .collisionPacGhost(collisionPacGhost[2:0]),
    .pixelX(scanX),
    .pixelY(scanY),
    .ghostSelect(SelectBlinkey[1:0]),
    .aroundGhost(aroundBlinky[15:0]),
    .pacmanX(pacmanX[10:0]),
    .pacmanY(pacmanY[10:0]),
    .pacmanDir(pacmanDir[1:0]),
    .gameState(gameState[2:0]),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .DR(BlinkyDR),
    .RGB(BlinkyRGB[7:0]),
    .topLeftX(BlinkytopLeftX[10:0]),
    .topLeftY(BlinkytopLeftY[10:0])
  );
  Ghost #(.initial_X(240), .initial_Y(192)) clyde (
    .clk(clk),
    .resetN(coreResetN),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .rnd(rnd[7:0]),
    .collisionPacGhost(collisionPacGhost[2:0]),
    .pixelX(scanX),
    .pixelY(scanY),
    .ghostSelect(SelectClyde[1:0]),
    .aroundGhost(aroundClyde[15:0]),
    .pacmanX(pacmanX[10:0]),
    .pacmanY(pacmanY[10:0]),
    .pacmanDir(pacmanDir[1:0]),
    .gameState(gameState[2:0]),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .DR(ClydeDR),
    .RGB(ClydeRGB[7:0]),
    .topLeftX(ClydetopLeftX[10:0]),
    .topLeftY(ClydetopLeftY[10:0])
  );
  Ghost #(.initial_X(224), .initial_Y(192)) inky (
    .clk(clk),
    .resetN(coreResetN),
    .startOfFrame(scanStartOfFrame),
    .oneSec(one_sec),
    .rnd(rnd[7:0]),
    .collisionPacGhost(collisionPacGhost[2:0]),
    .pixelX(scanX),
    .pixelY(scanY),
    .ghostSelect(SelectInky[1:0]),
    .aroundGhost(aroundInky[15:0]),
    .pacmanX(pacmanX[10:0]),
    .pacmanY(pacmanY[10:0]),
    .pacmanDir(pacmanDir[1:0]),
    .gameState(gameState[2:0]),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .DR(InkyDR),
    .RGB(InkyRGB[7:0]),
    .topLeftX(InkytopLeftX[10:0]),
    .topLeftY(InkytopLeftY[10:0])
  );
endmodule
