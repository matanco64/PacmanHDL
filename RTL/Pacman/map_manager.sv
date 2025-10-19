module map_manager (
    input logic clk,
    input logic resetN,
    input logic [2:0] gameState,
    input logic [7:0] rnd,

    output logic [0:MAP_WIDTH_X-1][0:MAP_HEIGHT_Y-1][TILE_BITS-1:0] currentMap,
    output logic [8:0] coinsPowTot
);

  // map
  parameter MAP_WIDTH_X = 31;
  parameter MAP_HEIGHT_Y = 28;
  parameter TILE_BITS = 4;

  localparam N_NEW_MAPS = 4;
  localparam MAX_CHANGES = 128;
  // game state
  localparam RESET_ST = 3'b000;
  localparam logic [N_NEW_MAPS:0][8:0] COINS_POW_TOT = '{
      300,
      322,
      326,
      354,
      318
  };  // original, map 1 2 3 4


// # ===================== Summary =====================
// # Map 0: 62 changes | Total coins & power: 322
// # Map 1: 110 changes | Total coins & power: 326
// # Map 2: 122 changes | Total coins & power: 354
// # Map 3: 66 changes | Total coins & power: 318
// # ====================================================


  integer i;
  logic [2:0] currentMapIndex;  // 0=original, map 1 2 3 4 
  logic [1:0] newMapIdx;  // 0=map1 1=map2 .... 3=map4

  assign coinsPowTot = COINS_POW_TOT[currentMapIndex];  // 0=original, map 1 2 3 4
  assign newMapIdx   = currentMapIndex - 1;

  
logic [0:MAP_WIDTH_X-1][0:MAP_HEIGHT_Y-1][TILE_BITS-1:0] OriginalPacmanMap = { // Since we are mutating the Original Map when coins are eaten, we want an ability to reset it
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2, 4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd3, 4'd0, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd4, 4'd0, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd3, 4'd0, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd0, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd0, 4'd4 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd3, 4'd0, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2 },
    { 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd2 },
    { 4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2 },
    { 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 }
  };
  
	 
