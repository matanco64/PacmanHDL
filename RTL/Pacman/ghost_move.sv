module ghost_move (
    input  logic        clk,
    input  logic        resetN,
    input  logic        startOfFrame,  // 30Hz pulse (move tick)
    input  logic [1:0]  ghostSelect,   // for future AI types
    input  logic [11:0] aroundGhost,   // {Up, Down, Left, Right}, 3 bits per tile

    output logic signed [10:0] topLeftX,
    output logic signed [10:0] topLeftY
);

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  localparam int FIXED_POINT_MULTIPLIER = 16;
  localparam int TILE_BITS = 3;
  localparam int MOVEMENT_SPEED = 16;  // fixed-point units (== 1 pixel if multiplier==16)
  localparam int OBJECT_WIDTH = 16;
  localparam int OBJECT_HEIGHT = 16;
  localparam int SAFETY_MARGIN = 16;

  localparam logic [TILE_BITS-1:0] WALL = 3'd2;

  localparam int X_FRAME_LEFT = (SAFETY_MARGIN) * FIXED_POINT_MULTIPLIER;
  localparam int X_FRAME_RIGHT = (640 - SAFETY_MARGIN - OBJECT_WIDTH) * FIXED_POINT_MULTIPLIER;
  localparam int Y_FRAME_TOP = (SAFETY_MARGIN) * FIXED_POINT_MULTIPLIER;
  localparam int Y_FRAME_BOTTOM = (480 - SAFETY_MARGIN - OBJECT_HEIGHT) * FIXED_POINT_MULTIPLIER;

  parameter int INITIAL_X = 280;
  parameter int INITIAL_Y = 185;

  // ---------------------------------------------------------------------------
  // Direction encoding
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    DIR_UP    = 2'b00,
    DIR_DOWN  = 2'b01,
    DIR_LEFT  = 2'b10,
    DIR_RIGHT = 2'b11
  } dir_t;

  // ---------------------------------------------------------------------------
  // Position and speed (fixed-point)
  // ---------------------------------------------------------------------------
  int Xposition;  // position * FIXED_POINT_MULTIPLIER
  int Yposition;
  int Xspeed;
  int Yspeed;

  dir_t ghostDir;

  // temps and flags (module scope)
  dir_t newDir;   // direction previously chosen (applied when changing)
  logic hit;

  // ---------------------------------------------------------------------------
  // Random generator (4-bit LFSR)
  // ---------------------------------------------------------------------------
  logic [3:0] lfsr;
  wire  [1:0] rnd = lfsr[1:0];

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) lfsr <= 4'b1011;
    else         lfsr <= {lfsr[2:0], lfsr[3] ^ lfsr[2]};
  end

  // ---------------------------------------------------------------------------
  // Direction chooser (safe random turn) - combinational
  // ---------------------------------------------------------------------------
  function automatic dir_t chooseNewDirSafe(input [4*TILE_BITS-1:0] around, input [1:0] rnd,
                                            input int Xpos, input int Ypos);
    dir_t candidate;
    int newX, newY;
    begin
      // try 4 directions in pseudo-random order
      for (int i = 0; i < 4; i++) begin
        case ((rnd + i) % 4)
          0: candidate = DIR_UP;
          1: candidate = DIR_DOWN;
          2: candidate = DIR_LEFT;
          default: candidate = DIR_RIGHT;
        endcase

        newX = Xpos;
        newY = Ypos;
        case (candidate)
          DIR_UP:    newY -= MOVEMENT_SPEED;
          DIR_DOWN:  newY += MOVEMENT_SPEED;
          DIR_LEFT:  newX -= MOVEMENT_SPEED;
          DIR_RIGHT: newX += MOVEMENT_SPEED;
        endcase

        if (((candidate == DIR_UP    && around[4*TILE_BITS-1 -: TILE_BITS] != WALL && newY >= Y_FRAME_TOP)    ||
             (candidate == DIR_DOWN  && around[3*TILE_BITS-1 -: TILE_BITS] != WALL && newY <= Y_FRAME_BOTTOM) ||
             (candidate == DIR_LEFT  && around[2*TILE_BITS-1 -: TILE_BITS] != WALL && newX >= X_FRAME_LEFT)   ||
             (candidate == DIR_RIGHT && around[1*TILE_BITS-1 -: TILE_BITS] != WALL && newX <= X_FRAME_RIGHT)))
        begin
          return candidate;
        end
      end
      return DIR_UP;  // fallback
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Junction detection (counts free directions)
  // ---------------------------------------------------------------------------
  function automatic bit isJunction(input [11:0] around);
    int freeCount;
    begin
      freeCount = 0;
      if (around[4*TILE_BITS-1 -: TILE_BITS] != WALL) freeCount++;
      if (around[3*TILE_BITS-1 -: TILE_BITS] != WALL) freeCount++;
      if (around[2*TILE_BITS-1 -: TILE_BITS] != WALL) freeCount++;
      if (around[1*TILE_BITS-1 -: TILE_BITS] != WALL) freeCount++;
      return (freeCount > 2);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // FSM states
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE_ST,
    DECIDE_DIR_ST,
	 UPDATE_SPEED,
    MOVE_ST
  } motion_state_t;

  motion_state_t SM_Motion;

  // ---------------------------------------------------------------------------
  // Main FSM - sequential logic
  // ---------------------------------------------------------------------------
  
  logic [4:0] dirCooldown; // enough bits for up to 31 frames
  localparam int DIR_COOLDOWN_VALUE = 5'd16; // tune: number of frames to wait
 

  always_ff @(posedge clk or negedge resetN) begin
		if (!resetN) begin
		 SM_Motion   <= IDLE_ST;
		 Xspeed      <= 0;
		 Yspeed      <= 0;
		 Xposition   <= INITIAL_X * FIXED_POINT_MULTIPLIER;
		 Yposition   <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
		 ghostDir    <= DIR_LEFT;
		 newDir      <= DIR_LEFT;
		 hit         <= 1'b0;
		 dirCooldown <= DIR_COOLDOWN_VALUE;   
		 
		 
	  end else begin
		 // decrement cooldown
		if (startOfFrame && dirCooldown > 0)
			dirCooldown <= dirCooldown - 1;
			
      case (SM_Motion)

        // -----------------------------------------------------------------
        IDLE_ST: begin
          // set initial motion left (you can change this)
          Xspeed <= -MOVEMENT_SPEED;
          Yspeed <= 0;
          ghostDir <= DIR_LEFT;
          // go to MOVE_ST on first startOfFrame
          if (startOfFrame) begin
            SM_Motion <= MOVE_ST;
          end
        end

        // -----------------------------------------------------------------
        DECIDE_DIR_ST: begin
          // Snap position to integer pixel grid once when deciding (avoid sub-pixel residue)
          Xposition <= (Xposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER;
          Yposition <= (Yposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER;

          // Choose new direction combinationally and store it to newDir
          newDir <= chooseNewDirSafe(aroundGhost, rnd, Xposition, Yposition);

          if(clk)  SM_Motion <= UPDATE_SPEED;
        end

		  // -----------------------------------------------------------------
		  UPDATE_SPEED: begin

          // set speeds immediately based on chosen direction
          case (newDir)
            DIR_UP:    begin Xspeed <= 0;                 Yspeed <= -MOVEMENT_SPEED; end
            DIR_DOWN:  begin Xspeed <= 0;                 Yspeed <=  MOVEMENT_SPEED; end
            DIR_LEFT:  begin Xspeed <= -MOVEMENT_SPEED;   Yspeed <= 0;                end
            DIR_RIGHT: begin Xspeed <=  MOVEMENT_SPEED;   Yspeed <= 0;                end
            default:   begin Xspeed <= 0;                 Yspeed <= 0;                end
          endcase

          // start a cooldown to avoid immediate re-change
          dirCooldown <= DIR_COOLDOWN_VALUE;

          // next state: move
          SM_Motion <= MOVE_ST;
        end
        // -----------------------------------------------------------------
        MOVE_ST: begin
          // Movement occurs only on the startOfFrame pulse (30Hz)
          if (startOfFrame) begin
            // clear hit flag for this frame
            hit <= 1'b0;

            // move according to current ghostDir
            case (ghostDir)
              DIR_UP: begin
                if (aroundGhost[11:9] != WALL && (Yposition - MOVEMENT_SPEED) >= Y_FRAME_TOP) begin
                  Yposition <= Yposition - MOVEMENT_SPEED;
                end else begin
                  hit <= 1'b1;
                end
              end

              DIR_DOWN: begin
                if (aroundGhost[8:6] != WALL && (Yposition + MOVEMENT_SPEED) <= Y_FRAME_BOTTOM) begin
                  Yposition <= Yposition + MOVEMENT_SPEED;
                end else begin
                  hit <= 1'b1;
                end
              end

              DIR_LEFT: begin
                if (aroundGhost[5:3] != WALL && (Xposition - MOVEMENT_SPEED) >= X_FRAME_LEFT) begin
                  Xposition <= Xposition - MOVEMENT_SPEED;
                end else begin
                  hit <= 1'b1;
                end
              end

              DIR_RIGHT: begin
                if (aroundGhost[2:0] != WALL && (Xposition + MOVEMENT_SPEED) <= X_FRAME_RIGHT) begin
                  Xposition <= Xposition + MOVEMENT_SPEED;
                end else begin
                  hit <= 1'b1;
                end
              end

              default: begin
                // do nothing
              end
            endcase

            // Decide whether to change direction:
            // - only when aligned to pixel grid (we keep top-left alignment)
            // - only when cooldown expired
            // - change if hit or at a junction
            if ((dirCooldown == 5'd0) &&
                ((Xposition % FIXED_POINT_MULTIPLIER) == 0) &&
                ((Yposition % FIXED_POINT_MULTIPLIER) == 0) &&
                ( hit || isJunction(aroundGhost) )) begin

              // apply previously chosen newDir (chosen in DECIDE_DIR_ST)
              ghostDir <= newDir;
              // go choose a new direction next cycle so speeds will be updated
              SM_Motion <= DECIDE_DIR_ST;
            end
          end // startOfFrame
        end

        default: SM_Motion <= IDLE_ST;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  // convert fixed-point back to integer pixels
  assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;
  assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

endmodule
