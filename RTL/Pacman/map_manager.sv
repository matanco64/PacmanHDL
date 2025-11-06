module map_manager #(
      parameter AW = 5,  // address width (for 32x32 map, AW=5)
      parameter TILE_BITS = 3   // data width (for 8 tile types, DW=3)
) (
    input logic clk,
    input logic resetN,
    input logic [2:0] gameState,
    input logic [7:0] rnd,
	 input logic startOfFrame,


	 
	 input  logic [AW-1:0] raddrX,
	 input  logic [AW-1:0] raddrY,
	 output logic [TILE_BITS-1:0] rdata,
	 
    output logic [8:0] coinsTot,
	 output logic newMapAvailable
);

  // map
  parameter MAP_WIDTH_X = 31;
  parameter MAP_HEIGHT_Y = 28;

  localparam N_NEW_MAPS = 4;
  localparam MAX_CHANGES = 128;
  // game state
  localparam RESET_ST = 3'b000;
   localparam logic [0:N_NEW_MAPS][8:0] COINS_POW_TOT = '{
      315,  // Map 0 (62 changes)
      315,  // Map 1 (110 changes)  
      341,  // Map 2 (122 changes)
      307,  // Map 3 (66 changes)
      293   // Map 4 (original, 0 changes)
  };
  
//# ===================== Summary =================================
//# Map 0: 62 changes | Total coins & power: 322  | Total coins 315
//# Map 1: 110 changes | Total coins & power: 326 | Total coins 315
//# Map 2: 122 changes | Total coins & power: 354 | Total coins 341
//# Map 3: 66 changes | Total coins & power: 318  | Total coins 307
//# ===============================================================


  logic [2:0] currentMapIndex;  // 0=map1 ... 3=map4 4=original
  logic inReset;
  logic loadedFirstMap;

  assign coinsTot = COINS_POW_TOT[currentMapIndex];  // 0=original, map 1 2 3 4

  localparam int DEPTH      = MAP_WIDTH_X * MAP_HEIGHT_Y; 

  logic [TILE_BITS-1:0] map_1_tile_value;
  logic [TILE_BITS-1:0] map_2_tile_value;
  logic [TILE_BITS-1:0] map_3_tile_value;
  logic [TILE_BITS-1:0] map_4_tile_value;
  logic [TILE_BITS-1:0] original_tile_value;

  altsyncram #(
   .operation_mode("ROM"),
   .width_a(TILE_BITS),
   .widthad_a($clog2(DEPTH)),                     // ceil(log2(868)) = 10
   .outdata_reg_a("UNREGISTERED"),
   .init_file("RTL/Pacman/maps_mif/map1.mif")
   ) map1_rom (
   .address_a(raddrX * MAP_HEIGHT_Y + raddrY), // row-major addressing
   .clock0(clk),
   .q_a(map_1_tile_value),
   .wren_a(1'b0),
   .data_a('0)
   );

   altsyncram #(
   .operation_mode("ROM"),
   .width_a(TILE_BITS),
   .widthad_a($clog2(DEPTH)),                     
   .outdata_reg_a("UNREGISTERED"),
   .init_file("RTL/Pacman/maps_mif/map2.mif")
   ) map2_rom (
   .address_a(raddrX * MAP_HEIGHT_Y + raddrY),
   .clock0(clk),
   .q_a(map_2_tile_value),
   .wren_a(1'b0),
   .data_a('0)
   );

   altsyncram #(
   .operation_mode("ROM"),
   .width_a(TILE_BITS),
   .widthad_a($clog2(DEPTH)),
   .outdata_reg_a("UNREGISTERED"),
   .init_file("RTL/Pacman/maps_mif/map3.mif")
   ) map3_rom (
   .address_a(raddrX * MAP_HEIGHT_Y + raddrY),
   .clock0(clk),
   .q_a(map_3_tile_value),
   .wren_a(1'b0),
   .data_a('0)
   );

   altsyncram #(
   .operation_mode("ROM"),
   .width_a(TILE_BITS),
   .widthad_a($clog2(DEPTH)),
   .outdata_reg_a("UNREGISTERED"),
   .init_file("RTL/Pacman/maps_mif/map4.mif")
   ) map4_rom (
   .address_a(raddrX * MAP_HEIGHT_Y + raddrY),
   .clock0(clk),
   .q_a(map_4_tile_value),
   .wren_a(1'b0),
   .data_a('0)
   );

   altsyncram #(
   .operation_mode("ROM"),
   .width_a(TILE_BITS),
   .widthad_a($clog2(DEPTH)),
   .outdata_reg_a("UNREGISTERED"),
   .init_file("RTL/Pacman/maps_mif/original.mif")
   ) original_map_rom (
   .address_a(raddrX * MAP_HEIGHT_Y + raddrY),
   .clock0(clk),
   .q_a(original_tile_value),
   .wren_a(1'b0),
   .data_a('0)
   );




	// ========Main state machine================================
	always_ff @(posedge clk or negedge resetN) begin
	  if (!resetN) begin
		 // Load the original map on reset
		 currentMapIndex <= N_NEW_MAPS;  // Start with original
		 loadedFirstMap <= 1'b0;
		 inReset <= 1'b0;
       newMapAvailable <= 1'b0;
	  end else begin
      newMapAvailable <= 1'b0;
		if (startOfFrame) inReset <= 1'b0; // RESET_ST is up for 1 frame

		// ---  first enter RESET_ST ---
		 if (gameState == RESET_ST && !inReset) begin 
			inReset <= 1'b1;
         if (loadedFirstMap) begin
            currentMapIndex <= rnd[1:0];  // 0-3 just new maps
         end else begin
            loadedFirstMap <= 1'b1;
         end
         newMapAvailable <= 1'b1;
			end
     end
   end

   always_comb begin
       // Default to original map
       rdata = original_tile_value;
   
       case (currentMapIndex)
          2'd0: rdata = map_1_tile_value;
          2'd1: rdata = map_2_tile_value;
          2'd2: rdata = map_3_tile_value;
          2'd3: rdata = map_4_tile_value;
          default: rdata = original_tile_value;
       endcase
   end

endmodule
