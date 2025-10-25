module around_character #(
  parameter int TILE_BITS     = 4,
  parameter int MAP_WIDTH_X   = 28,
  parameter int MAP_HEIGHT_Y  = 31,
  parameter logic [TILE_BITS-1:0] WALL = 'h2
) (
  input  logic clk, resetN,
  input  logic startOfFrame,
  input  logic [$clog2(MAP_WIDTH_X)-1:0]  currTileX,
  input  logic [$clog2(MAP_HEIGHT_Y)-1:0] currTileY,
  input  logic [TILE_BITS-1:0]            currTileData,
  input  logic [$clog2(MAP_WIDTH_X)-1:0]  charTileX,
  input  logic [$clog2(MAP_HEIGHT_Y)-1:0] charTileY,
  input  logic                            isScanInsideMap,
  output logic [4*TILE_BITS-1:0]          tiles_around  // {up,down,left,right}
);

  logic [$clog2(MAP_WIDTH_X)-1:0]  charTileX_q;
  logic [$clog2(MAP_HEIGHT_Y)-1:0] charTileY_q;



  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      charTileX_q <= '0;
      charTileY_q <= '0;
    end else if (startOfFrame) begin
      charTileX_q <= charTileX;
      charTileY_q <= charTileY;
    end
  end
  
  function logic is_in_range_up();
    return (charTileY_q >= 0);
  endfunction
  function logic is_in_range_down();
    return (charTileY_q + 1 < MAP_HEIGHT_Y);
  endfunction
  function logic is_in_range_left();
    return (charTileX_q >= 0);
  endfunction
  function logic is_in_range_right();
    return (charTileX_q + 1 < MAP_WIDTH_X);
  endfunction

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      tiles_around <= '0;
    end else begin
      if (startOfFrame) begin
        // tiles_around <= '0;
        // Initial placement - walls
        if (is_in_range_up())    tiles_around[4*TILE_BITS-1 -: TILE_BITS] <= WALL;
        if (is_in_range_down())  tiles_around[3*TILE_BITS-1 -: TILE_BITS] <= WALL;
        if (is_in_range_left())  tiles_around[2*TILE_BITS-1 -: TILE_BITS] <= WALL;
        if (is_in_range_right()) tiles_around[1*TILE_BITS-1 -: TILE_BITS] <= WALL;
      end
      if (isScanInsideMap) begin
        // Update during scan (only when in range)
        if (is_in_range_up()   &&
            currTileX == charTileX_q &&
            currTileY == charTileY_q-1)
          tiles_around[4*TILE_BITS-1 -: TILE_BITS] <= currTileData;

        if (is_in_range_down() &&
            currTileX == charTileX_q &&
            currTileY == charTileY_q+1)
          tiles_around[3*TILE_BITS-1 -: TILE_BITS] <= currTileData;

        if (is_in_range_left() &&
            currTileX == charTileX_q-1 &&
            currTileY == charTileY_q)
          tiles_around[2*TILE_BITS-1 -: TILE_BITS] <= currTileData;

        if (is_in_range_right() &&
            currTileX == charTileX_q+1 &&
            currTileY == charTileY_q)
          tiles_around[1*TILE_BITS-1 -: TILE_BITS] <= currTileData;
        end
    end
  end
endmodule