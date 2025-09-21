module	pacman_move	(	
 
					input	 logic clk,
					input	 logic resetN,
					input	 logic startOfFrame,      //short pulse every start of frame 30Hz 
					input	 logic [3:0] keyPadCode,   //move direction
					input	 logic keyPadValid,        
					input  logic collision,         //collision if smiley hits an object
					input  logic [2:0] HitEdgeCode, 
					output logic signed 	[10:0] topLeftX, // output the top left corner 
					output logic signed	[10:0] topLeftY,  // can be negative , if the object is partliy outside
					output logic [3:0] curDirKey,
					output logic [3:0] curDir
					
);

const int	FIXED_POINT_MULTIPLIER = 64;

const int   OBJECT_WIDTH_X = 32;
const int   OBJECT_HIGHT_Y = 32;
const int	SafetyMargin   = 16;
const int	x_FRAME_LEFT	=	(SafetyMargin)* FIXED_POINT_MULTIPLIER; 
const int	x_FRAME_RIGHT	=	(640 - SafetyMargin - OBJECT_WIDTH_X)* FIXED_POINT_MULTIPLIER; 
const int	y_FRAME_TOP		=	(SafetyMargin) * FIXED_POINT_MULTIPLIER;
const int	y_FRAME_BOTTOM	=	(480 -SafetyMargin) * FIXED_POINT_MULTIPLIER; //- OBJECT_HIGHT_Y


localparam UP_KEY = 4'd8;
localparam INITIAL_DIRECTION = UP_KEY;
localparam RIGHT_KEY = 4'd6;
localparam LEFT_KEY = 4'd4;
localparam DOWN_KEY = 4'd2;


const int	MOVEMENT_SPEED = 64; 


parameter int INITIAL_X = 280;
parameter int INITIAL_Y = 185;

int Xposition;
int Yposition;
int Xspeed;
int Yspeed;

//const logic [4:0] CORNER =	5'b10000; 
//const logic [3:0] TOP =		 4'b1000; 
//const logic [3:0] RIGHT =   4'b0100; 
//const logic [3:0] LEFT =	 4'b0010; 
//const logic [3:0] BOTTOM =  4'b0001; 


enum  logic [2:0] {IDLE_ST,         	// initial state
						 MOVE_ST, 				// moving no colision 
						 START_OF_FRAME_ST, 	          // startOfFrame activity-after all data collected 
						 POSITION_CHANGE_ST, // position interpolate 
						 POSITION_LIMITS_ST  // check if inside the frame  
						}  SM_Motion ;
						
logic hit_reg = 1'b0;
logic is_neg;

logic canTurn;

assign canTurn = ((Xposition / FIXED_POINT_MULTIPLIER) % 16) == 0 && ((Yposition / FIXED_POINT_MULTIPLIER) % 16) == 0;


always_ff @(posedge clk or negedge resetN)
begin
	if (resetN == 1'b0) begin
		SM_Motion <= IDLE_ST;
		Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER;
		Xspeed <= 0;
		Yspeed <= 0;
		hit_reg <= 1'b0;
		is_neg <= 1'b0;
		Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER;
		curDirKey <= INITIAL_DIRECTION;
	end
	else begin

		case(SM_Motion)
			
			//------------
				IDLE_ST: begin
			//------------
			
					Xspeed  <= 0; 
					Yspeed  <= 0; 
					Xposition <= INITIAL_X*FIXED_POINT_MULTIPLIER; 
					Yposition <= INITIAL_Y*FIXED_POINT_MULTIPLIER; 
					curDirKey <= INITIAL_DIRECTION;
					if (startOfFrame) 
						SM_Motion <= MOVE_ST ;
		
				end
		
			//------------
				MOVE_ST:  begin     // moving collecting colisions 
			//------------
				
				if(keyPadValid && !is_neg && canTurn) begin
					case(keyPadCode)
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
	 			if (collision) begin
					hit_reg <= 1'b1;
				end
				

				if (startOfFrame )
					SM_Motion <= START_OF_FRAME_ST ; 
						
						
					
			end 
			
			//------------
				START_OF_FRAME_ST:  begin      //check if any colision was detected 
			//------------
					if (hit_reg && !is_neg) begin
						Xspeed <= -Xspeed;
						Yspeed <= -Yspeed;
						hit_reg <= 1'b0;
						is_neg <= 1'b1;
						
					end else if (!hit_reg && is_neg) begin
						Xspeed <= 0;
						Yspeed <= 0;
						is_neg <= 1'b0;
					end
					
					
					SM_Motion <= POSITION_CHANGE_ST ; 
				end

			//------------------------
				POSITION_CHANGE_ST : begin  // position interpolate 
			//------------------------
		
					Xposition <= Xposition + Xspeed ; 
					Yposition <= Yposition + Yspeed ;
				 
					
					SM_Motion <= POSITION_LIMITS_ST ; 
				end
			
			//------------------------
				POSITION_LIMITS_ST : begin  //check if still inside the frame 
			//------------------------
			
			if (Xposition < x_FRAME_LEFT) begin
							Xposition <= x_FRAME_LEFT ;
							Xspeed <= 0;
							Yspeed <= 0;
			end				
			if (Xposition > x_FRAME_RIGHT) begin
							Xposition <= x_FRAME_RIGHT ;
							Xspeed <= 0;
							Yspeed <= 0;
			end	
			if (Yposition < y_FRAME_TOP) begin
							Yposition <= y_FRAME_TOP ; 
							Xspeed <= 0;
							Yspeed <= 0;
			end
			if (Yposition > y_FRAME_BOTTOM) begin
							Yposition <= y_FRAME_BOTTOM ;
							Xspeed <= 0;
							Yspeed <= 0;
			end

					SM_Motion <= MOVE_ST ; 
				
			end
			
			endcase  // case 

		end
	end 

assign 	topLeftX = Xposition / FIXED_POINT_MULTIPLIER ;   // note it must be 2^n 
assign 	topLeftY = Yposition / FIXED_POINT_MULTIPLIER ;    

always_comb begin
    case (curDirKey)
        UP_KEY: curDir = 2'd0;
        DOWN_KEY: curDir = 2'd1;
        LEFT_KEY: curDir = 2'd2;
        RIGHT_KEY: curDir = 2'd3;
        default: curDir = 2'd0; // fallback value if none match
    endcase
end

	
	

endmodule 