module ghost_move (	
    input  logic clk,
    input  logic resetN,
    input  logic startOfFrame,      // short pulse every start of frame 30Hz       
    input  logic collision,         // collision if smiley hits an object 
    input  logic [1:0] ghostSelect,
    output logic signed [10:0] topLeftX, // output the top left corner 
    output logic signed [10:0] topLeftY, // can be negative , if the object is partliy outside
    output logic [3:0] currentDirection
);

    const int FIXED_POINT_MULTIPLIER = 64;
    const int OBJECT_WIDTH_X = 32;
    const int OBJECT_HIGHT_Y = 32;
    const int SafetyMargin   = 2;
    const int x_FRAME_LEFT   = (SafetyMargin)* FIXED_POINT_MULTIPLIER; 
    const int x_FRAME_RIGHT  = (639 - SafetyMargin - OBJECT_WIDTH_X)* FIXED_POINT_MULTIPLIER; 
    const int y_FRAME_TOP    = (SafetyMargin) * FIXED_POINT_MULTIPLIER;
    const int y_FRAME_BOTTOM = (479 - SafetyMargin - OBJECT_HIGHT_Y) * FIXED_POINT_MULTIPLIER; 

    localparam UP_KEY    = 4'd8;
    localparam RIGHT_KEY = 4'd6;
    localparam LEFT_KEY  = 4'd4;
    localparam DOWN_KEY  = 4'd2;

    const int MOVEMENT_SPEED = 50; 

    parameter int INITIAL_X = 280;
    parameter int INITIAL_Y = 185;

    int Xposition;
    int Yposition;
    int Xspeed;
    int Yspeed;

    // random generator (8-bit LFSR)
    logic [7:0] lfsr;
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN)
            lfsr <= 8'h1;
        else
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    enum logic [2:0] {
        IDLE_ST,
        MOVE_ST,
        START_OF_FRAME_ST,
        POSITION_CHANGE_ST,
        POSITION_LIMITS_ST
    } SM_Motion;

    logic [4:0] hit_reg = 5'b00000;

    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            SM_Motion        <= IDLE_ST;
            Xposition        <= INITIAL_X*FIXED_POINT_MULTIPLIER;
            Yposition        <= INITIAL_Y*FIXED_POINT_MULTIPLIER;
            Xspeed           <= 0;
            Yspeed           <= 0;
            currentDirection <= 0;
        end
        else begin
            case (SM_Motion)

                IDLE_ST: begin
                    Xspeed           <= 0; 
                    Yspeed           <= 0; 
                    Xposition        <= INITIAL_X*FIXED_POINT_MULTIPLIER; 
                    Yposition        <= INITIAL_Y*FIXED_POINT_MULTIPLIER; 
                    currentDirection <= 0;
                    if (startOfFrame) 
                        SM_Motion <= MOVE_ST;
                end

                MOVE_ST: begin
                    if (startOfFrame)
                        SM_Motion <= START_OF_FRAME_ST; 
                end 

                START_OF_FRAME_ST: begin
                    hit_reg <= 5'b00000;

                    // <<< RANDOM PART >>> only for ghostSelect == 3
                    if (ghostSelect == 2'b01) begin
                        unique case (lfsr[1:0])
                            2'b00: begin
                                Xspeed           <= 0;
                                Yspeed           <= -MOVEMENT_SPEED;
                                currentDirection <= UP_KEY;
                            end
                            2'b01: begin
                                Xspeed           <= 0;
                                Yspeed           <= MOVEMENT_SPEED;
                                currentDirection <= DOWN_KEY;
                            end
                            2'b10: begin
                                Xspeed           <= -MOVEMENT_SPEED;
                                Yspeed           <= 0;
                                currentDirection <= LEFT_KEY;
                            end
                            2'b11: begin
                                Xspeed           <= MOVEMENT_SPEED;
                                Yspeed           <= 0;
                                currentDirection <= RIGHT_KEY;
                            end
                        endcase
                    end
                    // <<< END RANDOM PART >>>

                    SM_Motion <= POSITION_CHANGE_ST; 
                end 

                POSITION_CHANGE_ST: begin
                    Xposition <= Xposition + Xspeed; 
                    Yposition <= Yposition + Yspeed;
                    SM_Motion <= POSITION_LIMITS_ST; 
                end

                POSITION_LIMITS_ST: begin
                    if (Xposition < x_FRAME_LEFT) begin
                        Xposition <= x_FRAME_LEFT ;
                        Xspeed    <= 0;
                        Yspeed    <= 0;
                    end				
                    if (Xposition > x_FRAME_RIGHT) begin
                        Xposition <= x_FRAME_RIGHT ;
                        Xspeed    <= 0;
                        Yspeed    <= 0;
                    end	
                    if (Yposition < y_FRAME_TOP) begin
                        Yposition <= y_FRAME_TOP ; 
                        Xspeed    <= 0;
                        Yspeed    <= 0;
                    end
                    if (Yposition > y_FRAME_BOTTOM) begin
                        Yposition <= y_FRAME_BOTTOM ;
                        Xspeed    <= 0;
                        Yspeed    <= 0;
                    end
                    SM_Motion <= MOVE_ST; 
                end

            endcase
        end
    end 

    assign topLeftX = Xposition / FIXED_POINT_MULTIPLIER;   
    assign topLeftY = Yposition / FIXED_POINT_MULTIPLIER;    

endmodule
