module pacman_game_controller (
    input  logic       clk,
    input  logic       resetN,
    input  logic       pauseN,        
    input  logic       startOfFrame,  
    input  logic       pacDR,
    input  logic       wallsDR,
    input  logic       coinDR,
    input  logic       powerDR,
    input  logic       blinkeyDR,
    input  logic       pinkeyDR,
    input  logic       inkyDR,
    input  logic       clydeDR,
    input  logic       oneSec,
    input  logic [8:0] coinsTot,

    output logic       collision_pac_wall,
    output logic       collision_pac_coin,
    output logic       collision_pac_power,
    output logic [2:0] collision_pac_ghost,

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

  localparam START_HEARTS = 4;

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
  logic [7:0]  stateCounter;
  logic [7:0]  powerPelletTimer;
  logic [9:0]  totalScore;
  logic        ghost_flag;
  logic        coin_flag;
  logic [8:0]  coinCollected;

  // Collision detection
  assign collision_pac_wall  = pacDR && wallsDR;
  assign collision_pac_coin  = pacDR && coinDR;
  assign collision_pac_power = pacDR && powerDR;

  always_comb begin
    collision_pac_ghost = 3'd0;
    if (pacDR) begin
      if      (blinkeyDR) collision_pac_ghost = 3'd1;
      else if (pinkeyDR)  collision_pac_ghost = 3'd2;
      else if (inkyDR)    collision_pac_ghost = 3'd3;
      else if (clydeDR)   collision_pac_ghost = 3'd4;
    end
  end

  // ------------------------------------------------------------------------
  // Single always_ff block FSM + timers + outputs
  // ------------------------------------------------------------------------
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      // Reset all state and outputs
      currentState     <= RESET_ST;
      lastState        <= RESET_ST;

      currLives        <= START_HEARTS;
      totalScore       <= 10'd0;
      stateCounter     <= 8'd0;
      powerPelletTimer <= 8'd0;

      coin_flag        <= 1'b0;
      coinCollected    <= 9'd0;
      ghost_flag       <= 1'b0;

      datainL          <= 4'd5;
      datainH          <= 4'd0;
      startCountN      <= 1'b0;
    end else begin
      // Default per frame
      coin_flag   <= 1'b0;
      ghost_flag  <= 1'b0;
      startCountN <= 1'b1;

      // Timers tick
      if (oneSec) begin
        if (stateCounter > 0)     stateCounter     <= stateCounter - 8'd1;
        if (powerPelletTimer > 0) powerPelletTimer <= powerPelletTimer - 8'd1;
      end

      // FSM updates on startOfFrame
      if (startOfFrame) begin
        lastState <= currentState;

        // Compute next state and update sequential outputs
        case (currentState)
          RESET_ST: begin
			 
			   // state
            currentState <= pauseN ? START_WAIT_ST : PAUSED_ST;
				
				// output
            currLives        <= START_HEARTS;
            totalScore       <= 10'd0;
            stateCounter     <= 8'd0;
            powerPelletTimer <= 8'd0;
            coinCollected    <= 9'd0;

            datainL     <= 4'd5;
            datainH     <= 4'd0;
            startCountN <= 1'b0;
          end

          START_WAIT_ST: begin
				
				// state
            if (!pauseN) currentState <= PAUSED_ST;
            else if (stateCounter == 0 && lastState == START_WAIT_ST) currentState <= PLAYING_ST;

            // output
				if (lastState != START_WAIT_ST) begin
              stateCounter <= 8'd3;
              datainL      <= 4'd3;
              datainH      <= 4'd0;
              startCountN  <= 1'b0;
            end
          end

          PLAYING_ST: begin
            if (!pauseN) currentState <= PAUSED_ST;
				else if (collision_pac_ghost != 3'd0) currentState <= GHOST_HIT_ST;
            else if (coinCollected == coinsTot) currentState <= WIN_ST; // win one frame after 
            else if (collision_pac_power) currentState <= POWER_UP_ST;

            // Coin collection
            if (collision_pac_coin && !coin_flag) begin
              coinCollected <= coinCollected + 1;
              coin_flag     <= 1'b1;
              totalScore <= totalScore +1;
            end
          end

          GHOST_HIT_ST: begin
				currentState <= (!pauseN) ? PAUSED_ST :
					 (currLives > 1) ? START_WAIT_ST : LOSE_ST;

            if (lastState != GHOST_HIT_ST && currLives > 0) 
              currLives <= currLives - 1;										 
          end

          POWER_UP_ST: begin
            if (!pauseN) currentState <= PAUSED_ST;
            else if (powerPelletTimer == 0) currentState <= PLAYING_ST;
				
				 if (lastState != POWER_UP_ST) begin
					 powerPelletTimer <= 8'd8;
					 datainL          <= 4'd8;
					 datainH          <= 4'd0;
					 startCountN      <= 1'b0;
				 end // DOES NOT COVER EATING ANOTHER POWER DURING ST
				 

				  // Ghost eaten
				 if (collision_pac_ghost != 3'd0 && !ghost_flag) begin
					 ghost_flag      <= 1'b1;
					 totalScore  <= totalScore + 50;
				 end

				  // Coin collected
				 if (collision_pac_coin && !coin_flag) begin
					 coinCollected   <= coinCollected + 1;
					 coin_flag       <= 1'b1;
					 totalScore  <= totalScore+ 1;
				 end
          end

          WIN_ST:  if (pauseN) currentState <= RESET_ST;
          LOSE_ST: if (pauseN) currentState <= RESET_ST;

          PAUSED_ST: begin
				currentState <= pauseN ? prePausedState : PAUSED_ST;
				if (lastState != PAUSED_ST) prePausedState <= lastState;
				
			 end
        endcase
		  
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