// ======================== Change Arrays ========================
localparam logic [N_NEW_MAPS-1:0][MAX_CHANGES-1:0][7:0] changeX = '{
    // Map 0 (62 real changes + 66 zeros)
    '{
       8'd2, 8'd2, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
       8'd3, 8'd3, 8'd3, 8'd3, 8'd4, 8'd4, 8'd8, 8'd8,
       8'd8, 8'd8, 8'd9, 8'd9, 8'd9, 8'd9, 8'd9, 8'd9,
       8'd9, 8'd9, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10,
       8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd18, 8'd18,
       8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18,
       8'd19, 8'd19, 8'd19, 8'd19, 8'd19, 8'd19, 8'd20, 8'd20,
       8'd25, 8'd25, 8'd25, 8'd25, 8'd29, 8'd29, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    },
    // Map 1 (110 real changes + 18 zeros)
    '{
       8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1,
       8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd2, 8'd2,
       8'd2, 8'd2, 8'd2, 8'd2, 8'd3, 8'd3, 8'd3, 8'd3,
       8'd4, 8'd4, 8'd4, 8'd4, 8'd9, 8'd9, 8'd10, 8'd10,
       8'd10, 8'd10, 8'd11, 8'd11, 8'd11, 8'd11, 8'd12, 8'd12,
       8'd12, 8'd12, 8'd13, 8'd13, 8'd15, 8'd15, 8'd16, 8'd16,
       8'd16, 8'd16, 8'd17, 8'd17, 8'd17, 8'd17, 8'd18, 8'd18,
       8'd18, 8'd18, 8'd19, 8'd19, 8'd19, 8'd19, 8'd19, 8'd19,
       8'd21, 8'd21, 8'd21, 8'd21, 8'd22, 8'd22, 8'd22, 8'd22,
       8'd23, 8'd23, 8'd23, 8'd23, 8'd24, 8'd24, 8'd24, 8'd24,
       8'd25, 8'd25, 8'd25, 8'd25, 8'd26, 8'd26, 8'd26, 8'd26,
       8'd26, 8'd26, 8'd26, 8'd26, 8'd26, 8'd26, 8'd26, 8'd26,
       8'd26, 8'd26, 8'd27, 8'd27, 8'd27, 8'd27, 8'd27, 8'd27,
       8'd27, 8'd27, 8'd28, 8'd28, 8'd29, 8'd29, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    },
    // Map 2 (122 real changes + 6 zeros)
    '{
       8'd1, 8'd1, 8'd2, 8'd2, 8'd2, 8'd2, 8'd3, 8'd3,
       8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
       8'd3, 8'd3, 8'd4, 8'd4, 8'd4, 8'd4, 8'd5, 8'd5,
       8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd5, 8'd6, 8'd6,
       8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd6, 8'd9, 8'd9,
       8'd9, 8'd9, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10,
       8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd11, 8'd11,
       8'd11, 8'd11, 8'd11, 8'd11, 8'd11, 8'd11, 8'd11, 8'd11,
       8'd12, 8'd12, 8'd12, 8'd12, 8'd12, 8'd12, 8'd12, 8'd12,
       8'd12, 8'd12, 8'd13, 8'd13, 8'd15, 8'd15, 8'd16, 8'd16,
       8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16,
       8'd17, 8'd17, 8'd17, 8'd17, 8'd17, 8'd17, 8'd17, 8'd17,
       8'd17, 8'd17, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18,
       8'd18, 8'd18, 8'd18, 8'd18, 8'd19, 8'd19, 8'd20, 8'd20,
       8'd21, 8'd21, 8'd21, 8'd21, 8'd22, 8'd22, 8'd22, 8'd22,
       8'd23, 8'd23, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    },
    // Map 3 (66 real changes + 62 zeros)
    '{
       8'd1, 8'd1, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3, 8'd3,
       8'd3, 8'd3, 8'd3, 8'd3, 8'd5, 8'd5, 8'd7, 8'd7,
       8'd8, 8'd8, 8'd9, 8'd9, 8'd10, 8'd10, 8'd12, 8'd12,
       8'd13, 8'd13, 8'd13, 8'd13, 8'd14, 8'd14, 8'd14, 8'd14,
       8'd15, 8'd15, 8'd15, 8'd15, 8'd16, 8'd16, 8'd18, 8'd18,
       8'd19, 8'd19, 8'd21, 8'd21, 8'd24, 8'd25, 8'd27, 8'd27,
       8'd27, 8'd27, 8'd27, 8'd27, 8'd28, 8'd28, 8'd28, 8'd28,
       8'd29, 8'd29, 8'd29, 8'd29, 8'd29, 8'd29, 8'd29, 8'd29,
       8'd29, 8'd29, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    }
};

