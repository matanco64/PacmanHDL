module ghost_move (
    input logic clk,
    input logic resetN,
    input logic startOfFrame,
    input logic [1:0] ghostSelect,
    input logic [11:0] aroundGhost,
    input logic [10:0] pacmanX,
    input logic [10:0] pacmanY,
    input logic [1:0] pacmanDir,
	 
	 input logic [2:0] collisionPacGhost,
    input logic [1:0] forceMode,          // External mode control: 00=unused, 01=unused, 10=FRIGHTENED_M, 11=EATEN_M
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
  parameter SCREEN_HEIGHT = 480;
  parameter SCREEN_WIDTH = 640;

  parameter [TILE_BITS-1:0] EMPTY = 3'd0;
  parameter [TILE_BITS-1:0] WALL = 3'd2;
  parameter [TILE_BITS-1:0] GHOST_WALL = 3'd3;
  parameter [TILE_BITS-1:0] PORTAL = 3'd4;

  // time
  parameter [10:0] SCATTER_TIME = 10'd210;  // 7 SEC
  parameter [10:0] CHASE_TIME = 10'd600;  // 20 SEC
  parameter [10:0] FRIGHTENED_TIME = 10'd180;  // 6 SEC
  parameter IDLE_DELAY_FRAMES = 60;  // 2 sec

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

  // ---------------------------------------------------------------------------
  // Internal signals
  // ---------------------------------------------------------------------------
  reg signed [31:0] Xposition, Yposition;
  reg [1:0] ghostDir, lastDir;
  reg [7:0] modeTimer;
  reg [7:0] frightenedTimer;
  reg [7:0] idleCounter;
  reg [1:0] prevMode;

  reg signed [31:0] targetX, targetY;
  reg signed [31:0] distUp, distDown, distLeft, distRight;

  reg  [1:0] nextDir;
  reg  [7:0] lfsr;
  wire [1:0] rnd;
  assign rnd = lfsr[1:0];

  // junction detection
  wire isJunction;
  assign isJunction = ((canMoveUp || canMoveDown) && (canMoveLeft || canMoveRight));
  wire aligned_to_grid;
  assign aligned_to_grid = (Xposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER) == 0) &&
                         (Yposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER) == 0);   // if speed is not a multiple of TILE_PIXELS:  cahnge ==0 to < MOVEMENT_SPEED

             
  // Direction checking signals
  wire canMoveUp, canMoveDown, canMoveLeft, canMoveRight;

  assign canMoveUp = (!aligned_to_grid || aroundGhost[11:9] != WALL);
  assign canMoveDown = (!aligned_to_grid || aroundGhost[8:6] != WALL&& aroundGhost[8:6] != GHOST_WALL);
  assign canMoveLeft = (!aligned_to_grid || aroundGhost[5:3] != WALL);
  assign canMoveRight = (!aligned_to_grid || (aroundGhost[2:0] != WALL));

  enum logic [1:0] {  // ghost movement
    IDLE_ST,
    CHANGE_ST,
    MOVE_ST
  } SM_Motion;

  enum logic [1:0] {  // ghost mode
    SCATTER_M,
    CHASE_M,
    FRIGHTENED_M,
    EATEN_M
  } currMode;

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

  function automatic signed [31:0] absDiff(input signed [31:0] a, input signed [31:0] b);
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
    case (currMode)
      SCATTER_M: begin
        targetX = homeX;
        targetY = homeY;
      end

      CHASE_M: begin
        case (ghostSelect)
          2'd0: begin  // Blinky - direct CHASE_M
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
              default: begin  // If no direction, just CHASE_M directly
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

      FRIGHTENED_M: begin
        targetX = Xposition / FIXED_POINT_MULTIPLIER;
        targetY = Yposition / FIXED_POINT_MULTIPLIER;
      end

      EATEN_M: begin
        targetX = INITIAL_X;
        targetY = INITIAL_Y;
      end
    endcase
  end

  // Calculate potential new positions and their distances to target
  always_comb begin
    // local temporaries (pixel units)
    logic signed [31:0] baseX, baseY;
    logic signed [31:0] tileX, tileY;
    logic signed [31:0] newX_up, newY_up, newX_down, newY_down;
    logic signed [31:0] newX_left, newY_left, newX_right, newY_right;

    // Normalize to pixel coordinates (from fixed-point)
    baseX      = Xposition / FIXED_POINT_MULTIPLIER;  // CHATGPT
    baseY      = Yposition / FIXED_POINT_MULTIPLIER;  // CHATGPT

    // Determine current tile coordinates (integer tile indices)
    tileX      = baseX / TILE_PIXELS;  // CHATGPT
    tileY      = baseY / TILE_PIXELS;  // CHATGPT

    // Neighbor TILE CENTERS (pixel coordinates) - 1 tile offset
    newX_up    = tileX * TILE_PIXELS;  // same column
    newY_up    = (tileY - 1) * TILE_PIXELS;  // one tile up

    newX_down  = tileX * TILE_PIXELS;
    newY_down  = (tileY + 1) * TILE_PIXELS;

    newX_left  = (tileX - 1) * TILE_PIXELS;  // one tile left
    newY_left  = tileY * TILE_PIXELS;

    newX_right = (tileX + 1) * TILE_PIXELS;
    newY_right = tileY * TILE_PIXELS;

    // Manhattan distance from each candidate tile-center to the target (all in pixels)
    distUp     = absDiff(newX_up, targetX) + absDiff(newY_up, targetY);  // CHATGPT
    distDown   = absDiff(newX_down, targetX) + absDiff(newY_down, targetY);  // CHATGPT
    distLeft   = absDiff(newX_left, targetX) + absDiff(newY_left, targetY);  // CHATGPT
    distRight  = absDiff(newX_right, targetX) + absDiff(newY_right, targetY);  // CHATGPT
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

    if (currMode == FRIGHTENED_M) begin  // Random direction - FRIGHTENED_M mode - the code is long for quartus compatibility
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
    end
  end

  // ---------------------------------------------------------------------------
  // always_ff blocks
  // ---------------------------------------------------------------------------

  // Random number generator
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) lfsr <= 8'b10110001;
    else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  end


  // Motion state machine
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      idleCounter <= 0;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      ghostDir <= DIR_UP;
      lastDir <= DIR_UP;
      SM_Motion <= IDLE_ST;
		
	 end else if (collisionPacGhost !=3'b0)	begin
	  idleCounter <= 0;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      ghostDir <= DIR_UP;
      lastDir <= DIR_UP;
      SM_Motion <= IDLE_ST;
	
    end else begin
      case (SM_Motion)
        IDLE_ST: begin
          // Increment counter until delay is reached
          if (idleCounter < IDLE_DELAY_FRAMES) idleCounter <= idleCounter + 1;
          else if (startOfFrame) begin
            idleCounter <= 0;
            SM_Motion   <= CHANGE_ST;  // Start normal movement
          end
        end

        CHANGE_ST: begin
          if (startOfFrame) begin
            if (prevMode != currMode && currMode == FRIGHTENED_M) begin
              case (ghostDir)  // Reverse direction on entering FRIGHTENED_M
                DIR_UP:    ghostDir <= DIR_DOWN;
                DIR_DOWN:  ghostDir <= DIR_UP;
                DIR_LEFT:  ghostDir <= DIR_RIGHT;
                DIR_RIGHT: ghostDir <= DIR_LEFT;
              endcase
              prevMode <= currMode;
            end else begin
              // Direction changes at junctions or when stuck
              if (aligned_to_grid) begin
                // Check if we can move in current direction
                case (ghostDir)
                  DIR_UP:
                  if (aroundGhost[11:9] == PORTAL) begin
                    Yposition <= (SCREEN_HEIGHT - 2 * TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
                  end else if (!canMoveUp || isJunction) begin
                    lastDir  <= ghostDir;
                    ghostDir <= nextDir;
                  end
                  DIR_DOWN:
                  if (aroundGhost[8:6] == PORTAL) begin
                    Yposition <= (2* TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
                  end else if (!canMoveDown || isJunction) begin
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
              // update prevMode
              prevMode <= currMode;
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

    end
  end


  // Mode state machine
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      currMode        <= SCATTER_M;
      modeTimer       <= SCATTER_TIME;
      frightenedTimer <= 8'd0;
		
	end else if (collisionPacGhost !=3'b0)	begin // collision
		currMode        <= SCATTER_M;
      modeTimer       <= SCATTER_TIME;
      frightenedTimer <= 8'd0;
		
    end else if (startOfFrame) begin

      // Update timers
      if (modeTimer > 0) modeTimer <= modeTimer - 1;
      if (frightenedTimer > 0) frightenedTimer <= frightenedTimer - 1;

      // FSM transitions
      case (currMode)

        SCATTER_M: begin
          if (forceMode == FRIGHTENED_M) begin
            currMode        <= FRIGHTENED_M;
            frightenedTimer <= FRIGHTENED_TIME;
          end else if (modeTimer == 0) begin
            currMode  <= CHASE_M;
            modeTimer <= CHASE_TIME;
          end
        end

        CHASE_M: begin
          if (forceMode == FRIGHTENED_M) begin
            currMode        <= FRIGHTENED_M;
            frightenedTimer <= FRIGHTENED_TIME;
          end else if (modeTimer == 0) begin
            currMode  <= SCATTER_M;
            modeTimer <= SCATTER_TIME;
          end
        end

        FRIGHTENED_M: begin
          if (frightenedTimer == 0) begin
            currMode  <= CHASE_M;
            modeTimer <= 8'd150;
          end
        end

        EATEN_M: begin
          // handled separately (e.g. reset position when reaching the pen)
        end

      endcase
    end
  end


  // Outputs
  assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;
  assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

endmodule