module melody_selector (
    input logic clk,
    input logic resetN,
    input logic startOfFrame,

    // Game state
    input logic [2:0] gameState,

    // Event flags (1-cycle pulses, made sticky until startOfFrame)
    input logic coinFlag,
    input logic powFlag,
    input logic fruitSpawn,
    input logic ghostFlag,
    input logic [2:0] pickupType,  // 0=none, 1=cherry, 2=banana, 3=strawberry, 4=poison, 5=penalty
    input logic pickupCollectedFlag,
    input logic [1:0] pacLifeChange,  // 0=none, 1=+1, 2=-1

    // Output to JukeBox
    output logic [3:0] melodySelect
);

  // Game states
  localparam RESET_ST = 3'b000;
  localparam START_WAIT_ST = 3'b001;
  localparam PLAYING_ST = 3'b010;
  localparam PAUSED_ST = 3'b011;
  localparam GHOST_HIT_ST = 3'b100;
  localparam WIN_ST = 3'b101;
  localparam LOSE_ST = 3'b110;
  localparam POWER_UP_ST = 3'b111;

  // Melody indices (matching JukeBox)
  localparam MELODY_GAME_START = 4'd0;
  localparam MELODY_WIN = 4'd1;
  localparam MELODY_LOSE = 4'd2;
  localparam MELODY_LIFE_LOST = 4'd3;
  localparam MELODY_LIFE_GAINED = 4'd4;
  localparam MELODY_PICKUP_CHERRY = 4'd5;
  localparam MELODY_PICKUP_BANANA = 4'd6;
  localparam MELODY_PICKUP_STRAW = 4'd7;
  localparam MELODY_PICKUP_POISON = 4'd8;
  localparam MELODY_PICKUP_PENALTY = 4'd9;
  localparam MELODY_FRUIT_APPEAR = 4'd10;
  localparam MELODY_EAT_GHOST = 4'd11;
  localparam MELODY_POWER_MODE = 4'd12;
  localparam MELODY_COIN = 4'd13;
  localparam MELODY_SILENCE = 4'd15;

  // Internal registers
  logic [2:0] lastGameState;
  logic [3:0] currentMelody;
  logic [3:0] nextMelody;
  
  // Sticky event flags (hold until processed at startOfFrame)
  logic coinFlag_sticky;
  logic powFlag_sticky;
  logic fruitSpawn_sticky;
  logic ghostFlag_sticky;
  logic pickupCollectedFlag_sticky;
  logic [2:0] pickupType_sticky;
  logic [1:0] pacLifeChange_sticky;

  // Make flags sticky until startOfFrame
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      coinFlag_sticky <= 1'b0;
      powFlag_sticky <= 1'b0;
      fruitSpawn_sticky <= 1'b0;
      ghostFlag_sticky <= 1'b0;
      pickupCollectedFlag_sticky <= 1'b0;
      pickupType_sticky <= 3'd0;
      pacLifeChange_sticky <= 2'd0;
    end else begin
      // Set flags when events occur
      if (coinFlag) coinFlag_sticky <= 1'b1;
      if (powFlag) powFlag_sticky <= 1'b1;
      if (fruitSpawn) fruitSpawn_sticky <= 1'b1;
      if (ghostFlag) ghostFlag_sticky <= 1'b1;
      if (pickupCollectedFlag) begin
        pickupCollectedFlag_sticky <= 1'b1;
        pickupType_sticky <= pickupType;
      end
      if (pacLifeChange != 2'd0) pacLifeChange_sticky <= pacLifeChange;
      
      // Clear flags at start of frame after processing
      if (startOfFrame) begin
        coinFlag_sticky <= 1'b0;
        powFlag_sticky <= 1'b0;
        fruitSpawn_sticky <= 1'b0;
        ghostFlag_sticky <= 1'b0;
        pickupCollectedFlag_sticky <= 1'b0;
        pickupType_sticky <= 3'd0;
        pacLifeChange_sticky <= 2'd0;
      end
    end
  end

  // Priority-based melody selection (combinational)
  always_comb begin
    nextMelody = currentMelody;  // Default: keep current melody
    
    // Highest priority: Life events
    if (pacLifeChange_sticky == 2'd1) begin
      nextMelody = MELODY_LIFE_GAINED;
    end
    else if (pacLifeChange_sticky == 2'd2) begin
      nextMelody = MELODY_LIFE_LOST;
    end
    // Second priority: Pickup collected
    else if (pickupCollectedFlag_sticky) begin
      case (pickupType_sticky)
        3'd1: nextMelody = MELODY_PICKUP_CHERRY;
        3'd2: nextMelody = MELODY_PICKUP_BANANA;
        3'd3: nextMelody = MELODY_PICKUP_STRAW;
        3'd4: nextMelody = MELODY_PICKUP_POISON;
        3'd5: nextMelody = MELODY_PICKUP_PENALTY;
        default: nextMelody = currentMelody;
      endcase
    end
    // Third priority: Ghost eaten
    else if (ghostFlag_sticky) begin
      nextMelody = MELODY_EAT_GHOST;
    end
    // Fourth priority: State-based sounds
    else begin
      case (gameState)
        RESET_ST: begin
          nextMelody = MELODY_SILENCE;
        end

        START_WAIT_ST: begin
          // Play game start only when entering this state
          if (lastGameState != START_WAIT_ST) begin
            nextMelody = MELODY_GAME_START;
          end
          // Otherwise keep playing game start or silence
        end

        PLAYING_ST: begin
          // Event-based sounds
          if (fruitSpawn_sticky) begin
            nextMelody = MELODY_FRUIT_APPEAR;
          end
          else if (coinFlag_sticky) begin
            nextMelody = MELODY_COIN;
          end
          else if (powFlag_sticky) begin
            nextMelody = MELODY_POWER_MODE;
          end
          else begin
            // No events - silence (or you could add background music here)
            nextMelody = MELODY_SILENCE;
          end
        end

        PAUSED_ST: begin
          nextMelody = MELODY_SILENCE;
        end

        GHOST_HIT_ST: begin
          // Play life lost sound when entering this state
          if (lastGameState != GHOST_HIT_ST) begin
            nextMelody = MELODY_LIFE_LOST;
          end
        end

        WIN_ST: begin
          // Play win sound when entering this state
          if (lastGameState != WIN_ST) begin
            nextMelody = MELODY_WIN;
          end
        end

        LOSE_ST: begin
          // Play lose sound when entering this state
          if (lastGameState != LOSE_ST) begin
            nextMelody = MELODY_LOSE;
          end
        end

        POWER_UP_ST: begin
          // Power mode background music (loops)
          // Unless an event overrides it (handled by priorities above)
          if (lastGameState != POWER_UP_ST) begin
            // Just entered power mode
            nextMelody = MELODY_POWER_MODE;
          end
          else if (currentMelody != MELODY_POWER_MODE && 
                   !pickupCollectedFlag_sticky && 
                   !ghostFlag_sticky && 
                   pacLifeChange_sticky == 2'd0) begin
            // Return to power mode music after event sounds
            nextMelody = MELODY_POWER_MODE;
          end
        end

        default: begin
          nextMelody = MELODY_SILENCE;
        end
      endcase
    end
  end

  // Sequential logic: Update melody ONLY at frame boundaries
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      currentMelody <= MELODY_SILENCE;
      lastGameState <= RESET_ST;
    end else if (startOfFrame) begin  // KEY FIX: Only update on startOfFrame!
      currentMelody <= nextMelody;
      lastGameState <= gameState;
    end
  end

  // Output assignment
  assign melodySelect = currentMelody;

endmodule