module map_manager (
    input  logic clk,
    input  logic resetN,
    input  logic [2:0] gameState,
    input  logic [7:0] rnd, 
	 
    output logic [0:MAP_WIDTH_X-1][0:MAP_HEIGHT_Y-1][TILE_BITS-1:0] currentMap,
	 output logic [8:0] coinsPowTot
);

    // map
	 parameter MAP_WIDTH_X = 31;
	 parameter MAP_HEIGHT_Y = 28;
	 parameter TILE_BITS    = 4;

    localparam NUM_MAPS     = 4;
    localparam MAX_CHANGES  = 64;
	// game state
    localparam RESET_ST = 3'b000; 
	 localparam logic [NUM_MAPS:0][8:0] COINS_POW_TOT = '{300,328,324,317,305}; // original, map 1 2 3 4
    logic [1:0] currentMapIndex;
	 
	 assign coinsPowTot = COINS_POW_TOT[currentMapIndex]; // 0=original, map 1 2 3 4
	 
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
localparam logic [NUM_MAPS-1:0][MAX_CHANGES-1:0][7:0] changeY = '{
    // Map 0 (29 real changes + 35 zeros)
    '{ 8'd2,  8'd25, 8'd0,  8'd1,  8'd2,  8'd3,  8'd4,  8'd12,
       8'd15, 8'd23, 8'd24, 8'd25, 8'd26, 8'd27, 8'd0,  8'd1,
       8'd2,  8'd3,  8'd4,  8'd23, 8'd24, 8'd25, 8'd26, 8'd27,
       8'd2,  8'd25, 8'd9,  8'd11, 8'd16, 8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 },

    // Map 1 (48 real changes + 16 zeros)
    '{ 8'd7,  8'd8,  8'd9,  8'd10, 8'd11, 8'd16, 8'd17, 8'd18,
       8'd19, 8'd20, 8'd3,  8'd4,  8'd23, 8'd24, 8'd3,  8'd4,
       8'd23, 8'd24, 8'd3,  8'd4,  8'd23, 8'd24, 8'd3,  8'd4,
       8'd23, 8'd24, 8'd3,  8'd4,  8'd23, 8'd24, 8'd3,  8'd4,
       8'd23, 8'd24, 8'd6,  8'd21, 8'd6,  8'd21, 8'd3,  8'd9,
       8'd18, 8'd24, 8'd3,  8'd24, 8'd4,  8'd5,  8'd22, 8'd23,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 },

    // Map 2 (39 real changes + 25 zeros)
    '{ 8'd1,  8'd26, 8'd6,  8'd21, 8'd6,  8'd21, 8'd6,  8'd21,
       8'd2,  8'd3,  8'd4,  8'd5,  8'd22, 8'd23, 8'd24, 8'd25,
       8'd12, 8'd15, 8'd15, 8'd0,  8'd2,  8'd3,  8'd24, 8'd25,
       8'd27, 8'd0,  8'd2,  8'd3,  8'd24, 8'd25, 8'd27, 8'd0,
       8'd27, 8'd6,  8'd12, 8'd15, 8'd21, 8'd12, 8'd15, 8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 },

    // Map 3 (29 real changes + 35 zeros)
    '{ 8'd13, 8'd14, 8'd1,  8'd26, 8'd12, 8'd15, 8'd4,  8'd23,
       8'd6,  8'd15, 8'd21, 8'd4,  8'd23, 8'd4,  8'd23, 8'd12,
       8'd15, 8'd18, 8'd1,  8'd4,  8'd5,  8'd7,  8'd8,  8'd13,
       8'd14, 8'd19, 8'd20, 8'd22, 8'd26, 8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 }
};
// ...existing code...