localparam logic [N_NEW_MAPS-1:0][MAX_CHANGES-1:0][7:0] changeY = '{
    // Map 0
    '{
       8'd9, 8'd18, 8'd2, 8'd3, 8'd7, 8'd8, 8'd9, 8'd18,
       8'd19, 8'd20, 8'd24, 8'd25, 8'd3, 8'd24, 8'd2, 8'd13,
       8'd14, 8'd25, 8'd1, 8'd2, 8'd3, 8'd12, 8'd15, 8'd24,
       8'd25, 8'd26, 8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd12,
       8'd15, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27, 8'd0, 8'd1,
       8'd2, 8'd3, 8'd4, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27,
       8'd1, 8'd2, 8'd3, 8'd24, 8'd25, 8'd26, 8'd2, 8'd25,
       8'd7, 8'd8, 8'd19, 8'd20, 8'd13, 8'd14, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    },
    // Map 1
    '{
       8'd7, 8'd8, 8'd9, 8'd10, 8'd11, 8'd12, 8'd13, 8'd14,
       8'd15, 8'd16, 8'd17, 8'd18, 8'd19, 8'd20, 8'd8, 8'd9,
       8'd10, 8'd17, 8'd18, 8'd19, 8'd8, 8'd10, 8'd17, 8'd19,
       8'd8, 8'd10, 8'd17, 8'd19, 8'd4, 8'd23, 8'd3, 8'd4,
       8'd23, 8'd24, 8'd3, 8'd4, 8'd23, 8'd24, 8'd3, 8'd4,
       8'd23, 8'd24, 8'd4, 8'd23, 8'd4, 8'd23, 8'd3, 8'd4,
       8'd23, 8'd24, 8'd3, 8'd4, 8'd23, 8'd24, 8'd3, 8'd4,
       8'd23, 8'd24, 8'd4, 8'd12, 8'd13, 8'd14, 8'd15, 8'd23,
       8'd4, 8'd6, 8'd21, 8'd23, 8'd4, 8'd6, 8'd21, 8'd23,
       8'd1, 8'd4, 8'd23, 8'd26, 8'd3, 8'd9, 8'd18, 8'd24,
       8'd3, 8'd9, 8'd18, 8'd24, 8'd1, 8'd4, 8'd5, 8'd9,
       8'd10, 8'd11, 8'd13, 8'd14, 8'd16, 8'd17, 8'd18, 8'd22,
       8'd23, 8'd26, 8'd3, 8'd4, 8'd5, 8'd6, 8'd21, 8'd22,
       8'd23, 8'd24, 8'd3, 8'd24, 8'd1, 8'd26, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    },
    // Map 2
    '{
       8'd1, 8'd26, 8'd3, 8'd6, 8'd21, 8'd24, 8'd3, 8'd7,
       8'd8, 8'd9, 8'd10, 8'd11, 8'd16, 8'd17, 8'd18, 8'd19,
       8'd20, 8'd24, 8'd2, 8'd3, 8'd24, 8'd25, 8'd2, 8'd3,
       8'd4, 8'd5, 8'd22, 8'd23, 8'd24, 8'd25, 8'd2, 8'd3,
       8'd4, 8'd5, 8'd22, 8'd23, 8'd24, 8'd25, 8'd1, 8'd12,
       8'd15, 8'd26, 8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd12,
       8'd15, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27, 8'd0, 8'd1,
       8'd2, 8'd3, 8'd4, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27,
       8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd23, 8'd24, 8'd25,
       8'd26, 8'd27, 8'd4, 8'd23, 8'd2, 8'd25, 8'd0, 8'd1,
       8'd2, 8'd3, 8'd4, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27,
       8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd23, 8'd24, 8'd25,
       8'd26, 8'd27, 8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd23,
       8'd24, 8'd25, 8'd26, 8'd27, 8'd4, 8'd23, 8'd13, 8'd14,
       8'd6, 8'd12, 8'd15, 8'd21, 8'd6, 8'd12, 8'd15, 8'd21,
       8'd13, 8'd14, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    },
    // Map 3
    '{
       8'd12, 8'd15, 8'd7, 8'd8, 8'd9, 8'd10, 8'd11, 8'd16,
       8'd17, 8'd18, 8'd19, 8'd20, 8'd13, 8'd14, 8'd2, 8'd25,
       8'd1, 8'd26, 8'd13, 8'd14, 8'd12, 8'd15, 8'd4, 8'd23,
       8'd5, 8'd16, 8'd17, 8'd22, 8'd15, 8'd19, 8'd20, 8'd21,
       8'd5, 8'd16, 8'd17, 8'd22, 8'd4, 8'd23, 8'd4, 8'd23,
       8'd5, 8'd22, 8'd13, 8'd14, 8'd18, 8'd18, 8'd6, 8'd9,
       8'd13, 8'd14, 8'd18, 8'd21, 8'd6, 8'd9, 8'd18, 8'd21,
       8'd1, 8'd4, 8'd7, 8'd8, 8'd13, 8'd14, 8'd19, 8'd20,
       8'd22, 8'd26, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0,
       8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0
    }
};

