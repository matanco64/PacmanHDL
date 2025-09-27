module pacman_game_controller (
    input logic       clk,
    input logic       resetN,
    input logic       pauseN,
    input logic       startOfFrame,
    input logic       pacDR,
    input logic       wallsDR,
    input logic       coinDR,
    input logic       powerDR,
    input logic       blinkeyDR,
    input logic       pinkeyDR,
    input logic       inkyDR,
    input logic       clydeDR,
    input logic       oneSec,
	 input logic		 timerEnd,
    input logic [8:0] coinsPowTot,
    input logic [8:0] coinsCollected,
    input logic [8:0] powCollected,

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

  localparam START_HEARTS = 3;

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

  logic       ghost_flag;
  
  logic [5:0] ghostEaten;
  logic [9:0] totalScore;

  // Collision detection
  assign collision_pac_wall = pacDR && wallsDR;
  assign collision_pac_coin = pacDR && coinDR;
  assign collision_pac_power = pacDR && powerDR;  // for map
  assign totalScore = coinsCollected + (ghostEaten * 50) + (powCollected * 10);

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
      ghost_flag <= 1'b0;
      currLives  <= START_HEARTS;
      ghostEaten <= 0;

    end else if (currentState == RESET_ST) begin
      ghost_flag <= 1'b0;
      currLives  <= START_HEARTS;
      ghostEaten <= 0;
    end else begin

      if (startOfFrame) ghost_flag <= 1'b0;

      if (collision_pac_ghost != 3'd0 && !ghost_flag) begin
        ghost_flag <= 1'b1;
        if (currentState == PLAYING_ST) begin
          currLives <= (currLives > 0) ? currLives - 1 : 0;
        end else if (currentState == POWER_UP_ST) begin
          ghostEaten <= ghostEaten + 1;
        end
      end

    end
  end

  // sticky logic - up for frame
  logic collision_pac_power_reg;
  logic timerEnd_reg;

	 always_ff @(posedge clk or negedge resetN) begin
	  if (!resetN) begin
		 collision_pac_power_reg <= 1'b0;
		 timerEnd_reg <= 1'b0;
	  end else begin

		 if (startOfFrame) collision_pac_power_reg <= 1'b0;  // clear at the start of frame
		 else if (pacDR && powerDR) collision_pac_power_reg <= 1'b1;

		 if (startOfFrame) timerEnd_reg <= 1'b0;
		 else if (timerEnd) timerEnd_reg <= 1'b1;

	  end
	end

  // ------------------------------------------------------------
  // Sequential FSM and counters
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      currentState     <= RESET_ST;
      lastState        <= RESET_ST;
      prePausedState   <= RESET_ST;

      startCountN      <= 1'b1;  // no counting
      datainL          <= 4'd0;
      datainH          <= 4'd0;

    end else begin
      // default
      startCountN <= 1'b1;

      // State machine updates once per frame
      if (startOfFrame) begin
        lastState <= currentState;


        case (currentState)

          RESET_ST: begin
            currentState <= pauseN ? START_WAIT_ST : PAUSED_ST;
          end

          START_WAIT_ST: begin
            if (!pauseN) currentState <= PAUSED_ST;
            else if (timerEnd_reg && lastState == START_WAIT_ST) currentState <= PLAYING_ST;

            if (lastState != START_WAIT_ST) begin

              startCountN  <= 1'b0;
              datainL      <= TIME_START_L;
              datainH      <= TIME_START_H;

            end
          end

          PLAYING_ST: begin
            if (!pauseN) currentState <= PAUSED_ST;
            else if (collision_pac_ghost != 3'd0) currentState <= GHOST_HIT_ST;
            else if (coinsCollected + powCollected == coinsPowTot) currentState <= WIN_ST;
            else if (collision_pac_power_reg) currentState <= POWER_UP_ST;
          end

          GHOST_HIT_ST: begin
            currentState <= (!pauseN) ? PAUSED_ST : (currLives > 1) ? START_WAIT_ST : LOSE_ST;
          end

          POWER_UP_ST: begin
            if (!pauseN) currentState <= PAUSED_ST;
            if (lastState != POWER_UP_ST || collision_pac_power_reg) begin  // 1st enter or re-enter
              startCountN      <= 1'b0;
              datainL          <= TIME_POWER_L;
              datainH          <= TIME_POWER_H;

            end else if (timerEnd_reg)   // +2st enter
              currentState <= PLAYING_ST;
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
