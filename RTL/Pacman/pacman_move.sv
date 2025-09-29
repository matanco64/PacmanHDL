module pacman_move (

    input logic       clk,
    input logic       resetN,
    input logic       startOfFrame,  //short pulse every start of frame 30Hz 
    input logic [3:0] keyPadCode,    //move direction
    input logic       keyPadValid,

    // collision
    input logic       collision_pac_wall,
    input logic [2:0] collision_pac_ghost, // 0=no 1=B 2=P 3=I 4=C

    input logic [11:0] aroundPac,
    input logic [ 2:0] gameState,

    output logic signed [10:0] topLeftX,  // output the top left corner 
    output logic signed [10:0] topLeftY,  // can be negative , if the object is partliy outside
    output logic [3:0] curDirKey,
    output logic [1:0] curDir
);


  parameter int INITIAL_X = 224;
  parameter int INITIAL_Y = 320;
  // map
  parameter WALL = 2;
  parameter GHOST_WALL = 3;
  parameter PORTAL = 4;
  parameter SCREEN_HEIGHT = 480;
  parameter SCREEN_WIDTH = 640;
  parameter TILE_PIXELS = 16;

  // game states
  parameter RESET_ST = 3'b000;
  parameter START_WAIT_ST = 3'b001;
  parameter PLAYING_ST = 3'b010;
  parameter PAUSED_ST = 3'b011;
  parameter GHOST_HIT_ST = 3'b100;
  parameter WIN_ST = 3'b101;
  parameter LOSE_ST = 3'b110;
  parameter POWER_UP_ST = 3'b111;

  localparam UP_KEY = 4'd8;
  localparam INITIAL_DIRECTION = UP_KEY;
  localparam RIGHT_KEY = 4'd6;
  localparam LEFT_KEY = 4'd4;
  localparam DOWN_KEY = 4'd2;

  const int MOVEMENT_SPEED = 64;
  const int FIXED_POINT_MULTIPLIER = 64;

  const int OBJECT_WIDTH_X = 32;
  const int OBJECT_HIGHT_Y = 32;
  const int SafetyMargin = 16;
  const int x_FRAME_LEFT = (TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
  const int x_FRAME_RIGHT = (640 - TILE_PIXELS - OBJECT_WIDTH_X) * FIXED_POINT_MULTIPLIER;
  const int y_FRAME_TOP = (TILE_PIXELS) * FIXED_POINT_MULTIPLIER;
  const int y_FRAME_BOTTOM = (480 - TILE_PIXELS) * FIXED_POINT_MULTIPLIER;  //- OBJECT_HIGHT_Y

  int Xposition;
  int Yposition;
  int Xspeed;
  int Yspeed;


  enum logic [2:0] {
    IDLE_ST,             // initial state
    MOVE_ST,             // moving no colision 
    START_OF_FRAME_ST,   // startOfFrame activity-after all data collected 
    POSITION_CHANGE_ST,  // position interpolate 
    PORTAL_UP,
    PORTAL_DOWN
  } SM_Motion;

  logic hit_reg = 1'b0;
  logic is_neg;

  logic canTurn;

  assign canTurn = ((Xposition / FIXED_POINT_MULTIPLIER) % 16) == 0 && ((Yposition / FIXED_POINT_MULTIPLIER) % 16) == 0;



  always_ff @(posedge clk or negedge resetN) begin
    if (resetN == 1'b0) begin
      SM_Motion <= IDLE_ST;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Xspeed <= 0;
      Yspeed <= 0;
      hit_reg <= 1'b0;
      is_neg <= 1'b0;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      curDirKey <= INITIAL_DIRECTION;
    end else if (collision_pac_ghost != 3'b0) begin  // thoch ghost
      SM_Motion <= IDLE_ST;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Xspeed <= 0;
      Yspeed <= 0;
      hit_reg <= 1'b0;
      is_neg <= 1'b0;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      curDirKey <= INITIAL_DIRECTION;
		
	  end else if (gameState == START_WAIT_ST || gameState == PAUSED_ST) begin
      // Pacman stands still in START or PAUSE
      Xspeed <= 0;
      Yspeed <= 0;
      SM_Motion <= MOVE_ST;

    end else begin

      case (SM_Motion)

        //------------
        IDLE_ST: begin
          //------------

          Xspeed <= 0;
          Yspeed <= 0;
          Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
          Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
          curDirKey <= INITIAL_DIRECTION;
          if (startOfFrame) SM_Motion <= MOVE_ST;

        end

        //------------
        MOVE_ST: begin  // moving collecting colisions 
          //------------

          if (keyPadValid && !is_neg && canTurn) begin
            case (keyPadCode)
              UP_KEY: begin
                Yspeed <= -MOVEMENT_SPEED;
                Xspeed <= 0;
                curDirKey <= UP_KEY;
              end
              RIGHT_KEY: begin
                Xspeed <= MOVEMENT_SPEED;
                Yspeed <= 0;
                curDirKey <= RIGHT_KEY;
              end
              LEFT_KEY: begin
                Xspeed <= -MOVEMENT_SPEED;
                Yspeed <= 0;
                curDirKey <= LEFT_KEY;
              end
              DOWN_KEY: begin
                Yspeed <= MOVEMENT_SPEED;
                Xspeed <= 0;
                curDirKey <= DOWN_KEY;
              end
            endcase

            // ensure there is no accumaltive 1/64th pixel error:
            Xposition <= ((Xposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER);
            Yposition <= ((Yposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER);

          end


          // Collecting collisions during wait for new frame
          if (collision_pac_wall) begin
            hit_reg <= 1'b1;
          end


          if (startOfFrame) SM_Motion <= START_OF_FRAME_ST;

        end

        //------------
        START_OF_FRAME_ST: begin  //check if any colision was detected 
          //------------
          if (hit_reg && !is_neg) begin
            Xspeed  <= -Xspeed;
            Yspeed  <= -Yspeed;
            hit_reg <= 1'b0;
            is_neg  <= 1'b1;

          end else if (!hit_reg && is_neg) begin
            Xspeed <= 0;
            Yspeed <= 0;
            is_neg <= 1'b0;
          end


          SM_Motion <= POSITION_CHANGE_ST;
        end

        //------------------------
        POSITION_CHANGE_ST: begin  // position interpolate
          //------------------------

          Xposition <= Xposition + Xspeed;
          Yposition <= Yposition + Yspeed;


          if (aroundPac[11:9] == PORTAL && curDirKey == UP_KEY) SM_Motion <= PORTAL_UP;
          else if (aroundPac[8:6] == PORTAL && curDirKey == DOWN_KEY) SM_Motion <= PORTAL_DOWN;
          else SM_Motion <= MOVE_ST;

        end

        //------------------------
        PORTAL_UP: begin  // position interpolate
          //------------------------
          if (startOfFrame) begin
            Yposition <= (SCREEN_HEIGHT - TILE_PIXELS - OBJECT_HIGHT_Y) * FIXED_POINT_MULTIPLIER;
            SM_Motion <= MOVE_ST;
          end
        end

        //------------------------
        PORTAL_DOWN: begin  // position interpolate
          //------------------------
          if (startOfFrame) begin
            Yposition <= (2 * TILE_PIXELS) * FIXED_POINT_MULTIPLIER;  // map is down by 1 tile
            SM_Motion <= MOVE_ST;
          end
        end

      endcase  // case 

    end
  end

  assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;  // note it must be 2^n 
  assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;

  always_comb begin
    case (curDirKey)
      UP_KEY: curDir = 2'd0;
      DOWN_KEY: curDir = 2'd1;
      LEFT_KEY: curDir = 2'd2;
      RIGHT_KEY: curDir = 2'd3;
      default: curDir = 2'd0;  // fallback value if none match
    endcase
  end




endmodule
