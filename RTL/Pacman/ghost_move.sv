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
  parameter MOVEMENT_SPEED = 32;
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

  // Internal signals
  reg signed [31:0] Xposition, Yposition;
  reg [1:0] lastDir;
  reg [7:0] modeTimer;
  reg [2:0] lastGameState;
  reg wasInFrightened;  // Track if we just entered frightened mode

  reg signed [31:0] targetX, targetY;
  reg signed [31:0] distUp, distDown, distLeft, distRight;
  reg  [1:0] nextDir;
  reg  [7:0] lfsr;
  wire [1:0] rnd;
  assign rnd = lfsr[1:0];

  // Junction and alignment detection
  wire isJunction = ((canMoveUp || canMoveDown) && (canMoveLeft || canMoveRight));
  wire aligned_to_grid = (Xposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER) == 0) &&
                         (Yposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER) == 0);

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
    FRIGHTENED_M,
    EATEN_M
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

  function automatic signed [31:0] absDiff(input signed [31:0] a, input signed [31:0] b);
    absDiff = (a > b) ? (a - b) : (b - a);
  endfunction

  // ---------------------------------------------------------------------------
  // Home coordinates per ghost
  // ---------------------------------------------------------------------------
  reg signed [31:0] homeX, homeY;
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
            targetX = pacmanX + (rnd[0] ? 2 * TILE_PIXELS : -2 * TILE_PIXELS);
            targetY = pacmanY + (rnd[1] ? 2 * TILE_PIXELS : -2 * TILE_PIXELS);
          end
          2'd3: begin  // Clyde - distance dependent
            reg signed [31:0] distSq, dx, dy;
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

      EATEN_M: begin
        targetX = INITIAL_X;
        targetY = INITIAL_Y;
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // Distance calculation (Manhattan distance)
  // ---------------------------------------------------------------------------
  always_comb begin
    logic signed [31:0] baseX, baseY, tileX, tileY;
    logic signed [31:0] newX_up, newY_up, newX_down, newY_down;
    logic signed [31:0] newX_left, newY_left, newX_right, newY_right;

    baseX = Xposition / FIXED_POINT_MULTIPLIER;
    baseY = Yposition / FIXED_POINT_MULTIPLIER;
    tileX = baseX / TILE_PIXELS;
    tileY = baseY / TILE_PIXELS;

    newX_up = tileX * TILE_PIXELS;
    newY_up = (tileY - 1) * TILE_PIXELS;
    newX_down = tileX * TILE_PIXELS;
    newY_down = (tileY + 1) * TILE_PIXELS;
    newX_left = (tileX - 1) * TILE_PIXELS;
    newY_left = tileY * TILE_PIXELS;
    newX_right = (tileX + 1) * TILE_PIXELS;
    newY_right = tileY * TILE_PIXELS;

    distUp = absDiff(newX_up, targetX) + absDiff(newY_up, targetY);
    distDown = absDiff(newX_down, targetX) + absDiff(newY_down, targetY);
    distLeft = absDiff(newX_left, targetX) + absDiff(newY_left, targetY);
    distRight = absDiff(newX_right, targetX) + absDiff(newY_right, targetY);
  end

  // ---------------------------------------------------------------------------
  // Direction selection
  // ---------------------------------------------------------------------------
  always_comb begin
    int minDist;
    int bestDir;

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
      // Chase/Scatter/Eaten - best direction toward target
      minDist = 32'h7FFFFFFF;
      bestDir = lastDir;

      // Check all possible directions and pick the closest one
      if (canMoveUp && DIR_UP != opposite(lastDir)) begin
        if (distUp < minDist) begin
          minDist = distUp;
          bestDir = DIR_UP;
        end else if (distUp == minDist && lfsr[0]) begin
          bestDir = DIR_UP;  // Random tie-break
        end
      end

      if (canMoveDown && DIR_DOWN != opposite(lastDir)) begin
        if (distDown < minDist) begin
          minDist = distDown;
          bestDir = DIR_DOWN;
        end else if (distDown == minDist && lfsr[1]) begin
          bestDir = DIR_DOWN;
        end
      end

      if (canMoveLeft && DIR_LEFT != opposite(lastDir)) begin
        if (distLeft < minDist) begin
          minDist = distLeft;
          bestDir = DIR_LEFT;
        end else if (distLeft == minDist && lfsr[2]) begin
          bestDir = DIR_LEFT;
        end
      end

      if (canMoveRight && DIR_RIGHT != opposite(lastDir)) begin
        if (distRight < minDist) begin
          minDist = distRight;
          bestDir = DIR_RIGHT;
        end else if (distRight == minDist && lfsr[3]) begin
          bestDir = DIR_RIGHT;
        end
      end

      // If no better direction found, turn back (dead end)
      if (bestDir == lastDir) bestDir = opposite(lastDir);

      nextDir = bestDir;

    end
  end

  // ---------------------------------------------------------------------------
  // LFSR for randomness
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) lfsr <= 8'hB1;
    else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  end

  // ---------------------------------------------------------------------------
  // Main state machine
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge resetN) begin
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

          EATEN_M: begin
            // Return to nest, then leave
            if (absDiff(
                    Xposition / FIXED_POINT_MULTIPLIER, INITIAL_X
                ) < TILE_PIXELS && absDiff(
                    Yposition / FIXED_POINT_MULTIPLIER, INITIAL_Y
                ) < TILE_PIXELS) begin
              currMode  <= LEAVE_NEST_M;
              modeTimer <= rnd;
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
            if (startOfFrame) begin
              case (ghostDir)
                DIR_UP:    if (canMoveUp) Yposition <= Yposition - MOVEMENT_SPEED;
                DIR_DOWN:  if (canMoveDown) Yposition <= Yposition + MOVEMENT_SPEED;
                DIR_LEFT:  if (canMoveLeft) Xposition <= Xposition - MOVEMENT_SPEED;
                DIR_RIGHT: if (canMoveRight) Xposition <= Xposition + MOVEMENT_SPEED;
              endcase
              SM_Motion <= CHANGE_ST;
            end
          end
        endcase
      end
    end
  end

  // Outputs
  assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;
  assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

endmodule
