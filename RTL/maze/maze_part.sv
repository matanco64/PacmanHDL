module maze_part #(
					SYMBOL_SIZE = 2
					TILE_SIZE = 16
					OBJECT_COLOR = 8'b00000011
) (
	input logic [SYMBOL_SIZE - 1:0] symbol,
	input logic [SYMBOL_SIZE - 1:0] USymbol,
	input logic [SYMBOL_SIZE - 1:0] DSymbol,
	input logic [SYMBOL_SIZE - 1:0] LSymbol,
	input logic [SYMBOL_SIZE - 1:0] RSymbol,
	input logic [3:0] offsetX,
	input logic [3:0] offsetY,
	output	logic	[7:0] RGBout
);

localparam BLOCK_DEPTH = 6;
localparam MARGIN = 3;

	
	
always_comb begin
	logic UpIsWall = (USymbol == 2'd1) || (USymbol == 2'd2);
	logic DownIsWall = (DSymbol == 2'd1) || (DSymbol == 2'd2);
	logic LeftIsWall = (LSymbol == 2'd1) || (LSymbol == 2'd2);
	logic RightIsWall = (RSymbol == 2'd1) || (RSymbol == 2'd2);
	logic isInner =  ((offsetX > BLOCK_DEPTH && (TILE_SIZE - offsetX) > BLOCK_DEPTH) && 
	    (offsetY > BLOCK_DEPTH && (TILE_SIZE - offsetX) > BLOCK_DEPTH));	 
	
	
	if (!symbol || isInner)  // Inner part of the block or not a tile
		RGBout = 8'd0;		
	else if (UpIsWall) begin
		if (offsetY < BLOCK_DEPTH && (offsetX > BLOCK_DEPTH && (TILE_SIZE - offsetX) > BLOCK_DEPTH)
			RGBout = 8'd0;	
		else
			
	end else
	
end


endmodule


