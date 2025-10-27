module around_character #(
  parameter int TILE_BITS     = 4,
  parameter int MAP_WIDTH_X   = 31,
  parameter int MAP_HEIGHT_Y  = 28,
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

  // Snapshot character tile at SOF
  always_ff @(posedge clk or negedge resetN) begin
    // if (!resetN) begin
    //   charTileX_q <= '0;
    //   charTileY_q <= '0;
    // end else if (startOfFrame) begin
    //   charTileX_q <= charTileX;
    //   charTileY_q <= charTileY;
    // end
    charTileX_q <= charTileX;
    charTileY_q <= charTileY;
  end

  // Valid neighbor flags (unsigned-safe)
  logic has_up, has_down, has_left, has_right;
  always_comb begin
    has_up    = (charTileY_q > 0);
    has_down  = (charTileY_q < MAP_HEIGHT_Y-1);
    has_left  = (charTileX_q > 0);
    has_right = (charTileX_q < MAP_WIDTH_X-1);
  end

  // {up,down,left,right} bit slices
  localparam int UP_MSB    = 4*TILE_BITS-1;
  localparam int DOWN_MSB  = 3*TILE_BITS-1;
  localparam int LEFT_MSB  = 2*TILE_BITS-1;
  localparam int RIGHT_MSB = 1*TILE_BITS-1;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      tiles_around <= {4{WALL}};
    end else begin
      // if (startOfFrame) begin
      //   // Seed ALL directions to WALL; scan will overwrite valid ones
      //   tiles_around <= {4{WALL}};
      // end

      if (isScanInsideMap) begin
        if (has_up    && (currTileX == charTileX_q)     && (currTileY == charTileY_q-1))
          tiles_around[UP_MSB   -: TILE_BITS] <= currTileData;

        if (has_down  && (currTileX == charTileX_q)     && (currTileY == charTileY_q+1))
          tiles_around[DOWN_MSB -: TILE_BITS] <= currTileData;

        if (has_left  && (currTileX == charTileX_q-1)   && (currTileY == charTileY_q))
          tiles_around[LEFT_MSB -: TILE_BITS] <= currTileData;

        if (has_right && (currTileX == charTileX_q+1)   && (currTileY == charTileY_q))
          tiles_around[RIGHT_MSB-: TILE_BITS] <= currTileData;
      end
    end
  end
endmodule