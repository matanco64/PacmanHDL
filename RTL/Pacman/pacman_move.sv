module pacman_move (

    input logic       clk,
    input logic       resetN,
    input logic       startOfFrame,  //short pulse every start of frame 30Hz 
	 input logic       oneSec, 
    input logic [3:0] keyPadCode,    //move direction
    input logic       keyPadValid,

    // collision
    input logic       collision_pac_wall,
    input logic [2:0] collision_pac_ghost, // 0=no 1=B 2=P 3=I 4=C

    input logic [15:0] aroundPac,
    input logic [ 2:0] gameState,
    input logic [ 1:0] speedChange, // 0=normal, 1=fast, 2=slow

    output logic signed [10:0] topLeftX,  // output the top left corner 
    output logic signed [10:0] topLeftY,  // can be negative , if the object is partliy outside
    output logic [3:0] curDirKey,
    output logic [1:0] curDir,
	 output logic recovering
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
  localparam RECOVER_TIME = 4'd3;

  const int FIXED_POINT_MULTIPLIER = 64;
  const int OBJECT_WIDTH_X = 32;
  const int OBJECT_HIGHT_Y = 32;
  const int NORMAL_SPEED = 64;

  int speed;
  int prevSpeed;
  int Xposition;
  int Yposition;
  int Xspeed;
  int Yspeed;
  logic speedChangeRequested;
  logic keyPadValidAction;


  enum logic [2:0] {
    IDLE_ST,             // initial state
    MOVE_ST,             // moving no colision 
    START_OF_FRAME_ST,   // startOfFrame activity-after all data collected 
    POSITION_CHANGE_ST,  // position interpolate 
    PORTAL_UP,
    PORTAL_DOWN,
    WAIT_ST
  } SM_Motion;

  logic hit_reg = 1'b0;
  logic [2:0] recoveTimer; 

  logic canTurn;
  assign canTurn = ((Xposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER)) == 0) &&
                 ((Yposition % (TILE_PIXELS * FIXED_POINT_MULTIPLIER)) == 0);



  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      SM_Motion <= IDLE_ST;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

      Xspeed <= 0;
      Yspeed <= 0;
      hit_reg <= 1'b0;
      speed <= NORMAL_SPEED;
      prevSpeed <= 0;
      curDirKey <= INITIAL_DIRECTION;
		recovering <= 0;
		recoveTimer <=0;
		
	end else if(gameState == RESET_ST) begin
		SM_Motion <= IDLE_ST;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;

      Xspeed <= 0;
      Yspeed <= 0;
      hit_reg <= 1'b0;
		speedChangeRequested <= 1'b0;
      speed <= NORMAL_SPEED;
      prevSpeed <= 0;
      curDirKey <= INITIAL_DIRECTION;
		recovering <= 0;
		recoveTimer <=0;
    end else if (collision_pac_ghost != 3'b0 && gameState != POWER_UP_ST && !recovering) begin  // touch ghost
      SM_Motion <= IDLE_ST;
      Xposition <= INITIAL_X * FIXED_POINT_MULTIPLIER;
      Yposition <= INITIAL_Y * FIXED_POINT_MULTIPLIER;
      Xspeed <= 0;
      Yspeed <= 0;
      hit_reg <= 1'b0;
		speedChangeRequested <= 1'b0;
      curDirKey <= INITIAL_DIRECTION;
		recovering <= 1'b1;
		recoveTimer <= RECOVER_TIME;
    end else if (gameState == START_WAIT_ST || gameState == PAUSED_ST || gameState == GHOST_HIT_ST || gameState == WIN_ST || gameState == LOSE_ST) begin
      // Pacman stands still in START or PAUSE
      SM_Motion <= WAIT_ST;
		if(gameState == LOSE_ST || gameState == WIN_ST || gameState == PAUSED_ST) recovering <= 0;
    end else begin

      // missing - handle speed next do turbo - all in different ff block
		
		if(recoveTimer > 0 && oneSec) recoveTimer <= recoveTimer- 1;
		else if(recoveTimer == 0) recovering <= 0 ;

      if (startOfFrame && canTurn) begin
        case (speedChange)
          0: speed <= NORMAL_SPEED;
          1: speed <= NORMAL_SPEED * 2;
          2: speed <= NORMAL_SPEED / 2;
          default: speed <= NORMAL_SPEED;
        endcase
        prevSpeed <= speed;
      end

      // align if speed has changed - prevent getting stuck at the middle
      if (speed != prevSpeed) begin
        Xposition <= ((Xposition / FIXED_POINT_MULTIPLIER)/ TILE_PIXELS ) * FIXED_POINT_MULTIPLIER*TILE_PIXELS;
        Yposition <= ((Yposition / FIXED_POINT_MULTIPLIER)/ TILE_PIXELS ) * FIXED_POINT_MULTIPLIER*TILE_PIXELS;
        prevSpeed <= speed;
		  speedChangeRequested <= 1'b1;
      end

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
          if (keyPadValidAction && canTurn) begin
              curDirKey <= keyPadCode;
              speedChangeRequested <= 1'b1;
          end
			 
			
				
          if (speedChangeRequested) begin
            case (curDirKey)
              UP_KEY: begin
                Yspeed <= -speed;
                Xspeed <= 0;
              end
              RIGHT_KEY: begin
                Xspeed <= speed;
                Yspeed <= 0;
              end
              LEFT_KEY: begin
                Xspeed <= -speed;
                Yspeed <= 0;
              end
              DOWN_KEY: begin
                Yspeed <= speed;
                Xspeed <= 0;
              end
              default: ;
            endcase

            // ensure there is no accumaltive 1/64th pixel error:
            Xposition <= ((Xposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER);
            Yposition <= ((Yposition / FIXED_POINT_MULTIPLIER) * FIXED_POINT_MULTIPLIER);
				speedChangeRequested <= 1'b0;
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
			 
			 if (hit_reg) begin
				 int curTileX;
				 int curTileY;
				 int nextX, nextY;
				 int tileMultiplier = (TILE_PIXELS * FIXED_POINT_MULTIPLIER);
				

				 curTileX = Xposition / tileMultiplier;
				 curTileY = Yposition / tileMultiplier;

				 nextX = curTileX * tileMultiplier;
				 nextY = curTileY * tileMultiplier;

				 // Nudge to the opposite edge when coming from UP/LEFT
				 case (curDirKey)
					UP_KEY: nextY = (curTileY + 1) * tileMultiplier;
					DOWN_KEY:  nextY = curTileY * tileMultiplier;
					LEFT_KEY: nextX = (curTileX + 1) * tileMultiplier;
					RIGHT_KEY: nextX = curTileX * tileMultiplier;
					default: ;
				 endcase
				 Xposition <= nextX;
				 Yposition <= nextY;
				 Xspeed  <= 0;
				 Yspeed  <= 0;
				 hit_reg <= 1'b0;
			end
						
	

          SM_Motion <= POSITION_CHANGE_ST;
        end

        //------------------------
        POSITION_CHANGE_ST: begin  // position interpolate
          //------------------------

          Xposition <= Xposition + Xspeed;
          Yposition <= Yposition + Yspeed;


          if (aroundPac[15:12] == PORTAL && curDirKey == UP_KEY) SM_Motion <= PORTAL_UP;
          else if (aroundPac[11:8] == PORTAL && curDirKey == DOWN_KEY) SM_Motion <= PORTAL_DOWN;
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

        WAIT_ST: begin
          Xspeed <= 0;
          Yspeed <= 0;
          if (startOfFrame && (gameState == PLAYING_ST || gameState == POWER_UP_ST))
            SM_Motion <= MOVE_ST;
            speedChangeRequested <= 1'b1;
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
	  keyPadValidAction = keyPadValid && (keyPadCode == UP_KEY || keyPadCode == DOWN_KEY || keyPadCode == LEFT_KEY || keyPadCode == RIGHT_KEY);
  end




endmodule