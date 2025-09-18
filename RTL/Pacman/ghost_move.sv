module ghost_move (
    input  logic        clk,
    input  logic        resetN,
    input  logic        startOfFrame,   // 30Hz pulse
    input  logic [1:0]  ghostSelect,    // for future AI types
    input  logic [11:0] aroundGhost,    // {Up, Down, Left, Right}, 3 bits per tile

    output logic signed [10:0] topLeftX,
    output logic signed [10:0] topLeftY
);

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  localparam int FIXED_POINT_MULTIPLIER = 16;
  localparam int TILE_BITS   = 3;
  localparam int MOVEMENT_SPEED = 16;   // one pixel per tick
  localparam int OBJECT_WIDTH  = 16;
  localparam int OBJECT_HEIGHT = 16;
  localparam int SAFETY_MARGIN = 16;

  localparam logic [TILE_BITS-1:0] WALL = 3'd2;

  localparam int X_FRAME_LEFT   = (SAFETY_MARGIN) * FIXED_POINT_MULTIPLIER;
  localparam int X_FRAME_RIGHT  = (640 - SAFETY_MARGIN - OBJECT_WIDTH) * FIXED_POINT_MULTIPLIER;
  localparam int Y_FRAME_TOP    = (SAFETY_MARGIN) * FIXED_POINT_MULTIPLIER;
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
  // Position and speed
  // ---------------------------------------------------------------------------
  int Xposition;
  int Yposition;
  int Xspeed;
  int Yspeed;

  dir_t ghostDir, nextDir;

  // ---------------------------------------------------------------------------
  // Random generator (4-bit LFSR)
  // ---------------------------------------------------------------------------
  logic [3:0] lfsr;
  wire [1:0] rnd = lfsr[1:0];

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)
      lfsr <= 4'b1011;   // seed
    else
      lfsr <= {lfsr[2:0], lfsr[3] ^ lfsr[2]};
  end

  // ---------------------------------------------------------------------------
  // Direction chooser (safe random turn)
  // ---------------------------------------------------------------------------
  function automatic dir_t chooseNewDirSafe(
    input [4*TILE_BITS-1:0] around,
    input [1:0] rnd,
    input int Xpos, input int Ypos
  );
    dir_t candidate;
    int newX, newY;
    begin
      for (int i = 0; i < 4; i++) begin
        case ((rnd + i) % 4)
          0: candidate = DIR_UP;
          1: candidate = DIR_DOWN;
          2: candidate = DIR_LEFT;
          3: candidate = DIR_RIGHT;
        endcase

        newX = Xpos;
        newY = Ypos;
        case (candidate)
          DIR_UP:    newY -= MOVEMENT_SPEED;
          DIR_DOWN:  newY += MOVEMENT_SPEED;
          DIR_LEFT:  newX -= MOVEMENT_SPEED;
          DIR_RIGHT: newX += MOVEMENT_SPEED;
        endcase

        // Check: not a wall and inside bounds
        if (((candidate == DIR_UP    && around[4*TILE_BITS-1 -: TILE_BITS] != WALL && newY >= Y_FRAME_TOP)    ||
             (candidate == DIR_DOWN  && around[3*TILE_BITS-1 -: TILE_BITS] != WALL && newY <= Y_FRAME_BOTTOM) ||
             (candidate == DIR_LEFT  && around[2*TILE_BITS-1 -: TILE_BITS] != WALL && newX >= X_FRAME_LEFT)   ||
             (candidate == DIR_RIGHT && around[1*TILE_BITS-1 -: TILE_BITS] != WALL && newX <= X_FRAME_RIGHT)))
        begin
          return candidate;
        end
      end
      return DIR_UP; // fallback
    end
  endfunction

  // ---------------------------------------------------------------------------
  // FSM states
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE_ST,
    DECIDE_DIR_ST,
    MOVE_ST
  } motion_state_t;

  motion_state_t SM_Motion;

  // ---------------------------------------------------------------------------
  // FSM
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      SM_Motion <= IDLE_ST;
      Xspeed    <= 0;
      Yspeed    <= 0;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      ghostDir  <= DIR_LEFT;
      nextDir   <= DIR_LEFT;
    end else if (ghostSelect == 2'b00) begin
      case (SM_Motion)

        // ---------------------------------------------------------
        IDLE_ST: begin
          if (startOfFrame)
            SM_Motion <= DECIDE_DIR_ST;
        end

        // ---------------------------------------------------------
        DECIDE_DIR_ST: begin
          // Align to tile grid before deciding
          Xposition <= (Xposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER;
          Yposition <= (Yposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER;

          nextDir   <= chooseNewDirSafe(aroundGhost, rnd, Xposition, Yposition);
          ghostDir  <= nextDir;

          case (nextDir)
            DIR_UP:    begin Xspeed <= 0; Yspeed <= -MOVEMENT_SPEED; end
            DIR_DOWN:  begin Xspeed <= 0; Yspeed <=  MOVEMENT_SPEED; end
            DIR_LEFT:  begin Xspeed <= -MOVEMENT_SPEED; Yspeed <= 0; end
            DIR_RIGHT: begin Xspeed <=  MOVEMENT_SPEED; Yspeed <= 0; end
          endcase

          SM_Motion <= MOVE_ST;
        end

        // ---------------------------------------------------------
        MOVE_ST: begin
          if (startOfFrame) begin
            // Move only if not blocked
            case (ghostDir)
              DIR_UP:    if (aroundGhost[4*TILE_BITS-1 -: TILE_BITS] != WALL && Yposition > Y_FRAME_TOP)
                            Yposition <= Yposition + Yspeed;
                          else SM_Motion <= DECIDE_DIR_ST;

              DIR_DOWN:  if (aroundGhost[3*TILE_BITS-1 -: TILE_BITS] != WALL && Yposition < Y_FRAME_BOTTOM)
                            Yposition <= Yposition + Yspeed;
                          else SM_Motion <= DECIDE_DIR_ST;

              DIR_LEFT:  if (aroundGhost[2*TILE_BITS-1 -: TILE_BITS] != WALL && Xposition > X_FRAME_LEFT)
                            Xposition <= Xposition + Xspeed;
                          else SM_Motion <= DECIDE_DIR_ST;

              DIR_RIGHT: if (aroundGhost[1*TILE_BITS-1 -: TILE_BITS] != WALL && Xposition < X_FRAME_RIGHT)
                            Xposition <= Xposition + Xspeed;
                          else SM_Motion <= DECIDE_DIR_ST;
            endcase
          end
        end

      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;
  assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

endmodule