// -------------------- changeY --------------------
localparam logic [NUM_MAPS-1:0][MAX_CHANGES-1:0][7:0] changeX = '{
    // Map 0
    '{ 8'd8,  8'd8,  8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10,
       8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd10, 8'd18, 8'd18,
       8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18, 8'd18,
       8'd20, 8'd20, 8'd24, 8'd29, 8'd29, 8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 },

    // Map 1
    '{ 8'd1,  8'd1,  8'd1,  8'd1,  8'd1,  8'd1,  8'd1,  8'd1,
       8'd1,  8'd1,  8'd10, 8'd10, 8'd10, 8'd10, 8'd11, 8'd11,
       8'd11, 8'd11, 8'd12, 8'd12, 8'd12, 8'd12, 8'd16, 8'd16,
       8'd16, 8'd16, 8'd17, 8'd17, 8'd17, 8'd17, 8'd18, 8'd18,
       8'd18, 8'd18, 8'd21, 8'd21, 8'd22, 8'd22, 8'd24, 8'd24,
       8'd24, 8'd24, 8'd25, 8'd25, 8'd26, 8'd26, 8'd26, 8'd26,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 },

    // Map 2
    '{ 8'd1,  8'd1,  8'd2,  8'd2,  8'd3,  8'd3,  8'd4,  8'd4,
       8'd5,  8'd5,  8'd5,  8'd5,  8'd5,  8'd5,  8'd5,  8'd5,
       8'd10, 8'd10, 8'd14, 8'd16, 8'd16, 8'd16, 8'd16, 8'd16,
       8'd16, 8'd17, 8'd17, 8'd17, 8'd17, 8'd17, 8'd17, 8'd18,
       8'd18, 8'd22, 8'd22, 8'd22, 8'd22, 8'd26, 8'd26, 8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 },

    // Map 3
    '{ 8'd5,  8'd5,  8'd8,  8'd8,  8'd10, 8'd10, 8'd12, 8'd12,
       8'd14, 8'd14, 8'd14, 8'd16, 8'd16, 8'd18, 8'd18, 8'd20,
       8'd20, 8'd24, 8'd29, 8'd29, 8'd29, 8'd29, 8'd29, 8'd29,
       8'd29, 8'd29, 8'd29, 8'd29, 8'd29, 8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,
       8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0,  8'd0 }
};

