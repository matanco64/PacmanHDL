module pacman_game_controller (
    input logic clk,
    input logic resetN,
    input logic pauseN,
    input logic startOfFrame,
    input logic oneSec,
    input logic timerEnd,
    input logic isWin,

    // DR
    input logic pacDR,
    input logic wallsDR,
    input logic coinDR,
    input logic powerDR,
    input logic blinkeyDR,
    input logic pinkeyDR,
    input logic inkyDR,
    input logic clydeDR,

    input logic signed [10:0] partialScore,
    input logic [1:0] pacLifeChange,
	 input logic recovering,
	 input logic levelChanged,
	 

    output logic       collision_pac_wall,
    output logic       collision_pac_coin,
    output logic       collision_pac_power,
    output logic [2:0] collision_pac_ghost,
	 output logic       ghostFlag,

    output logic [2:0] gameState,
    output logic [3:0] gameStateFor7Seg,
    output logic [2:0] currLives,
    output logic [3:0] score0,
    output logic [3:0] score1,
    output logic [3:0] score2,

    output logic [3:0] datainL,
    output logic [3:0] datainH,
    output logic       startCountN
);

  localparam START_HEARTS = 3;
  localparam MAX_HEARTS = 5;
  localparam INCREASE_HEARTS = 1;
  localparam DECREASE_HEARTS = 2;

  localparam [3:0] TIME_POWER_L = 8;
  localparam [3:0] TIME_POWER_H = 0;
  localparam [3:0] TIME_START_L = 3;
  localparam [3:0] TIME_START_H = 0;


  typedef enum logic [2:0] {
    RESET_ST      = 3'b000,
    START_WAIT_ST = 3'b001,
    PLAYING_ST    = 3'b010,
    PAUSED_ST     = 3'b011,
    GHOST_HIT_ST  = 3'b100,
    WIN_ST        = 3'b101,
    LOSE_ST       = 3'b110,
    POWER_UP_ST   = 3'b111
  } game_state_t;

  // Internal registers
  game_state_t currentState, lastState, prePausedState;

  logic [5:0] ghostEaten;
  logic [9:0] totalScore;

  // Collision detection
  assign collision_pac_wall  = pacDR && wallsDR;
  assign collision_pac_coin  = pacDR && coinDR;
  assign collision_pac_power = pacDR && powerDR;  // for map

  // ------------------------------------------------------------
  // Collision detection (combinational, latched later per-frame)
  // ------------------------------------------------------------
  always_comb begin
    collision_pac_ghost = 3'd0;
    if (pacDR) begin
      if (blinkeyDR) collision_pac_ghost = 3'd1;
      else if (pinkeyDR) collision_pac_ghost = 3'd2;
      else if (inkyDR) collision_pac_ghost = 3'd3;
      else if (clydeDR) collision_pac_ghost = 3'd4;
    end
  end


  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      ghostFlag <= 1'b0;
      currLives  <= START_HEARTS;
      ghostEaten <= 0;
      totalScore <= 0;	
    end else if (currentState == RESET_ST) begin
      ghostFlag <= 1'b0;
      currLives  <= START_HEARTS;
      ghostEaten <= 0;
		totalScore <= 0;
    end else begin
      logic signed [4:0] newLives;
		newLives = currLives;
		
		if(pacLifeChange == INCREASE_HEARTS) newLives = newLives+1;
		else if(pacLifeChange == DECREASE_HEARTS) newLives = newLives - 1;

      totalScore = (partialScore + ghostEaten * 5 > 0) ? (partialScore + ghostEaten * 5) : 0;
      if (startOfFrame && collision_pac_ghost == 0) ghostFlag <= 1'b0;

      if (collision_pac_ghost != 3'd0 && !ghostFlag) begin
        ghostFlag <= 1'b1;
        if (currentState == PLAYING_ST && !recovering) begin
          newLives = newLives - 1;
        end else if (currentState == POWER_UP_ST) begin
          ghostEaten <= ghostEaten + 1;
        end
      end

      // Only update currLives
		if (newLives != currLives) 
		   currLives <= (newLives >= MAX_HEARTS)? MAX_HEARTS : (newLives <= 0)? 0 : newLives;
		
    end
  end


  // sticky logic - up for frame
  logic collision_pac_power_reg;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      collision_pac_power_reg <= 1'b0;
    end else if(currentState == RESET_ST) begin
		collision_pac_power_reg <= 1'b0;
	 end else begin

      if (startOfFrame) collision_pac_power_reg <= 1'b0;  // clear at the start of frame
      else if (pacDR && powerDR) collision_pac_power_reg <= 1'b1;
    end
  end

  // ------------------------------------------------------------
  // Sequential FSM and counters
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      currentState   <= RESET_ST;
      lastState      <= RESET_ST;
      prePausedState <= RESET_ST;

      startCountN    <= 1'b1;  // no counting
      datainL        <= 4'd0;
      datainH        <= 4'd0;

    end else  begin
      // default
      startCountN <= 1'b1;

      // State machine updates once per frame
      if (startOfFrame) begin
        lastState <= currentState;
		  
		  if (levelChanged) currentState <= RESET_ST;
		  else begin
	 


			  case (currentState)

				 RESET_ST: begin
					currentState <= pauseN ? START_WAIT_ST : PAUSED_ST;
				 end

				 START_WAIT_ST: begin
					if (!pauseN) currentState <= PAUSED_ST;
					else if (lastState != START_WAIT_ST) begin  // 1st enter
					  startCountN <= 1'b0;
					  datainL     <= TIME_START_L;
					  datainH     <= TIME_START_H;
					end else if (timerEnd) currentState <= PLAYING_ST;
				 end

				 PLAYING_ST: begin
					if (!pauseN) currentState <= PAUSED_ST;
					else if (collision_pac_ghost != 3'd0 && !recovering) currentState <= GHOST_HIT_ST;
					else if (currLives == 0) currentState <= LOSE_ST;
					else if (isWin) currentState <= WIN_ST; // if 0 heart caused by a pickUp
					else if (collision_pac_power_reg) currentState <= POWER_UP_ST;
				 end

				 GHOST_HIT_ST: begin
					if (!pauseN) currentState <= PAUSED_ST;
					else if (lastState != GHOST_HIT_ST) begin  // 1st enter
					  startCountN <= 1'b0;
					  datainL     <= TIME_START_L;
					  datainH     <= TIME_START_H;
					end else if (timerEnd) currentState <= (currLives > 1) ? PLAYING_ST : LOSE_ST;
				 end

				 POWER_UP_ST: begin
					if (!pauseN) currentState <= PAUSED_ST;
					else if (lastState != POWER_UP_ST || collision_pac_power_reg) begin  // 1st enter or re-enter
					  startCountN <= 1'b0;
					  datainL     <= TIME_POWER_L;
					  datainH     <= TIME_POWER_H;
					end else if (timerEnd)  // +2st enter
					  currentState <= PLAYING_ST;
				 end
				 
				 WIN_ST: begin
					if (!pauseN) currentState <= PAUSED_ST;
					else if (lastState != WIN_ST) begin  // 1st enter
					  startCountN <= 1'b0;
					  datainL     <= 10;
					  datainH     <= 0;
					end else if (timerEnd) currentState <= RESET_ST;
				 end
				 
				 LOSE_ST: begin
					if (!pauseN) currentState <= PAUSED_ST;
					else if (lastState != LOSE_ST) begin  // 1st enter
					  startCountN <= 1'b0;
					  datainL     <= 10;
					  datainH     <= 0;
					end else if (timerEnd) currentState <= RESET_ST;
				 end

	//          WIN_ST:  if (pauseN) currentState <= RESET_ST;
	//          LOSE_ST: if (pauseN) currentState <= RESET_ST; // CURRENTLY STACK AT WIN OR LOST

				 PAUSED_ST: begin
					currentState <= pauseN ? prePausedState : PAUSED_ST;
					if (lastState != PAUSED_ST) prePausedState <= lastState;
				 end

			  endcase
			end  
      end
    end
  end

  // Outputs
  assign gameState = currentState;
  assign gameStateFor7Seg = {1'b0, currentState};  // 3->4 bits
  assign score0 = totalScore % 10;
  assign score1 = (totalScore / 10) % 10;
  assign score2 = (totalScore / 100) % 10;

endmodule
