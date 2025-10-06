module melody_selector (
    input logic clk,
    input logic resetN,
    input logic startOfFrame,
    
    // Game state
    input logic [2:0] gameState,
    
    // Event flags (up for 1 clock cycle)
    input logic coinFlag,
    input logic powFlag,
    input logic picUpFlag,
    input logic fruitSpawnPending,
    
    // Speed and life changes (up for 1 clock cycle)
    input logic [1:0] pacSpeedChange,  // 0=normal, 1=fast, 2=slow
    input logic [1:0] pacLifeChange,   // 0=no, 1=incr, 2=decr
    
    // Output to JukeBox
    output logic [3:0] melodySelect
);

  // Game states
  localparam RESET_ST      = 3'b000;
  localparam START_WAIT_ST = 3'b001;
  localparam PLAYING_ST    = 3'b010;
  localparam PAUSED_ST     = 3'b011;
  localparam GHOST_HIT_ST  = 3'b100;
  localparam WIN_ST        = 3'b101;
  localparam LOSE_ST       = 3'b110;
  localparam POWER_UP_ST   = 3'b111;

  // Melody indices (matching JukeBox1)
  localparam MELODY_GAME_START     = 4'd0;  // Game intro
  localparam MELODY_BACKGROUND     = 4'd1;  // Wakka-wakka loop
  localparam MELODY_COIN           = 4'd2;  // Coin eating
  localparam MELODY_POWER_MODE     = 4'd3;  // Power pellet active
  localparam MELODY_DEATH          = 4'd4;  // Pac-Man death
  localparam MELODY_EAT_GHOST      = 4'd5;  // Eating a ghost
  localparam MELODY_GHOST_RETREAT  = 4'd6;  // Ghost eyes retreating
  localparam MELODY_LEVEL_COMPLETE = 4'd7;  // Level finished
  localparam MELODY_FRUIT_APPEAR   = 4'd8;  // Fruit spawns
  localparam MELODY_EXTRA_LIFE     = 4'd9;  // Extra life gained
  localparam MELODY_SILENCE        = 4'd10; // No sound

  // Internal registers
  logic [2:0] lastGameState;
  logic [3:0] currentMelody;
  logic [3:0] nextMelody;

  // Priority-based melody selection (combinational)
  always_comb begin
    nextMelody = currentMelody; // Default: keep current melody
    
    // Priority 1: Life events (highest priority for short sounds)
    if (pacLifeChange == 2'd1) begin
      nextMelody = MELODY_EXTRA_LIFE;
    end
    else if (pacLifeChange == 2'd2) begin
      nextMelody = MELODY_DEATH; // Life lost
    end
    
    // Priority 2: Ghost eaten (during power mode)
    else if (gameState == POWER_UP_ST && picUpFlag) begin
      nextMelody = MELODY_EAT_GHOST;
    end
    
    // Priority 3: State-based events
    else begin
      case (gameState)
        
        RESET_ST: begin
          nextMelody = MELODY_SILENCE;
        end
        
        START_WAIT_ST: begin
			 nextMelody = MELODY_GAME_START;
        end
        
        PLAYING_ST: begin
          // Priority 4: Short event sounds during gameplay
          if (fruitSpawnPending) begin
            nextMelody = MELODY_FRUIT_APPEAR;
          end
          else if (coinFlag) begin
            nextMelody = MELODY_COIN;
          end
          else if (powFlag) begin
            nextMelody = MELODY_POWER_MODE; // Transition to power mode
          end
          else begin
            // Default gameplay music
            nextMelody = MELODY_BACKGROUND;
          end
        end
        
        POWER_UP_ST: begin
          // During power mode, play power music unless eating something
          if (coinFlag) begin
            nextMelody = MELODY_COIN;
          end
          else begin
            nextMelody = MELODY_POWER_MODE;
          end
        end
        
        GHOST_HIT_ST: begin
          nextMelody = MELODY_DEATH;
        end
        
        WIN_ST: begin
          if (lastGameState != WIN_ST) begin
            nextMelody = MELODY_LEVEL_COMPLETE;
          end else begin
            nextMelody = MELODY_LEVEL_COMPLETE; // Keep playing
          end
        end
        
        LOSE_ST: begin
          if (lastGameState != LOSE_ST) begin
            nextMelody = MELODY_DEATH;
          end else begin
            nextMelody = MELODY_SILENCE; // After death sound finishes
          end
        end
        
        PAUSED_ST: begin
          nextMelody = MELODY_SILENCE;
        end
        
        default: begin
          nextMelody = MELODY_SILENCE;
        end
        
      endcase
    end
  end

  // Sequential logic: Update melody at frame boundaries
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      currentMelody <= MELODY_SILENCE;
      lastGameState <= RESET_ST;
    end else begin
      currentMelody <= nextMelody;
      lastGameState <= gameState;
    end
  end

  // Output assignment
  assign melodySelect = currentMelody;

endmodule