// -------------------- changeVal --------------------
localparam logic [NUM_MAPS-1:0][MAX_CHANGES-1:0][TILE_BITS-1:0] changeVal = '{
    // Map 0 (all 4'd2)
    '{ 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },

    // Map 1
    '{ 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd1, 4'd1, 4'd2, 4'd2, 4'd1,
       4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },

    // Map 2
    '{ 4'd1, 4'd1, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd5, 4'd2, 4'd5, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 },

    // Map 3
    '{ 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd1, 4'd5, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd5, 4'd1, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2,
       4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2, 4'd2 }
};
	

    
	 // === Main state machine ===
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            // Load the original map on reset
            currentMap <= OriginalPacmanMap;
            currentMapIndex <= 2'd0;
        end 
        else if (gameState == RESET_ST) begin
            // Start from the base map
            currentMap <= OriginalPacmanMap;
             
            // Static manual assignment for Quartus compatibility (no loops!)
            case (currentMapIndex-1) // -1 to ignore original
                2'd0: begin
                    currentMap[ changeX[0][0]  ][ changeY[0][0]  ] <= changeVal[0][0];
						  currentMap[ changeX[0][1]  ][ changeY[0][1]  ] <= changeVal[0][1];
						  currentMap[ changeX[0][2]  ][ changeY[0][2]  ] <= changeVal[0][2];
						  currentMap[ changeX[0][3]  ][ changeY[0][3]  ] <= changeVal[0][3];
						  currentMap[ changeX[0][4]  ][ changeY[0][4]  ] <= changeVal[0][4];
						  currentMap[ changeX[0][5]  ][ changeY[0][5]  ] <= changeVal[0][5];
						  currentMap[ changeX[0][6]  ][ changeY[0][6]  ] <= changeVal[0][6];
						  currentMap[ changeX[0][7]  ][ changeY[0][7]  ] <= changeVal[0][7];
						  currentMap[ changeX[0][8]  ][ changeY[0][8]  ] <= changeVal[0][8];
						  currentMap[ changeX[0][9]  ][ changeY[0][9]  ] <= changeVal[0][9];
						  currentMap[ changeX[0][10] ][ changeY[0][10] ] <= changeVal[0][10];
						  currentMap[ changeX[0][11] ][ changeY[0][11] ] <= changeVal[0][11];
						  currentMap[ changeX[0][12] ][ changeY[0][12] ] <= changeVal[0][12];
						  currentMap[ changeX[0][13] ][ changeY[0][13] ] <= changeVal[0][13];
						  currentMap[ changeX[0][14] ][ changeY[0][14] ] <= changeVal[0][14];
						  currentMap[ changeX[0][15] ][ changeY[0][15] ] <= changeVal[0][15];
						  currentMap[ changeX[0][16] ][ changeY[0][16] ] <= changeVal[0][16];
						  currentMap[ changeX[0][17] ][ changeY[0][17] ] <= changeVal[0][17];
						  currentMap[ changeX[0][18] ][ changeY[0][18] ] <= changeVal[0][18];
						  currentMap[ changeX[0][19] ][ changeY[0][19] ] <= changeVal[0][19];
						  currentMap[ changeX[0][20] ][ changeY[0][20] ] <= changeVal[0][20];
						  currentMap[ changeX[0][21] ][ changeY[0][21] ] <= changeVal[0][21];
						  currentMap[ changeX[0][22] ][ changeY[0][22] ] <= changeVal[0][22];
						  currentMap[ changeX[0][23] ][ changeY[0][23] ] <= changeVal[0][23];
						  currentMap[ changeX[0][24] ][ changeY[0][24] ] <= changeVal[0][24];
						  currentMap[ changeX[0][25] ][ changeY[0][25] ] <= changeVal[0][25];
						  currentMap[ changeX[0][26] ][ changeY[0][26] ] <= changeVal[0][26];
						  currentMap[ changeX[0][27] ][ changeY[0][27] ] <= changeVal[0][27];
						  currentMap[ changeX[0][28] ][ changeY[0][28] ] <= changeVal[0][28];
						  currentMap[ changeX[0][29] ][ changeY[0][29] ] <= changeVal[0][29];
						  currentMap[ changeX[0][30] ][ changeY[0][30] ] <= changeVal[0][30];
						  currentMap[ changeX[0][31] ][ changeY[0][31] ] <= changeVal[0][31];
						  currentMap[ changeX[0][32] ][ changeY[0][32] ] <= changeVal[0][32];
						  currentMap[ changeX[0][33] ][ changeY[0][33] ] <= changeVal[0][33];
						  currentMap[ changeX[0][34] ][ changeY[0][34] ] <= changeVal[0][34];
						  currentMap[ changeX[0][35] ][ changeY[0][35] ] <= changeVal[0][35];
						  currentMap[ changeX[0][36] ][ changeY[0][36] ] <= changeVal[0][36];
						  currentMap[ changeX[0][37] ][ changeY[0][37] ] <= changeVal[0][37];
						  currentMap[ changeX[0][38] ][ changeY[0][38] ] <= changeVal[0][38];
						  currentMap[ changeX[0][39] ][ changeY[0][39] ] <= changeVal[0][39];
						  currentMap[ changeX[0][40] ][ changeY[0][40] ] <= changeVal[0][40];
						  currentMap[ changeX[0][41] ][ changeY[0][41] ] <= changeVal[0][41];
						  currentMap[ changeX[0][42] ][ changeY[0][42] ] <= changeVal[0][42];
						  currentMap[ changeX[0][43] ][ changeY[0][43] ] <= changeVal[0][43];
						  currentMap[ changeX[0][44] ][ changeY[0][44] ] <= changeVal[0][44];
						  currentMap[ changeX[0][45] ][ changeY[0][45] ] <= changeVal[0][45];
						  currentMap[ changeX[0][46] ][ changeY[0][46] ] <= changeVal[0][46];
						  currentMap[ changeX[0][47] ][ changeY[0][47] ] <= changeVal[0][47];
						  currentMap[ changeX[0][48] ][ changeY[0][48] ] <= changeVal[0][48];
						  currentMap[ changeX[0][49] ][ changeY[0][49] ] <= changeVal[0][49];
						  currentMap[ changeX[0][50] ][ changeY[0][50] ] <= changeVal[0][50];
						  currentMap[ changeX[0][51] ][ changeY[0][51] ] <= changeVal[0][51];
						  currentMap[ changeX[0][52] ][ changeY[0][52] ] <= changeVal[0][52];
						  currentMap[ changeX[0][53] ][ changeY[0][53] ] <= changeVal[0][53];
						  currentMap[ changeX[0][54] ][ changeY[0][54] ] <= changeVal[0][54];
						  currentMap[ changeX[0][55] ][ changeY[0][55] ] <= changeVal[0][55];
						  currentMap[ changeX[0][56] ][ changeY[0][56] ] <= changeVal[0][56];
						  currentMap[ changeX[0][57] ][ changeY[0][57] ] <= changeVal[0][57];
						  currentMap[ changeX[0][58] ][ changeY[0][58] ] <= changeVal[0][58];
						  currentMap[ changeX[0][59] ][ changeY[0][59] ] <= changeVal[0][59];
						  currentMap[ changeX[0][60] ][ changeY[0][60] ] <= changeVal[0][60];
						  currentMap[ changeX[0][61] ][ changeY[0][61] ] <= changeVal[0][61];
						  currentMap[ changeX[0][62] ][ changeY[0][62] ] <= changeVal[0][62];
						  currentMap[ changeX[0][63] ][ changeY[0][63] ] <= changeVal[0][63];
                end
                2'd1: begin
                    currentMap[ changeX[1][0]  ][ changeY[1][0]  ] <= changeVal[1][0];
						  currentMap[ changeX[1][1]  ][ changeY[1][1]  ] <= changeVal[1][1];
						  currentMap[ changeX[1][2]  ][ changeY[1][2]  ] <= changeVal[1][2];
						  currentMap[ changeX[1][3]  ][ changeY[1][3]  ] <= changeVal[1][3];
						  currentMap[ changeX[1][4]  ][ changeY[1][4]  ] <= changeVal[1][4];
						  currentMap[ changeX[1][5]  ][ changeY[1][5]  ] <= changeVal[1][5];
						  currentMap[ changeX[1][6]  ][ changeY[1][6]  ] <= changeVal[1][6];
						  currentMap[ changeX[1][7]  ][ changeY[1][7]  ] <= changeVal[1][7];
						  currentMap[ changeX[1][8]  ][ changeY[1][8]  ] <= changeVal[1][8];
						  currentMap[ changeX[1][9]  ][ changeY[1][9]  ] <= changeVal[1][9];
						  currentMap[ changeX[1][10] ][ changeY[1][10] ] <= changeVal[1][10];
						  currentMap[ changeX[1][11] ][ changeY[1][11] ] <= changeVal[1][11];
						  currentMap[ changeX[1][12] ][ changeY[1][12] ] <= changeVal[1][12];
						  currentMap[ changeX[1][13] ][ changeY[1][13] ] <= changeVal[1][13];
						  currentMap[ changeX[1][14] ][ changeY[1][14] ] <= changeVal[1][14];
						  currentMap[ changeX[1][15] ][ changeY[1][15] ] <= changeVal[1][15];
						  currentMap[ changeX[1][16] ][ changeY[1][16] ] <= changeVal[1][16];
						  currentMap[ changeX[1][17] ][ changeY[1][17] ] <= changeVal[1][17];
						  currentMap[ changeX[1][18] ][ changeY[1][18] ] <= changeVal[1][18];
						  currentMap[ changeX[1][19] ][ changeY[1][19] ] <= changeVal[1][19];
						  currentMap[ changeX[1][20] ][ changeY[1][20] ] <= changeVal[1][20];
						  currentMap[ changeX[1][21] ][ changeY[1][21] ] <= changeVal[1][21];
						  currentMap[ changeX[1][22] ][ changeY[1][22] ] <= changeVal[1][22];
						  currentMap[ changeX[1][23] ][ changeY[1][23] ] <= changeVal[1][23];
						  currentMap[ changeX[1][24] ][ changeY[1][24] ] <= changeVal[1][24];
						  currentMap[ changeX[1][25] ][ changeY[1][25] ] <= changeVal[1][25];
						  currentMap[ changeX[1][26] ][ changeY[1][26] ] <= changeVal[1][26];
						  currentMap[ changeX[1][27] ][ changeY[1][27] ] <= changeVal[1][27];
						  currentMap[ changeX[1][28] ][ changeY[1][28] ] <= changeVal[1][28];
						  currentMap[ changeX[1][29] ][ changeY[1][29] ] <= changeVal[1][29];
						  currentMap[ changeX[1][30] ][ changeY[1][30] ] <= changeVal[1][30];
						  currentMap[ changeX[1][31] ][ changeY[1][31] ] <= changeVal[1][31];
						  currentMap[ changeX[1][32] ][ changeY[1][32] ] <= changeVal[1][32];
						  currentMap[ changeX[1][33] ][ changeY[1][33] ] <= changeVal[1][33];
						  currentMap[ changeX[1][34] ][ changeY[1][34] ] <= changeVal[1][34];
						  currentMap[ changeX[1][35] ][ changeY[1][35] ] <= changeVal[1][35];
						  currentMap[ changeX[1][36] ][ changeY[1][36] ] <= changeVal[1][36];
						  currentMap[ changeX[1][37] ][ changeY[1][37] ] <= changeVal[1][37];
						  currentMap[ changeX[1][38] ][ changeY[1][38] ] <= changeVal[1][38];
						  currentMap[ changeX[1][39] ][ changeY[1][39] ] <= changeVal[1][39];
						  currentMap[ changeX[1][40] ][ changeY[1][40] ] <= changeVal[1][40];
						  currentMap[ changeX[1][41] ][ changeY[1][41] ] <= changeVal[1][41];
						  currentMap[ changeX[1][42] ][ changeY[1][42] ] <= changeVal[1][42];
						  currentMap[ changeX[1][43] ][ changeY[1][43] ] <= changeVal[1][43];
						  currentMap[ changeX[1][44] ][ changeY[1][44] ] <= changeVal[1][44];
						  currentMap[ changeX[1][45] ][ changeY[1][45] ] <= changeVal[1][45];
						  currentMap[ changeX[1][46] ][ changeY[1][46] ] <= changeVal[1][46];
						  currentMap[ changeX[1][47] ][ changeY[1][47] ] <= changeVal[1][47];
						  currentMap[ changeX[1][48] ][ changeY[1][48] ] <= changeVal[1][48];
						  currentMap[ changeX[1][49] ][ changeY[1][49] ] <= changeVal[1][49];
						  currentMap[ changeX[1][50] ][ changeY[1][50] ] <= changeVal[1][50];
						  currentMap[ changeX[1][51] ][ changeY[1][51] ] <= changeVal[1][51];
						  currentMap[ changeX[1][52] ][ changeY[1][52] ] <= changeVal[1][52];
						  currentMap[ changeX[1][53] ][ changeY[1][53] ] <= changeVal[1][53];
						  currentMap[ changeX[1][54] ][ changeY[1][54] ] <= changeVal[1][54];
						  currentMap[ changeX[1][55] ][ changeY[1][55] ] <= changeVal[1][55];
						  currentMap[ changeX[1][56] ][ changeY[1][56] ] <= changeVal[1][56];
						  currentMap[ changeX[1][57] ][ changeY[1][57] ] <= changeVal[1][57];
						  currentMap[ changeX[1][58] ][ changeY[1][58] ] <= changeVal[1][58];
						  currentMap[ changeX[1][59] ][ changeY[1][59] ] <= changeVal[1][59];
						  currentMap[ changeX[1][60] ][ changeY[1][60] ] <= changeVal[1][60];
						  currentMap[ changeX[1][61] ][ changeY[1][61] ] <= changeVal[1][61];
						  currentMap[ changeX[1][62] ][ changeY[1][62] ] <= changeVal[1][62];
						  currentMap[ changeX[1][63] ][ changeY[1][63] ] <= changeVal[1][63];
                end
                2'd2: begin
                    currentMap[ changeX[2][0]  ][ changeY[2][0]  ] <= changeVal[2][0];
						  currentMap[ changeX[2][1]  ][ changeY[2][1]  ] <= changeVal[2][1];
						  currentMap[ changeX[2][2]  ][ changeY[2][2]  ] <= changeVal[2][2];
						  currentMap[ changeX[2][3]  ][ changeY[2][3]  ] <= changeVal[2][3];
						  currentMap[ changeX[2][4]  ][ changeY[2][4]  ] <= changeVal[2][4];
						  currentMap[ changeX[2][5]  ][ changeY[2][5]  ] <= changeVal[2][5];
						  currentMap[ changeX[2][6]  ][ changeY[2][6]  ] <= changeVal[2][6];
						  currentMap[ changeX[2][7]  ][ changeY[2][7]  ] <= changeVal[2][7];
						  currentMap[ changeX[2][8]  ][ changeY[2][8]  ] <= changeVal[2][8];
						  currentMap[ changeX[2][9]  ][ changeY[2][9]  ] <= changeVal[2][9];
						  currentMap[ changeX[2][10] ][ changeY[2][10] ] <= changeVal[2][10];
						  currentMap[ changeX[2][11] ][ changeY[2][11] ] <= changeVal[2][11];
						  currentMap[ changeX[2][12] ][ changeY[2][12] ] <= changeVal[2][12];
						  currentMap[ changeX[2][13] ][ changeY[2][13] ] <= changeVal[2][13];
						  currentMap[ changeX[2][14] ][ changeY[2][14] ] <= changeVal[2][14];
						  currentMap[ changeX[2][15] ][ changeY[2][15] ] <= changeVal[2][15];
						  currentMap[ changeX[2][16] ][ changeY[2][16] ] <= changeVal[2][16];
						  currentMap[ changeX[2][17] ][ changeY[2][17] ] <= changeVal[2][17];
						  currentMap[ changeX[2][18] ][ changeY[2][18] ] <= changeVal[2][18];
						  currentMap[ changeX[2][19] ][ changeY[2][19] ] <= changeVal[2][19];
						  currentMap[ changeX[2][20] ][ changeY[2][20] ] <= changeVal[2][20];
						  currentMap[ changeX[2][21] ][ changeY[2][21] ] <= changeVal[2][21];
						  currentMap[ changeX[2][22] ][ changeY[2][22] ] <= changeVal[2][22];
						  currentMap[ changeX[2][23] ][ changeY[2][23] ] <= changeVal[2][23];
						  currentMap[ changeX[2][24] ][ changeY[2][24] ] <= changeVal[2][24];
						  currentMap[ changeX[2][25] ][ changeY[2][25] ] <= changeVal[2][25];
						  currentMap[ changeX[2][26] ][ changeY[2][26] ] <= changeVal[2][26];
						  currentMap[ changeX[2][27] ][ changeY[2][27] ] <= changeVal[2][27];
						  currentMap[ changeX[2][28] ][ changeY[2][28] ] <= changeVal[2][28];
						  currentMap[ changeX[2][29] ][ changeY[2][29] ] <= changeVal[2][29];
						  currentMap[ changeX[2][30] ][ changeY[2][30] ] <= changeVal[2][30];
						  currentMap[ changeX[2][31] ][ changeY[2][31] ] <= changeVal[2][31];
						  currentMap[ changeX[2][32] ][ changeY[2][32] ] <= changeVal[2][32];
						  currentMap[ changeX[2][33] ][ changeY[2][33] ] <= changeVal[2][33];
						  currentMap[ changeX[2][34] ][ changeY[2][34] ] <= changeVal[2][34];
						  currentMap[ changeX[2][35] ][ changeY[2][35] ] <= changeVal[2][35];
						  currentMap[ changeX[2][36] ][ changeY[2][36] ] <= changeVal[2][36];
						  currentMap[ changeX[2][37] ][ changeY[2][37] ] <= changeVal[2][37];
						  currentMap[ changeX[2][38] ][ changeY[2][38] ] <= changeVal[2][38];
						  currentMap[ changeX[2][39] ][ changeY[2][39] ] <= changeVal[2][39];
						  currentMap[ changeX[2][40] ][ changeY[2][40] ] <= changeVal[2][40];
						  currentMap[ changeX[2][41] ][ changeY[2][41] ] <= changeVal[2][41];
						  currentMap[ changeX[2][42] ][ changeY[2][42] ] <= changeVal[2][42];
						  currentMap[ changeX[2][43] ][ changeY[2][43] ] <= changeVal[2][43];
						  currentMap[ changeX[2][44] ][ changeY[2][44] ] <= changeVal[2][44];
						  currentMap[ changeX[2][45] ][ changeY[2][45] ] <= changeVal[2][45];
						  currentMap[ changeX[2][46] ][ changeY[2][46] ] <= changeVal[2][46];
						  currentMap[ changeX[2][47] ][ changeY[2][47] ] <= changeVal[2][47];
						  currentMap[ changeX[2][48] ][ changeY[2][48] ] <= changeVal[2][48];
						  currentMap[ changeX[2][49] ][ changeY[2][49] ] <= changeVal[2][49];
						  currentMap[ changeX[2][50] ][ changeY[2][50] ] <= changeVal[2][50];
						  currentMap[ changeX[2][51] ][ changeY[2][51] ] <= changeVal[2][51];
						  currentMap[ changeX[2][52] ][ changeY[2][52] ] <= changeVal[2][52];
						  currentMap[ changeX[2][53] ][ changeY[2][53] ] <= changeVal[2][53];
						  currentMap[ changeX[2][54] ][ changeY[2][54] ] <= changeVal[2][54];
						  currentMap[ changeX[2][55] ][ changeY[2][55] ] <= changeVal[2][55];
						  currentMap[ changeX[2][56] ][ changeY[2][56] ] <= changeVal[2][56];
						  currentMap[ changeX[2][57] ][ changeY[2][57] ] <= changeVal[2][57];
						  currentMap[ changeX[2][58] ][ changeY[2][58] ] <= changeVal[2][58];
						  currentMap[ changeX[2][59] ][ changeY[2][59] ] <= changeVal[2][59];
						  currentMap[ changeX[2][60] ][ changeY[2][60] ] <= changeVal[2][60];
						  currentMap[ changeX[2][61] ][ changeY[2][61] ] <= changeVal[2][61];
						  currentMap[ changeX[2][62] ][ changeY[2][62] ] <= changeVal[2][62];
						  currentMap[ changeX[2][63] ][ changeY[2][63] ] <= changeVal[2][63];
                end
                2'd3: begin
                    currentMap[ changeX[3][0]  ][ changeY[3][0]  ] <= changeVal[3][0];
						  currentMap[ changeX[3][1]  ][ changeY[3][1]  ] <= changeVal[3][1];
						  currentMap[ changeX[3][2]  ][ changeY[3][2]  ] <= changeVal[3][2];
						  currentMap[ changeX[3][3]  ][ changeY[3][3]  ] <= changeVal[3][3];
						  currentMap[ changeX[3][4]  ][ changeY[3][4]  ] <= changeVal[3][4];
						  currentMap[ changeX[3][5]  ][ changeY[3][5]  ] <= changeVal[3][5];
						  currentMap[ changeX[3][6]  ][ changeY[3][6]  ] <= changeVal[3][6];
						  currentMap[ changeX[3][7]  ][ changeY[3][7]  ] <= changeVal[3][7];
						  currentMap[ changeX[3][8]  ][ changeY[3][8]  ] <= changeVal[3][8];
						  currentMap[ changeX[3][9]  ][ changeY[3][9]  ] <= changeVal[3][9];
						  currentMap[ changeX[3][10] ][ changeY[3][10] ] <= changeVal[3][10];
						  currentMap[ changeX[3][11] ][ changeY[3][11] ] <= changeVal[3][11];
						  currentMap[ changeX[3][12] ][ changeY[3][12] ] <= changeVal[3][12];
						  currentMap[ changeX[3][13] ][ changeY[3][13] ] <= changeVal[3][13];
						  currentMap[ changeX[3][14] ][ changeY[3][14] ] <= changeVal[3][14];
						  currentMap[ changeX[3][15] ][ changeY[3][15] ] <= changeVal[3][15];
						  currentMap[ changeX[3][16] ][ changeY[3][16] ] <= changeVal[3][16];
						  currentMap[ changeX[3][17] ][ changeY[3][17] ] <= changeVal[3][17];
						  currentMap[ changeX[3][18] ][ changeY[3][18] ] <= changeVal[3][18];
						  currentMap[ changeX[3][19] ][ changeY[3][19] ] <= changeVal[3][19];
						  currentMap[ changeX[3][20] ][ changeY[3][20] ] <= changeVal[3][20];
						  currentMap[ changeX[3][21] ][ changeY[3][21] ] <= changeVal[3][21];
						  currentMap[ changeX[3][22] ][ changeY[3][22] ] <= changeVal[3][22];
						  currentMap[ changeX[3][23] ][ changeY[3][23] ] <= changeVal[3][23];
						  currentMap[ changeX[3][24] ][ changeY[3][24] ] <= changeVal[3][24];
						  currentMap[ changeX[3][25] ][ changeY[3][25] ] <= changeVal[3][25];
						  currentMap[ changeX[3][26] ][ changeY[3][26] ] <= changeVal[3][26];
						  currentMap[ changeX[3][27] ][ changeY[3][27] ] <= changeVal[3][27];
						  currentMap[ changeX[3][28] ][ changeY[3][28] ] <= changeVal[3][28];
						  currentMap[ changeX[3][29] ][ changeY[3][29] ] <= changeVal[3][29];
						  currentMap[ changeX[3][30] ][ changeY[3][30] ] <= changeVal[3][30];
						  currentMap[ changeX[3][31] ][ changeY[3][31] ] <= changeVal[3][31];
						  currentMap[ changeX[3][32] ][ changeY[3][32] ] <= changeVal[3][32];
						  currentMap[ changeX[3][33] ][ changeY[3][33] ] <= changeVal[3][33];
						  currentMap[ changeX[3][34] ][ changeY[3][34] ] <= changeVal[3][34];
						  currentMap[ changeX[3][35] ][ changeY[3][35] ] <= changeVal[3][35];
						  currentMap[ changeX[3][36] ][ changeY[3][36] ] <= changeVal[3][36];
						  currentMap[ changeX[3][37] ][ changeY[3][37] ] <= changeVal[3][37];
						  currentMap[ changeX[3][38] ][ changeY[3][38] ] <= changeVal[3][38];
						  currentMap[ changeX[3][39] ][ changeY[3][39] ] <= changeVal[3][39];
						  currentMap[ changeX[3][40] ][ changeY[3][40] ] <= changeVal[3][40];
						  currentMap[ changeX[3][41] ][ changeY[3][41] ] <= changeVal[3][41];
						  currentMap[ changeX[3][42] ][ changeY[3][42] ] <= changeVal[3][42];
						  currentMap[ changeX[3][43] ][ changeY[3][43] ] <= changeVal[3][43];
						  currentMap[ changeX[3][44] ][ changeY[3][44] ] <= changeVal[3][44];
						  currentMap[ changeX[3][45] ][ changeY[3][45] ] <= changeVal[3][45];
						  currentMap[ changeX[3][46] ][ changeY[3][46] ] <= changeVal[3][46];
						  currentMap[ changeX[3][47] ][ changeY[3][47] ] <= changeVal[3][47];
						  currentMap[ changeX[3][48] ][ changeY[3][48] ] <= changeVal[3][48];
						  currentMap[ changeX[3][49] ][ changeY[3][49] ] <= changeVal[3][49];
						  currentMap[ changeX[3][50] ][ changeY[3][50] ] <= changeVal[3][50];
						  currentMap[ changeX[3][51] ][ changeY[3][51] ] <= changeVal[3][51];
						  currentMap[ changeX[3][52] ][ changeY[3][52] ] <= changeVal[3][52];
						  currentMap[ changeX[3][53] ][ changeY[3][53] ] <= changeVal[3][53];
						  currentMap[ changeX[3][54] ][ changeY[3][54] ] <= changeVal[3][54];
						  currentMap[ changeX[3][55] ][ changeY[3][55] ] <= changeVal[3][55];
						  currentMap[ changeX[3][56] ][ changeY[3][56] ] <= changeVal[3][56];
						  currentMap[ changeX[3][57] ][ changeY[3][57] ] <= changeVal[3][57];
						  currentMap[ changeX[3][58] ][ changeY[3][58] ] <= changeVal[3][58];
						  currentMap[ changeX[3][59] ][ changeY[3][59] ] <= changeVal[3][59];
						  currentMap[ changeX[3][60] ][ changeY[3][60] ] <= changeVal[3][60];
						  currentMap[ changeX[3][61] ][ changeY[3][61] ] <= changeVal[3][61];
						  currentMap[ changeX[3][62] ][ changeY[3][62] ] <= changeVal[3][62];
						  currentMap[ changeX[3][63] ][ changeY[3][63] ] <= changeVal[3][63];
                end
            endcase
        end else currentMapIndex <= rnd[1:0] + 1 ; // rnd from map 1 2 3 4 (no original)
    end

endmodule