module ghost_move (
    input logic clk,
    input logic resetN,
    input logic startOfFrame,
    input logic [1:0] ghostSelect,
    input logic [11:0] aroundGhost,
    input logic [10:0] pacmanX,
    input logic [10:0] pacmanY,
    input logic [1:0] pacmanDir,
    input logic [1:0] forceMode,          // External mode control: 00=unused, 01=unused, 10=Frightened, 11=EATEN_MODE
    input logic [7:0] gameTimer,  // Currently unused - for future timing features
    input logic [7:0] gameState,  // Currently unused - for future game state - start, play, pause, turbo, game over

    output logic signed [10:0] topLeftX,
    output logic signed [10:0] topLeftY
);
  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  parameter FIXED_POINT_MULTIPLIER = 16;
  parameter TILE_BITS = 3;
  parameter MOVEMENT_SPEED = 16;
  parameter TILE_PIXELS = 16;
  parameter SAFETY_MARGIN = 16;

  parameter [TILE_BITS-1:0] WALL = 3'd2;
  parameter [TILE_BITS-1:0] EMPTY = 3'd0;

  // Screen boundaries
  parameter X_FRAME_LEFT = (SAFETY_MARGIN) * FIXED_POINT_MULTIPLIER;
  parameter X_FRAME_RIGHT = (640 - SAFETY_MARGIN - TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
  parameter Y_FRAME_TOP = (SAFETY_MARGIN) * FIXED_POINT_MULTIPLIER;
  parameter Y_FRAME_BOTTOM = (480 - SAFETY_MARGIN - TILE_PIXELS) * FIXED_POINT_MULTIPLIER;

  // Home positions
  parameter BLINKY_HOME_X = 480;
  parameter BLINKY_HOME_Y = 48;
  parameter PINKY_HOME_X = 32;
  parameter PINKY_HOME_Y = 48;
  parameter INKY_HOME_X = 480;
  parameter INKY_HOME_Y = 592;
  parameter CLYDE_HOME_X = 32;
  parameter CLYDE_HOME_Y = 592;

  parameter INITIAL_X = 280;
  parameter INITIAL_Y = 185;

  // ---------------------------------------------------------------------------
  // Direction and Mode definitions (using parameters for Quartus compatibility)
  // ---------------------------------------------------------------------------
  parameter [1:0] DIR_UP = 2'b00;
  parameter [1:0] DIR_DOWN = 2'b01;
  parameter [1:0] DIR_LEFT = 2'b10;
  parameter [1:0] DIR_RIGHT = 2'b11;

  parameter [1:0] SCATTER_MODE = 2'b00;
  parameter [1:0] CHASE_MODE = 2'b01;
  parameter [1:0] FRIGHTENED = 2'b10;
  parameter [1:0] EATEN_MODE = 2'b11;

  // ---------------------------------------------------------------------------
  // Internal signals
  // ---------------------------------------------------------------------------
  reg signed [31:0] Xposition, Yposition;
  reg [1:0] ghostDir, lastDir;
  reg [1:0] currentMode;
  reg [7:0] modeTimer;
  reg [7:0] frightenedTimer;

  reg signed [31:0] targetX, targetY;

  // distances
  reg signed [31:0] distUp, distDown, distLeft, distRight;
  reg  [1:0] nextDir;

  // Random generator
  reg  [7:0] lfsr;
  wire [1:0] rnd;
  assign rnd = lfsr[1:0];

  // junction detection
  wire isJunction;
  assign isJunction = ((canMoveUp || canMoveDown) && (canMoveLeft || canMoveRight));
  wire aligned_to_grid;
  assign aligned_to_grid = (Xposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER) == 0) &&
                         (Yposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER) == 0);


  // Direction checking signals
  wire canMoveUp, canMoveDown, canMoveLeft, canMoveRight;

  assign canMoveUp    = (!aligned_to_grid || aroundGhost[11:9] != WALL); // NEED TO ADD SAFETY CHECKS FOR SCREEN EDGES
  assign canMoveDown = (!aligned_to_grid || aroundGhost[8:6] != WALL);
  assign canMoveLeft = (!aligned_to_grid || aroundGhost[5:3] != WALL);
  assign canMoveRight = (!aligned_to_grid || aroundGhost[2:0] != WALL);

  // ---------------------------------------------------------------------------
  // functions
  // ---------------------------------------------------------------------------

  // Opposite direction mapping
  function automatic logic [1:0] opposite(input logic [1:0] dir);
    case (dir)
      DIR_UP:    opposite = DIR_DOWN;
      DIR_DOWN:  opposite = DIR_UP;
      DIR_LEFT:  opposite = DIR_RIGHT;
      DIR_RIGHT: opposite = DIR_LEFT;
      default:   opposite = DIR_UP; // or safe fallback
    endcase
  endfunction

  function automatic [10:0] absDiff(input signed [10:0] a, b);
    absDiff = (a > b) ? (a - b) : (b - a);
  endfunction
  // ---------------------------------------------------------------------------
  // always_comb blocks
  // ---------------------------------------------------------------------------

  // Home coordinates for current ghost
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

  // Calculate target position based on mode and ghost type
  always_comb begin
    case (currentMode)
      SCATTER_MODE: begin
        targetX = homeX;
        targetY = homeY;
      end

      CHASE_MODE: begin
        case (ghostSelect)
          2'd0: begin  // Blinky - direct chase
            targetX = pacmanX;
            targetY = pacmanY;
          end
          2'd1: begin  // Pinky - 4 tiles ahead of Pacman's direction
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
              default: begin  // If no direction, just chase directly
                targetX = pacmanX;
                targetY = pacmanY;
              end
            endcase
          end
          2'd2: begin  // Inky - with randomness - easy version
            targetX = pacmanX + (rnd[0] ? 2 * TILE_PIXELS : -2 * TILE_PIXELS);
            targetY = pacmanY + (rnd[1] ? 2 * TILE_PIXELS : -2 * TILE_PIXELS);
          end
          2'd3: begin  // Clyde - distance dependent
            reg signed [31:0] distSq;
            reg signed [31:0] dx, dy;
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

      FRIGHTENED: begin
        targetX = Xposition / FIXED_POINT_MULTIPLIER;
        targetY = Yposition / FIXED_POINT_MULTIPLIER;
      end

      EATEN_MODE: begin
        targetX = INITIAL_X;
        targetY = INITIAL_Y;
      end
    endcase
  end

  // Calculate potential new positions and their distances to target
  always_comb begin
    logic signed [31:0] newX_up, newY_up, newX_down, newY_down, baseX, baseY;
    logic signed [31:0] newX_left, newY_left, newX_right, newY_right;

    // Normalize positions
    baseX = Xposition / FIXED_POINT_MULTIPLIER;
    baseY = Yposition / FIXED_POINT_MULTIPLIER;

    // New positions
    newX_up    = baseX;
    newY_up    = (Yposition - MOVEMENT_SPEED) / FIXED_POINT_MULTIPLIER;

    newX_down  = baseX;
    newY_down  = (Yposition + MOVEMENT_SPEED) / FIXED_POINT_MULTIPLIER;

    newX_left  = (Xposition - MOVEMENT_SPEED) / FIXED_POINT_MULTIPLIER;
    newY_left  = baseY;

    newX_right = (Xposition + MOVEMENT_SPEED) / FIXED_POINT_MULTIPLIER;
    newY_right = baseY;

    // Manhattan distance calculations
    distUp    = absDiff(newX_up,    targetX) + absDiff(newY_up,    targetY);
    distDown  = absDiff(newX_down,  targetX) + absDiff(newY_down,  targetY);
    distLeft  = absDiff(newX_left,  targetX) + absDiff(newY_left,  targetY);
    distRight = absDiff(newX_right, targetX) + absDiff(newY_right, targetY);
  end



  logic [1:0] dirPriority[3:0][3:0];  // 4 cases, each with 4 direction values
  // Define direction priority for each rnd value
  initial begin
    dirPriority[2'b00] = '{DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT};
    dirPriority[2'b01] = '{DIR_DOWN, DIR_LEFT, DIR_RIGHT, DIR_UP};
    dirPriority[2'b10] = '{DIR_LEFT, DIR_RIGHT, DIR_UP, DIR_DOWN};
    dirPriority[2'b11] = '{DIR_RIGHT, DIR_UP, DIR_DOWN, DIR_LEFT};
  end

  // Choose best direction
  always_comb begin
    int minDist;  // Max int
    int bestDir;  // Default fallback
    minDist = 32'h7FFFFFFF;  // Max int
    bestDir = lastDir;  // Default fallback

    nextDir = ghostDir;

    if (currentMode == FRIGHTENED) begin  // Random direction - frightened mode - the code is long for quartus compatibility
      case (rnd)
        2'b00:
        if (canMoveUp && (DIR_UP != opposite(ghostDir))) nextDir = DIR_UP;
        else if (canMoveDown && (DIR_DOWN != opposite(ghostDir))) nextDir = DIR_DOWN;
        else if (canMoveLeft && (DIR_LEFT != opposite(ghostDir))) nextDir = DIR_LEFT;
        else if (canMoveRight && (DIR_RIGHT != opposite(ghostDir))) nextDir = DIR_RIGHT;
        2'b01:
        if (canMoveDown && (DIR_DOWN != opposite(ghostDir))) nextDir = DIR_DOWN;
        else if (canMoveLeft && (DIR_LEFT != opposite(ghostDir))) nextDir = DIR_LEFT;
        else if (canMoveRight && (DIR_RIGHT != opposite(ghostDir))) nextDir = DIR_RIGHT;
        else if (canMoveUp && (DIR_UP != opposite(ghostDir))) nextDir = DIR_UP;
        2'b10:
        if (canMoveLeft && (DIR_LEFT != opposite(ghostDir))) nextDir = DIR_LEFT;
        else if (canMoveRight && (DIR_RIGHT != opposite(ghostDir))) nextDir = DIR_RIGHT;
        else if (canMoveUp && (DIR_UP != opposite(ghostDir))) nextDir = DIR_UP;
        else if (canMoveDown && (DIR_DOWN != opposite(ghostDir))) nextDir = DIR_DOWN;
        2'b11:
        if (canMoveRight && (DIR_RIGHT != opposite(ghostDir))) nextDir = DIR_RIGHT;
        else if (canMoveUp && (DIR_UP != opposite(ghostDir))) nextDir = DIR_UP;
        else if (canMoveDown && (DIR_DOWN != opposite(ghostDir))) nextDir = DIR_DOWN;
        else if (canMoveLeft && (DIR_LEFT != opposite(ghostDir))) nextDir = DIR_LEFT;
      endcase

    end else begin

      if (canMoveUp && DIR_UP != opposite(lastDir) && distUp < minDist) begin
        minDist = distUp;
        bestDir = DIR_UP;
      end
      if (canMoveDown && DIR_DOWN != opposite(lastDir) && distDown < minDist) begin
        minDist = distDown;
        bestDir = DIR_DOWN;
      end
      if (canMoveLeft && DIR_LEFT != opposite(lastDir) && distLeft < minDist) begin
        minDist = distLeft;
        bestDir = DIR_LEFT;
      end
      if (canMoveRight && DIR_RIGHT != opposite(lastDir) && distRight < minDist) begin
        minDist = distRight;
        bestDir = DIR_RIGHT;
      end
      nextDir = bestDir;


      // Best direction based on distance to target & avoiding U-turns - chase/scatter/eaten modes
      // if (canMoveUp && (distUp <= distDown) && (distUp <= distLeft) && (distUp <= distRight) && (DIR_UP != opposite(
      //         lastDir
      //     )))
      //   nextDir = DIR_UP;
      // else if (canMoveDown && (distDown <= distUp) && (distDown <= distLeft) && (distDown <= distRight) && (DIR_DOWN != opposite(
      //         lastDir
      //     )))
      //   nextDir = DIR_DOWN;
      // else if (canMoveLeft && (distLeft <= distUp) && (distLeft <= distDown) && (distLeft <= distRight) && (DIR_LEFT != opposite(
      //         lastDir
      //     )))
      //   nextDir = DIR_LEFT;
      // else if (canMoveRight && (distRight <= distUp) && (distRight <= distDown) && (distRight <= distLeft) && (DIR_RIGHT != opposite(
      //         lastDir
      //     )))
      //   nextDir = DIR_RIGHT;
      // // Fallback - try any valid direction
      // else if (canMoveUp && (DIR_UP != opposite(lastDir))) nextDir = DIR_UP;
      // else if (canMoveDown && (DIR_DOWN != opposite(lastDir))) nextDir = DIR_DOWN;
      // else if (canMoveLeft && (DIR_LEFT != opposite(lastDir))) nextDir = DIR_LEFT;
      // else if (canMoveRight && (DIR_RIGHT != opposite(lastDir))) nextDir = DIR_RIGHT;

    end
  end

  // Random number generator
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) lfsr <= 8'b10110001;
    else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  end


  enum logic [2:0] {
    IDLE_ST,    // initial state
    CHANGE_ST,
    MOVE_ST
  } SM_Motion;

  // Main state machine
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      SM_Motion <= IDLE_ST;

    end else begin
      case (SM_Motion)
        IDLE_ST: begin
          Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
          Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
          ghostDir <= DIR_LEFT;
          lastDir <= DIR_LEFT;
          currentMode <= CHASE_MODE;  // should start in scatter mode, but for simplicity start in chase
          modeTimer <= 8'd90;
          frightenedTimer <= 8'd0;

          if (startOfFrame) SM_Motion <= CHANGE_ST;
        end
        CHANGE_ST: begin
          if (startOfFrame) begin
            // Direction changes at junctions or when stuck
            if (aligned_to_grid) begin
              // Check if we can move in current direction
              case (ghostDir)
                DIR_UP:
                if (!canMoveUp || isJunction) begin
                  lastDir  <= ghostDir;
                  ghostDir <= nextDir;
                end
                DIR_DOWN:
                if (!canMoveDown || isJunction) begin
                  lastDir  <= ghostDir;
                  ghostDir <= nextDir;
                end
                DIR_LEFT:
                if (!canMoveLeft || isJunction) begin
                  lastDir  <= ghostDir;
                  ghostDir <= nextDir;
                end
                DIR_RIGHT:
                if (!canMoveRight || isJunction) begin
                  lastDir  <= ghostDir;
                  ghostDir <= nextDir;
                end
              endcase
            end
            SM_Motion <= MOVE_ST;
          end
        end

        MOVE_ST: begin
          if (startOfFrame) begin
            // Execute movement
            case (ghostDir)
              DIR_UP: if (canMoveUp) Yposition <= Yposition - MOVEMENT_SPEED;
              DIR_DOWN: if (canMoveDown) Yposition <= Yposition + MOVEMENT_SPEED;
              DIR_LEFT: if (canMoveLeft) Xposition <= Xposition - MOVEMENT_SPEED;
              DIR_RIGHT: if (canMoveRight) Xposition <= Xposition + MOVEMENT_SPEED;
            endcase
            SM_Motion <= CHANGE_ST;
          end
        end


      endcase

      // end else if (startOfFrame) begin

      //   // // Update timers
      //   // if (modeTimer > 0) modeTimer <= modeTimer - 1;
      //   // if (frightenedTimer > 0) frightenedTimer <= frightenedTimer - 1;

      //   // // Mode management
      //   // if (forceMode == FRIGHTENED && currentMode != FRIGHTENED && currentMode != EATEN_MODE) begin
      //   //   currentMode <= FRIGHTENED;
      //   //   frightenedTimer <= 8'd240;
      //   //   // Reverse direction
      //   //   case (ghostDir)
      //   //     DIR_UP: ghostDir <= DIR_DOWN;
      //   //     DIR_DOWN: ghostDir <= DIR_UP;
      //   //     DIR_LEFT: ghostDir <= DIR_RIGHT;
      //   //     DIR_RIGHT: ghostDir <= DIR_LEFT;
      //   //   endcase
      //   // end else if (frightenedTimer == 8'd0 && currentMode == FRIGHTENED) begin
      //   //   currentMode <= CHASE_MODE;
      //   //   modeTimer   <= 8'd150;
      //   // end else if (currentMode != FRIGHTENED && currentMode != EATEN_MODE) begin
      //   //   if (modeTimer == 8'd0) begin
      //   //     if (currentMode == SCATTER_MODE) begin
      //   //       currentMode <= CHASE_MODE;
      //   //       modeTimer   <= 8'd150;
      //   //     end else begin
      //   //       currentMode <= SCATTER_MODE;
      //   //       modeTimer   <= 8'd90;
      //   //     end
      //   //   end
      //   // end

      //   // Direction changes at junctions or when stuck
      //   if (aligned_to_grid) begin
      //     // Check if we can move in current direction
      //     case (ghostDir)
      //       DIR_UP:
      //       if (!canMoveUp || isJunction) begin
      //         lastDir  <= ghostDir;
      //         ghostDir <= nextDir;
      //       end
      //       DIR_DOWN:
      //       if (!canMoveDown || isJunction) begin
      //         lastDir  <= ghostDir;
      //         ghostDir <= nextDir;
      //       end
      //       DIR_LEFT:
      //       if (!canMoveLeft || isJunction) begin
      //         lastDir  <= ghostDir;
      //         ghostDir <= nextDir;
      //       end
      //       DIR_RIGHT:
      //       if (!canMoveRight || isJunction) begin
      //         lastDir  <= ghostDir;
      //         ghostDir <= nextDir;
      //       end
      //     endcase
      //   end

      //   // Execute movement
      //   case (ghostDir)
      //     DIR_UP: if (canMoveUp) Yposition <= Yposition - MOVEMENT_SPEED;
      //     DIR_DOWN: if (canMoveDown) Yposition <= Yposition + MOVEMENT_SPEED;
      //     DIR_LEFT: if (canMoveLeft) Xposition <= Xposition - MOVEMENT_SPEED;
      //     DIR_RIGHT: if (canMoveRight) Xposition <= Xposition + MOVEMENT_SPEED;
      //   endcase
    end
  end

  // Outputs
  assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;
  assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

endmodule
