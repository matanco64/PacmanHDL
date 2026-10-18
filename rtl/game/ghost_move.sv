module ghost_move (
    input logic clk,
    input logic resetN,
    input logic startOfFrame,
    input logic oneSec,
    input logic [1:0] ghostSelect,
    input logic [15:0] aroundGhost,
    input logic [10:0] pacmanX,
    input logic [10:0] pacmanY,
    input logic [1:0] pacmanDir,
    input logic [2:0] collisionPacGhost,
    input logic [2:0] gameState,

    output logic signed [10:0] topLeftX,
    output logic signed [10:0] topLeftY,
    output logic        [ 1:0] ghostDir
);

  // Parameters
  parameter FIXED_POINT_MULTIPLIER = 16;
  parameter TILE_BITS = 4;
  parameter MOVEMENT_SPEED = 16;
  parameter TILE_PIXELS = 16;
  parameter SCREEN_HEIGHT = 480;
  parameter SCREEN_WIDTH = 640;

  parameter [TILE_BITS-1:0] EMPTY = 4'd0;
  parameter [TILE_BITS-1:0] WALL = 4'd2;
  parameter [TILE_BITS-1:0] GHOST_WALL = 4'd3;
  parameter [TILE_BITS-1:0] PORTAL = 4'd4;

  parameter [10:0] FRIGHTENED_TIME = 10'd8;  // 8 sec

  // Home positions
  parameter BLINKY_HOME_X = 464;
  parameter BLINKY_HOME_Y = 32;
  parameter PINKY_HOME_X = 0;
  parameter PINKY_HOME_Y = 32;
  parameter INKY_HOME_X = 480;
  parameter INKY_HOME_Y = 592;
  parameter CLYDE_HOME_X = 0;
  parameter CLYDE_HOME_Y = 592;
  parameter INITIAL_X = 280;
  parameter INITIAL_Y = 185;

  // Game states
  parameter RESET_ST = 3'b000;
  parameter START_WAIT_ST = 3'b001;
  parameter PLAYING_ST = 3'b010;
  parameter PAUSED_ST = 3'b011;
  parameter GHOST_HIT_ST = 3'b100;
  parameter WIN_ST = 3'b101;
  parameter LOSE_ST = 3'b110;
  parameter POWER_UP_ST = 3'b111;

  // Direction constants
  parameter [1:0] DIR_UP = 2'b00;
  parameter [1:0] DIR_DOWN = 2'b01;
  parameter [1:0] DIR_LEFT = 2'b10;
  parameter [1:0] DIR_RIGHT = 2'b11;

  // Mode durations (in seconds)
  parameter int SCATTER_DURATION = 7;
  parameter int CHASE_DURATION = 20;

  parameter int INTERNAL_DATA_BITS = 10 + 4; // position bits + fixed point bits

  // Internal signals
  logic signed [INTERNAL_DATA_BITS - 1:0] Xposition, Yposition;
  logic [1:0] lastDir;
  logic [7:0] modeTimer;
  logic [2:0] lastGameState;
  logic wasInFrightened;  // Track if we just entered frightened mode

  logic signed [INTERNAL_DATA_BITS - 1:0] targetX, targetY;
  logic [1:0] nextDir;
  logic [7:0] lfsr, lfsrAhead;
  logic [1:0] rnd;
  assign rnd = lfsr[1:0];

  // Junction and alignment detection
  logic isJunction;
  logic aligned_to_grid;

  logic signed [10:0] baseX, baseY, tileX, tileY;

  // Collision detection
  logic collidedAny, collidedThisGhost;
  assign collidedAny = (collisionPacGhost != 3'b000);
  assign collidedThisGhost = collidedAny && (collisionPacGhost - 3'b001 == ghostSelect);

  // Direction checking signals
  wire canMoveUp, canMoveDown, canMoveLeft, canMoveRight;
  assign canMoveUp = (!aligned_to_grid || aroundGhost[15:12] != WALL);
  assign canMoveDown = (!aligned_to_grid || (aroundGhost[11:8] != WALL && aroundGhost[11:8] != GHOST_WALL));
  assign canMoveLeft = (!aligned_to_grid || aroundGhost[7:4] != WALL);
  assign canMoveRight = (!aligned_to_grid || aroundGhost[3:0] != WALL);

  // State machines
  enum logic [1:0] {
    IDLE_ST,
    CHANGE_ST,
    MOVE_ST
  } SM_Motion;

  enum logic [2:0] {
    LEAVE_NEST_M,
    SCATTER_M,
    CHASE_M,
    FRIGHTENED_M
  } currMode;

  // ---------------------------------------------------------------------------
  // Functions
  // ---------------------------------------------------------------------------
  function automatic logic [1:0] opposite(input logic [1:0] dir);
    case (dir)
      DIR_UP:    opposite = DIR_DOWN;
      DIR_DOWN:  opposite = DIR_UP;
      DIR_LEFT:  opposite = DIR_RIGHT;
      DIR_RIGHT: opposite = DIR_LEFT;
    endcase
  endfunction

  function automatic signed [10:0] absDiff(input signed [10:0] a, input signed [10:0] b);
    absDiff = (a > b) ? (a - b) : (b - a);
  endfunction


  // Junction detection and Grid alignment
  always_comb begin
    isJunction = ((canMoveUp || canMoveDown) && (canMoveLeft || canMoveRight));
    // x % 256 == 0 is "low 8 bits zero" for any sign; written so to avoid a signed modulo
    aligned_to_grid = (Xposition[$clog2(TILE_PIXELS * FIXED_POINT_MULTIPLIER)-1:0] == 0) &&
                      (Yposition[$clog2(TILE_PIXELS * FIXED_POINT_MULTIPLIER)-1:0] == 0);
  end

  // ---------------------------------------------------------------------------
  // Home coordinates per ghost
  // ---------------------------------------------------------------------------
  logic signed [10:0] homeX, homeY;
  always_comb begin
    case (ghostSelect)
      2'd0: begin
        homeX = BLINKY_HOME_X;
        homeY = BLINKY_HOME_Y;
      end
      2'd1: begin
        homeX = PINKY_HOME_X;
        homeY = PINKY_HOME_Y;
      end
      2'd2: begin
        homeX = INKY_HOME_X;
        homeY = INKY_HOME_Y;
      end
      2'd3: begin
        homeX = CLYDE_HOME_X;
        homeY = CLYDE_HOME_Y;
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // Target calculation
  // ---------------------------------------------------------------------------
  always_comb begin
    // Clyde's scratch values, given a default so they don't infer latches
    // NOTE: distSq is 11 bits, so "distSq > 128*128" below is never true and
    // Clyde always targets his home corner (behaviour kept from the DE-10).
    logic signed [10:0] distSq, dx, dy;
    dx = '0;
    dy = '0;
    distSq = '0;

    targetX = Xposition / FIXED_POINT_MULTIPLIER;
    targetY = Yposition / FIXED_POINT_MULTIPLIER;

    case (currMode)
      LEAVE_NEST_M: begin
        targetX = Xposition / FIXED_POINT_MULTIPLIER;
        targetY = Yposition / FIXED_POINT_MULTIPLIER - TILE_PIXELS;
      end

      SCATTER_M: begin
        targetX = homeX;
        targetY = homeY;
      end

      CHASE_M: begin
        case (ghostSelect)
          2'd0: begin  // Blinky - direct chase
            targetX = pacmanX;
            targetY = pacmanY;
          end
          2'd1: begin  // Pinky - 4 tiles ahead
            case (pacmanDir)
              DIR_UP: begin
                targetX = pacmanX;
                targetY = pacmanY - 4 * TILE_PIXELS;
              end
              DIR_DOWN: begin
                targetX = pacmanX;
                targetY = pacmanY + 4 * TILE_PIXELS;
              end
              DIR_LEFT: begin
                targetX = pacmanX - 4 * TILE_PIXELS;
                targetY = pacmanY;
              end
              DIR_RIGHT: begin
                targetX = pacmanX + 4 * TILE_PIXELS;
                targetY = pacmanY;
              end
            endcase
          end
          2'd2: begin  // Inky - random offset
            targetX = pacmanX + (lfsrAhead[0] ? 2 * TILE_PIXELS : -2 * TILE_PIXELS);
            targetY = pacmanY + (lfsrAhead[1] ? 2 * TILE_PIXELS : -2 * TILE_PIXELS);
          end
          2'd3: begin  // Clyde - distance dependent
            dx = (Xposition / FIXED_POINT_MULTIPLIER) - pacmanX;
            dy = (Yposition / FIXED_POINT_MULTIPLIER) - pacmanY;
            distSq = (dx * dx) + (dy * dy);
            if (distSq > (128 * 128)) begin
              targetX = pacmanX;
              targetY = pacmanY;
            end else begin
              targetX = homeX;
              targetY = homeY;
            end
          end
        endcase
      end

      FRIGHTENED_M: begin
        // Random wandering - target doesn't matter
        targetX = Xposition / FIXED_POINT_MULTIPLIER;
        targetY = Yposition / FIXED_POINT_MULTIPLIER;
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // Chase/scatter direction, pipelined
  // ---------------------------------------------------------------------------
  // The choice is only used at startOfFrame, and positions, mode and Pac-Man
  // hold still for the clocks before it, so it is computed over PIPE_STAGES
  // registered steps instead of in one clock:
  //   1. target and the four neighbour tiles   2. per-axis distances
  //   3. Manhattan distance per direction      4. pairwise comparisons
  // Inky's random offset uses the LFSR value it will have when the result is
  // used (the LFSR steps every clock). Wall checks, lastDir and the tie-break
  // bits are cheap and stay current.
  localparam int PIPE_STAGES = 4;

  logic signed [10:0] tgtXQ, tgtYQ;
  logic signed [10:0] colXQ, leftXQ, rightXQ, rowYQ, upYQ, downYQ;
  logic signed [10:0] adColX, adLeftX, adRightX, adRowY, adUpY, adDownY;
  logic signed [INTERNAL_DATA_BITS - 1:0] manDist [4];  // indexed by direction
  logic [3:0] lt [4], le [4];  // lt[d][j]: manDist[d] < manDist[j], for j < d

  always_comb begin
    lfsrAhead = lfsr;
    for (int i = 0; i < PIPE_STAGES; i++)
      lfsrAhead = {lfsrAhead[6:0], lfsrAhead[7] ^ lfsrAhead[5] ^ lfsrAhead[4] ^ lfsrAhead[3]};
  end

  always_comb begin
    baseX = Xposition / FIXED_POINT_MULTIPLIER;
    baseY = Yposition / FIXED_POINT_MULTIPLIER;
    tileX = baseX / TILE_PIXELS;
    tileY = baseY / TILE_PIXELS;
  end

  always_ff @(posedge clk) begin
    tgtXQ   <= targetX[10:0];
    tgtYQ   <= targetY[10:0];
    colXQ   <= tileX * TILE_PIXELS;
    leftXQ  <= (tileX - 1) * TILE_PIXELS;
    rightXQ <= (tileX + 1) * TILE_PIXELS;
    rowYQ   <= tileY * TILE_PIXELS;
    upYQ    <= (tileY - 1) * TILE_PIXELS;
    downYQ  <= (tileY + 1) * TILE_PIXELS;

    adColX   <= absDiff(colXQ, tgtXQ);
    adLeftX  <= absDiff(leftXQ, tgtXQ);
    adRightX <= absDiff(rightXQ, tgtXQ);
    adRowY   <= absDiff(rowYQ, tgtYQ);
    adUpY    <= absDiff(upYQ, tgtYQ);
    adDownY  <= absDiff(downYQ, tgtYQ);

    manDist[DIR_UP]    <= adColX + adUpY;
    manDist[DIR_DOWN]  <= adColX + adDownY;
    manDist[DIR_LEFT]  <= adLeftX + adRowY;
    manDist[DIR_RIGHT] <= adRightX + adRowY;

    for (int d = 0; d < 4; d++)
      for (int j = 0; j < 4; j++) begin
        lt[d][j] <= (manDist[d] < manDist[j]);
        le[d][j] <= (manDist[d] <= manDist[j]);
      end
  end

  // ---------------------------------------------------------------------------
  // Direction selection
  // ---------------------------------------------------------------------------
  always_comb begin
    // Chase/scatter: visit Up, Down, Left, Right in order; an allowed direction
    // wins if it is strictly closer than every allowed one before it, or ties
    // the closest so far and its LFSR bit is set. Same result as the original
    // running-minimum loop, written so it only needs the registered compares.
    logic [3:0] allowed;
    logic [1:0] bestDir;
    logic       ltAll, leAll;
    allowed = {canMoveRight && DIR_RIGHT != opposite(lastDir),
               canMoveLeft  && DIR_LEFT  != opposite(lastDir),
               canMoveDown  && DIR_DOWN  != opposite(lastDir),
               canMoveUp    && DIR_UP    != opposite(lastDir)};
    bestDir = lastDir;

    nextDir = ghostDir;

    if (currMode == FRIGHTENED_M) begin
      // Random direction in frightened mode
      case (rnd)
        2'b00: begin
          if (canMoveUp && DIR_UP != opposite(ghostDir)) nextDir = DIR_UP;
          else if (canMoveDown && DIR_DOWN != opposite(ghostDir)) nextDir = DIR_DOWN;
          else if (canMoveLeft && DIR_LEFT != opposite(ghostDir)) nextDir = DIR_LEFT;
          else if (canMoveRight && DIR_RIGHT != opposite(ghostDir)) nextDir = DIR_RIGHT;
          else  nextDir = opposite(ghostDir);
        end
        2'b01: begin
          if (canMoveDown && DIR_DOWN != opposite(ghostDir)) nextDir = DIR_DOWN;
          else if (canMoveLeft && DIR_LEFT != opposite(ghostDir)) nextDir = DIR_LEFT;
          else if (canMoveRight && DIR_RIGHT != opposite(ghostDir)) nextDir = DIR_RIGHT;
          else if (canMoveUp && DIR_UP != opposite(ghostDir)) nextDir = DIR_UP;
          else  nextDir = opposite(ghostDir);
        end
        2'b10: begin
          if (canMoveLeft && DIR_LEFT != opposite(ghostDir)) nextDir = DIR_LEFT;
          else if (canMoveRight && DIR_RIGHT != opposite(ghostDir)) nextDir = DIR_RIGHT;
          else if (canMoveUp && DIR_UP != opposite(ghostDir)) nextDir = DIR_UP;
          else if (canMoveDown && DIR_DOWN != opposite(ghostDir)) nextDir = DIR_DOWN;
          else  nextDir = opposite(ghostDir);
        end
        2'b11: begin
          if (canMoveRight && DIR_RIGHT != opposite(ghostDir)) nextDir = DIR_RIGHT;
          else if (canMoveUp && DIR_UP != opposite(ghostDir)) nextDir = DIR_UP;
          else if (canMoveDown && DIR_DOWN != opposite(ghostDir)) nextDir = DIR_DOWN;
          else if (canMoveLeft && DIR_LEFT != opposite(ghostDir)) nextDir = DIR_LEFT;
          else  nextDir = opposite(ghostDir);
        end
      endcase
    end else begin
      for (int d = 0; d < 4; d++) begin
        ltAll = 1'b1;
        leAll = 1'b1;
        for (int j = 0; j < d; j++)
          if (allowed[j]) begin
            ltAll &= lt[d][j];
            leAll &= le[d][j];
          end
        if (allowed[d] && (ltAll || (leAll && lfsr[d]))) bestDir = 2'(d);
      end

      // If no better direction found, turn back (dead end)
      if (bestDir == lastDir) bestDir = opposite(lastDir);

      nextDir = bestDir;
    end
  end

  // ---------------------------------------------------------------------------
  // LFSR for randomness
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetN) lfsr <= 8'hB1;
    else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  end

  // ---------------------------------------------------------------------------
  // Main state machine
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!resetN) begin
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      ghostDir <= DIR_UP;
      lastDir <= DIR_UP;
      SM_Motion <= IDLE_ST;
      currMode <= LEAVE_NEST_M;
      modeTimer <= 0;
      lastGameState <= RESET_ST;
      wasInFrightened <= 1'b0;
    end else if (gameState == RESET_ST) begin
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      ghostDir <= DIR_UP;
      lastDir <= DIR_UP;
      SM_Motion <= IDLE_ST;
      currMode <= LEAVE_NEST_M;
      modeTimer <= 0;
      lastGameState <= RESET_ST;
      wasInFrightened <= 1'b0;
    end else begin

      // Track game state transitions
      lastGameState <= gameState;

      // ========================================================================
      // GAME STATE CONTROL (Highest Priority)
      // ========================================================================
      case (gameState)
        RESET_ST, WIN_ST, LOSE_ST: begin
          Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
          Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
          ghostDir <= DIR_UP;
          lastDir <= DIR_UP;
          SM_Motion <= IDLE_ST;
          currMode <= LEAVE_NEST_M;
          modeTimer <= 0;
          wasInFrightened <= 1'b0;
        end

        START_WAIT_ST, PAUSED_ST: begin
          SM_Motion <= IDLE_ST;
        end

        GHOST_HIT_ST: begin
          // All ghosts return to nest
          Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
          Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
          ghostDir <= DIR_UP;
          lastDir <= DIR_UP;
          SM_Motion <= IDLE_ST;
          currMode <= LEAVE_NEST_M;
          modeTimer <= rnd;
          wasInFrightened <= 1'b0;
        end

        POWER_UP_ST: begin
          // Transition to frightened mode for all ghosts
          if (lastGameState != POWER_UP_ST) begin
            // Just entered power mode - reverse direction
            currMode <= FRIGHTENED_M;
            wasInFrightened <= 1'b0;  // Will trigger reverse on next frame
          end

          // Handle collision - only this ghost returns
          if (collidedThisGhost) begin
            Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
            Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
            Yposition <= (ghostSelect == 2'd0) ? (INITIAL_Y + 2* TILE_PIXELS) * FIXED_POINT_MULTIPLIER : INITIAL_Y * FIXED_POINT_MULTIPLIER;
            ghostDir <= DIR_UP;
            lastDir <= DIR_UP;
            SM_Motion <= IDLE_ST;
            currMode <= LEAVE_NEST_M;
            modeTimer <= rnd;
          end
        end

        PLAYING_ST: begin
          if (lastGameState == POWER_UP_ST) begin
            currMode <= CHASE_M;
            SM_Motion <= CHANGE_ST;  // NEW ADDITION- BECAUSE GHOSTS GOT STUCK AFTER FRIGHTENED
            modeTimer <= CHASE_DURATION;
            wasInFrightened <= 1'b0;
          end
        end

      endcase

      // ========================================================================
      // MODE STATE MACHINE (only runs during PLAYING or POWER_UP)
      // ========================================================================
      if (gameState == PLAYING_ST || gameState == POWER_UP_ST) begin

        // Decrement timers
        if (oneSec) begin
          if (modeTimer > 0) modeTimer <= modeTimer - 1;
        end

        case (currMode)
          LEAVE_NEST_M: begin
            // Check if ghost passed the ghost wall (moved down through it)
            if (aroundGhost[11:8] == GHOST_WALL && modeTimer == 0) begin // after eaten there will be a rnd deley
              currMode  <= CHASE_M;
              modeTimer <= CHASE_DURATION;
            end
          end

          SCATTER_M: begin
            if (modeTimer == 0) begin
              currMode  <= CHASE_M;
              modeTimer <= CHASE_DURATION;
            end
          end

          CHASE_M: begin
            if (modeTimer == 0) begin
              currMode  <= SCATTER_M;
              modeTimer <= SCATTER_DURATION;
            end
          end

          FRIGHTENED_M: begin
            // Frightened mode ends when timer expires or game exits POWER_UP_ST
            if (gameState != POWER_UP_ST) begin
              currMode  <= CHASE_M;
              modeTimer <= CHASE_DURATION;
            end
          end
        endcase
      end

      // ========================================================================
      // MOTION STATE MACHINE (only runs during PLAYING or POWER_UP)
      // ========================================================================
      if (gameState == PLAYING_ST || gameState == POWER_UP_ST) begin
        case (SM_Motion)
          IDLE_ST: begin
            if (startOfFrame) begin
              if (currMode != LEAVE_NEST_M || modeTimer == 0)  // delay for leaving the nest
                SM_Motion <= CHANGE_ST;
            end
          end

          CHANGE_ST: begin
            if (startOfFrame) begin
              // Reverse direction when entering FRIGHTENED mode
              if (currMode == FRIGHTENED_M && !wasInFrightened) begin
                ghostDir <= opposite(ghostDir);
                lastDir <= opposite(ghostDir);
                wasInFrightened <= 1'b1;
              end else begin
                // Normal direction change logic
                if (aligned_to_grid) begin
                  case (ghostDir)
                    DIR_UP: begin
                      if (aroundGhost[15:12] == PORTAL) begin
                        Yposition <= (SCREEN_HEIGHT - 2 * TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
                      end else if (!canMoveUp || isJunction) begin
                        lastDir  <= ghostDir;
                        ghostDir <= nextDir;
                      end
                    end
                    DIR_DOWN: begin
                      if (aroundGhost[11:8] == PORTAL) begin
                        Yposition <= (2 * TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
                      end else if (!canMoveDown || isJunction) begin
                        lastDir  <= ghostDir;
                        ghostDir <= nextDir;
                      end
                    end
                    DIR_LEFT: begin
                      if (!canMoveLeft || isJunction) begin
                        lastDir  <= ghostDir;
                        ghostDir <= nextDir;
                      end
                    end
                    DIR_RIGHT: begin
                      if (!canMoveRight || isJunction) begin
                        lastDir  <= ghostDir;
                        ghostDir <= nextDir;
                      end
                    end
                  endcase
                end
              end
              SM_Motion <= MOVE_ST;
            end
          end

          MOVE_ST: begin
            case (ghostDir)
                DIR_UP:    if (canMoveUp) Yposition <= Yposition - MOVEMENT_SPEED;
                DIR_DOWN:  if (canMoveDown) Yposition <= Yposition + MOVEMENT_SPEED;
                DIR_LEFT:  if (canMoveLeft) Xposition <= Xposition - MOVEMENT_SPEED;
                DIR_RIGHT: if (canMoveRight) Xposition <= Xposition + MOVEMENT_SPEED;
            endcase
            SM_Motion <= CHANGE_ST;
          end
        endcase
      end
    end
  end

  // Outputs
  // Registered: positions only change at startOfFrame (vertical blanking), so
  // one clock of delay is invisible, and it keeps the signed divide off the
  // long timing paths into the tile-neighbour and collision logic.
  always_ff @(posedge clk)
    if (!resetN) begin
      topLeftX <= INITIAL_X;
      topLeftY <= INITIAL_Y;
    end else begin
      topLeftX <= Xposition / FIXED_POINT_MULTIPLIER;  // note it must be 2^n
      topLeftY <= Yposition / FIXED_POINT_MULTIPLIER;
    end

endmodule