localparam logic [N_NEW_MAPS-1:0][MAX_CHANGES-1:0][TILE_BITS-1:0] changeVal = '{
    // Map 0
    '{
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2
    },
    // Map 1
    '{
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd5, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd1, 4'd5, 4'd2, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd5, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd5, 4'd1, 4'd1, 4'd5, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd5, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd5, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2
    },
    // Map 2
    '{
       4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd5,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd5, 4'd1, 4'd1, 4'd5, 4'd5, 4'd1, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd1, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2,
       4'd2, 4'd1, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2,
       4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd2, 4'd2, 4'd1, 4'd5, 4'd2, 4'd2, 4'd1, 4'd2,
       4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd2,
       4'd2, 4'd1, 4'd2, 4'd2, 4'd5, 4'd1, 4'd2, 4'd2,
       4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd2, 4'd1, 4'd1, 4'd1, 4'd1,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd5, 4'd5, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2
    },
    // Map 3
    '{
       4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd1, 4'd1, 4'd1,
       4'd1, 4'd5, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1,
       4'd2, 4'd2, 4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd1, 4'd5, 4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd1, 4'd5, 4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1, 4'd1,
       4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd5, 4'd1,
       4'd1, 4'd5, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd5, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2
    }
};




  // ========Main state machine================================
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      // Load the original map on reset
      currentMap <= OriginalPacmanMap;
      currentMapIndex <= 2'd0;
    end else if (gameState == RESET_ST) begin
      // Start from the base map
      currentMap <= OriginalPacmanMap;

      if(currentMapIndex != 0) begin // not the original map
        //   for (i = 0; i < MAX_CHANGES; i++) begin
        //     currentMap[changeX[newMapIdx][i]][changeY[newMapIdx][i]] <= changeVal[newMapIdx][i];
        //   end

        // Static manual assignment for Quartus compatibility (no loops)
        currentMap[changeX[newMapIdx][0]][changeY[newMapIdx][0]] <= changeVal[newMapIdx][0];
        currentMap[changeX[newMapIdx][1]][changeY[newMapIdx][1]] <= changeVal[newMapIdx][1];
        currentMap[changeX[newMapIdx][2]][changeY[newMapIdx][2]] <= changeVal[newMapIdx][2];
        currentMap[changeX[newMapIdx][3]][changeY[newMapIdx][3]] <= changeVal[newMapIdx][3];
        currentMap[changeX[newMapIdx][4]][changeY[newMapIdx][4]] <= changeVal[newMapIdx][4];
        currentMap[changeX[newMapIdx][5]][changeY[newMapIdx][5]] <= changeVal[newMapIdx][5];
        currentMap[changeX[newMapIdx][6]][changeY[newMapIdx][6]] <= changeVal[newMapIdx][6];
        currentMap[changeX[newMapIdx][7]][changeY[newMapIdx][7]] <= changeVal[newMapIdx][7];
        currentMap[changeX[newMapIdx][8]][changeY[newMapIdx][8]] <= changeVal[newMapIdx][8];
        currentMap[changeX[newMapIdx][9]][changeY[newMapIdx][9]] <= changeVal[newMapIdx][9];
        currentMap[changeX[newMapIdx][10]][changeY[newMapIdx][10]] <= changeVal[newMapIdx][10];
        currentMap[changeX[newMapIdx][11]][changeY[newMapIdx][11]] <= changeVal[newMapIdx][11];
        currentMap[changeX[newMapIdx][12]][changeY[newMapIdx][12]] <= changeVal[newMapIdx][12];
        currentMap[changeX[newMapIdx][13]][changeY[newMapIdx][13]] <= changeVal[newMapIdx][13];
        currentMap[changeX[newMapIdx][14]][changeY[newMapIdx][14]] <= changeVal[newMapIdx][14];
        currentMap[changeX[newMapIdx][15]][changeY[newMapIdx][15]] <= changeVal[newMapIdx][15];
        currentMap[changeX[newMapIdx][16]][changeY[newMapIdx][16]] <= changeVal[newMapIdx][16];
        currentMap[changeX[newMapIdx][17]][changeY[newMapIdx][17]] <= changeVal[newMapIdx][17];
        currentMap[changeX[newMapIdx][18]][changeY[newMapIdx][18]] <= changeVal[newMapIdx][18];
        currentMap[changeX[newMapIdx][19]][changeY[newMapIdx][19]] <= changeVal[newMapIdx][19];
        currentMap[changeX[newMapIdx][20]][changeY[newMapIdx][20]] <= changeVal[newMapIdx][20];
        currentMap[changeX[newMapIdx][21]][changeY[newMapIdx][21]] <= changeVal[newMapIdx][21];
        currentMap[changeX[newMapIdx][22]][changeY[newMapIdx][22]] <= changeVal[newMapIdx][22];
        currentMap[changeX[newMapIdx][23]][changeY[newMapIdx][23]] <= changeVal[newMapIdx][23];
        currentMap[changeX[newMapIdx][24]][changeY[newMapIdx][24]] <= changeVal[newMapIdx][24];
        currentMap[changeX[newMapIdx][25]][changeY[newMapIdx][25]] <= changeVal[newMapIdx][25];
        currentMap[changeX[newMapIdx][26]][changeY[newMapIdx][26]] <= changeVal[newMapIdx][26];
        currentMap[changeX[newMapIdx][27]][changeY[newMapIdx][27]] <= changeVal[newMapIdx][27];
        currentMap[changeX[newMapIdx][28]][changeY[newMapIdx][28]] <= changeVal[newMapIdx][28];
        currentMap[changeX[newMapIdx][29]][changeY[newMapIdx][29]] <= changeVal[newMapIdx][29];
        currentMap[changeX[newMapIdx][30]][changeY[newMapIdx][30]] <= changeVal[newMapIdx][30];
        currentMap[changeX[newMapIdx][31]][changeY[newMapIdx][31]] <= changeVal[newMapIdx][31];
        currentMap[changeX[newMapIdx][32]][changeY[newMapIdx][32]] <= changeVal[newMapIdx][32];
        currentMap[changeX[newMapIdx][33]][changeY[newMapIdx][33]] <= changeVal[newMapIdx][33];
        currentMap[changeX[newMapIdx][34]][changeY[newMapIdx][34]] <= changeVal[newMapIdx][34];
        currentMap[changeX[newMapIdx][35]][changeY[newMapIdx][35]] <= changeVal[newMapIdx][35];
        currentMap[changeX[newMapIdx][36]][changeY[newMapIdx][36]] <= changeVal[newMapIdx][36];
        currentMap[changeX[newMapIdx][37]][changeY[newMapIdx][37]] <= changeVal[newMapIdx][37];
        currentMap[changeX[newMapIdx][38]][changeY[newMapIdx][38]] <= changeVal[newMapIdx][38];
        currentMap[changeX[newMapIdx][39]][changeY[newMapIdx][39]] <= changeVal[newMapIdx][39];
        currentMap[changeX[newMapIdx][40]][changeY[newMapIdx][40]] <= changeVal[newMapIdx][40];
        currentMap[changeX[newMapIdx][41]][changeY[newMapIdx][41]] <= changeVal[newMapIdx][41];
        currentMap[changeX[newMapIdx][42]][changeY[newMapIdx][42]] <= changeVal[newMapIdx][42];
        currentMap[changeX[newMapIdx][43]][changeY[newMapIdx][43]] <= changeVal[newMapIdx][43];
        currentMap[changeX[newMapIdx][44]][changeY[newMapIdx][44]] <= changeVal[newMapIdx][44];
        currentMap[changeX[newMapIdx][45]][changeY[newMapIdx][45]] <= changeVal[newMapIdx][45];
        currentMap[changeX[newMapIdx][46]][changeY[newMapIdx][46]] <= changeVal[newMapIdx][46];
        currentMap[changeX[newMapIdx][47]][changeY[newMapIdx][47]] <= changeVal[newMapIdx][47];
        currentMap[changeX[newMapIdx][48]][changeY[newMapIdx][48]] <= changeVal[newMapIdx][48];
        currentMap[changeX[newMapIdx][49]][changeY[newMapIdx][49]] <= changeVal[newMapIdx][49];
        currentMap[changeX[newMapIdx][50]][changeY[newMapIdx][50]] <= changeVal[newMapIdx][50];
        currentMap[changeX[newMapIdx][51]][changeY[newMapIdx][51]] <= changeVal[newMapIdx][51];
        currentMap[changeX[newMapIdx][52]][changeY[newMapIdx][52]] <= changeVal[newMapIdx][52];
        currentMap[changeX[newMapIdx][53]][changeY[newMapIdx][53]] <= changeVal[newMapIdx][53];
        currentMap[changeX[newMapIdx][54]][changeY[newMapIdx][54]] <= changeVal[newMapIdx][54];
        currentMap[changeX[newMapIdx][55]][changeY[newMapIdx][55]] <= changeVal[newMapIdx][55];
        currentMap[changeX[newMapIdx][56]][changeY[newMapIdx][56]] <= changeVal[newMapIdx][56];
        currentMap[changeX[newMapIdx][57]][changeY[newMapIdx][57]] <= changeVal[newMapIdx][57];
        currentMap[changeX[newMapIdx][58]][changeY[newMapIdx][58]] <= changeVal[newMapIdx][58];
        currentMap[changeX[newMapIdx][59]][changeY[newMapIdx][59]] <= changeVal[newMapIdx][59];
        currentMap[changeX[newMapIdx][60]][changeY[newMapIdx][60]] <= changeVal[newMapIdx][60];
        currentMap[changeX[newMapIdx][61]][changeY[newMapIdx][61]] <= changeVal[newMapIdx][61];
        currentMap[changeX[newMapIdx][62]][changeY[newMapIdx][62]] <= changeVal[newMapIdx][62];
        currentMap[changeX[newMapIdx][63]][changeY[newMapIdx][63]] <= changeVal[newMapIdx][63];
        currentMap[changeX[newMapIdx][64]][changeY[newMapIdx][64]] <= changeVal[newMapIdx][64];
        currentMap[changeX[newMapIdx][65]][changeY[newMapIdx][65]] <= changeVal[newMapIdx][65];
        currentMap[changeX[newMapIdx][66]][changeY[newMapIdx][66]] <= changeVal[newMapIdx][66];
        currentMap[changeX[newMapIdx][67]][changeY[newMapIdx][67]] <= changeVal[newMapIdx][67];
        currentMap[changeX[newMapIdx][68]][changeY[newMapIdx][68]] <= changeVal[newMapIdx][68];
        currentMap[changeX[newMapIdx][69]][changeY[newMapIdx][69]] <= changeVal[newMapIdx][69];
        currentMap[changeX[newMapIdx][70]][changeY[newMapIdx][70]] <= changeVal[newMapIdx][70];
        currentMap[changeX[newMapIdx][71]][changeY[newMapIdx][71]] <= changeVal[newMapIdx][71];
        currentMap[changeX[newMapIdx][72]][changeY[newMapIdx][72]] <= changeVal[newMapIdx][72];
        currentMap[changeX[newMapIdx][73]][changeY[newMapIdx][73]] <= changeVal[newMapIdx][73];
        currentMap[changeX[newMapIdx][74]][changeY[newMapIdx][74]] <= changeVal[newMapIdx][74];
        currentMap[changeX[newMapIdx][75]][changeY[newMapIdx][75]] <= changeVal[newMapIdx][75];
        currentMap[changeX[newMapIdx][76]][changeY[newMapIdx][76]] <= changeVal[newMapIdx][76];
        currentMap[changeX[newMapIdx][77]][changeY[newMapIdx][77]] <= changeVal[newMapIdx][77];
        currentMap[changeX[newMapIdx][78]][changeY[newMapIdx][78]] <= changeVal[newMapIdx][78];
        currentMap[changeX[newMapIdx][79]][changeY[newMapIdx][79]] <= changeVal[newMapIdx][79];
        currentMap[changeX[newMapIdx][80]][changeY[newMapIdx][80]] <= changeVal[newMapIdx][80];
        currentMap[changeX[newMapIdx][81]][changeY[newMapIdx][81]] <= changeVal[newMapIdx][81];
        currentMap[changeX[newMapIdx][82]][changeY[newMapIdx][82]] <= changeVal[newMapIdx][82];
        currentMap[changeX[newMapIdx][83]][changeY[newMapIdx][83]] <= changeVal[newMapIdx][83];
        currentMap[changeX[newMapIdx][84]][changeY[newMapIdx][84]] <= changeVal[newMapIdx][84];
        currentMap[changeX[newMapIdx][85]][changeY[newMapIdx][85]] <= changeVal[newMapIdx][85];
        currentMap[changeX[newMapIdx][86]][changeY[newMapIdx][86]] <= changeVal[newMapIdx][86];
        currentMap[changeX[newMapIdx][87]][changeY[newMapIdx][87]] <= changeVal[newMapIdx][87];
        currentMap[changeX[newMapIdx][88]][changeY[newMapIdx][88]] <= changeVal[newMapIdx][88];
        currentMap[changeX[newMapIdx][89]][changeY[newMapIdx][89]] <= changeVal[newMapIdx][89];
        currentMap[changeX[newMapIdx][90]][changeY[newMapIdx][90]] <= changeVal[newMapIdx][90];
        currentMap[changeX[newMapIdx][91]][changeY[newMapIdx][91]] <= changeVal[newMapIdx][91];
        currentMap[changeX[newMapIdx][92]][changeY[newMapIdx][92]] <= changeVal[newMapIdx][92];
        currentMap[changeX[newMapIdx][93]][changeY[newMapIdx][93]] <= changeVal[newMapIdx][93];
        currentMap[changeX[newMapIdx][94]][changeY[newMapIdx][94]] <= changeVal[newMapIdx][94];
        currentMap[changeX[newMapIdx][95]][changeY[newMapIdx][95]] <= changeVal[newMapIdx][95];
        currentMap[changeX[newMapIdx][96]][changeY[newMapIdx][96]] <= changeVal[newMapIdx][96];
        currentMap[changeX[newMapIdx][97]][changeY[newMapIdx][97]] <= changeVal[newMapIdx][97];
        currentMap[changeX[newMapIdx][98]][changeY[newMapIdx][98]] <= changeVal[newMapIdx][98];
        currentMap[changeX[newMapIdx][99]][changeY[newMapIdx][99]] <= changeVal[newMapIdx][99];
        currentMap[changeX[newMapIdx][100]][changeY[newMapIdx][100]] <= changeVal[newMapIdx][100];
        currentMap[changeX[newMapIdx][101]][changeY[newMapIdx][101]] <= changeVal[newMapIdx][101];
        currentMap[changeX[newMapIdx][102]][changeY[newMapIdx][102]] <= changeVal[newMapIdx][102];
        currentMap[changeX[newMapIdx][103]][changeY[newMapIdx][103]] <= changeVal[newMapIdx][103];
        currentMap[changeX[newMapIdx][104]][changeY[newMapIdx][104]] <= changeVal[newMapIdx][104];
        currentMap[changeX[newMapIdx][105]][changeY[newMapIdx][105]] <= changeVal[newMapIdx][105];
        currentMap[changeX[newMapIdx][106]][changeY[newMapIdx][106]] <= changeVal[newMapIdx][106];
        currentMap[changeX[newMapIdx][107]][changeY[newMapIdx][107]] <= changeVal[newMapIdx][107];
        currentMap[changeX[newMapIdx][108]][changeY[newMapIdx][108]] <= changeVal[newMapIdx][108];
        currentMap[changeX[newMapIdx][109]][changeY[newMapIdx][109]] <= changeVal[newMapIdx][109];
        currentMap[changeX[newMapIdx][110]][changeY[newMapIdx][110]] <= changeVal[newMapIdx][110];
        currentMap[changeX[newMapIdx][111]][changeY[newMapIdx][111]] <= changeVal[newMapIdx][111];
        currentMap[changeX[newMapIdx][112]][changeY[newMapIdx][112]] <= changeVal[newMapIdx][112];
        currentMap[changeX[newMapIdx][113]][changeY[newMapIdx][113]] <= changeVal[newMapIdx][113];
        currentMap[changeX[newMapIdx][114]][changeY[newMapIdx][114]] <= changeVal[newMapIdx][114];
        currentMap[changeX[newMapIdx][115]][changeY[newMapIdx][115]] <= changeVal[newMapIdx][115];
        currentMap[changeX[newMapIdx][116]][changeY[newMapIdx][116]] <= changeVal[newMapIdx][116];
        currentMap[changeX[newMapIdx][117]][changeY[newMapIdx][117]] <= changeVal[newMapIdx][117];
        currentMap[changeX[newMapIdx][118]][changeY[newMapIdx][118]] <= changeVal[newMapIdx][118];
        currentMap[changeX[newMapIdx][119]][changeY[newMapIdx][119]] <= changeVal[newMapIdx][119];
        currentMap[changeX[newMapIdx][120]][changeY[newMapIdx][120]] <= changeVal[newMapIdx][120];
        currentMap[changeX[newMapIdx][121]][changeY[newMapIdx][121]] <= changeVal[newMapIdx][121];
        currentMap[changeX[newMapIdx][122]][changeY[newMapIdx][122]] <= changeVal[newMapIdx][122];
        currentMap[changeX[newMapIdx][123]][changeY[newMapIdx][123]] <= changeVal[newMapIdx][123];
        currentMap[changeX[newMapIdx][124]][changeY[newMapIdx][124]] <= changeVal[newMapIdx][124];
        currentMap[changeX[newMapIdx][125]][changeY[newMapIdx][125]] <= changeVal[newMapIdx][125];
        currentMap[changeX[newMapIdx][126]][changeY[newMapIdx][126]] <= changeVal[newMapIdx][126];
        currentMap[changeX[newMapIdx][127]][changeY[newMapIdx][127]] <= changeVal[newMapIdx][127];
  
      end  

     
    end else currentMapIndex <= rnd[2:0] % (N_NEW_MAPS+1); // 0-5
  end
endmodule

