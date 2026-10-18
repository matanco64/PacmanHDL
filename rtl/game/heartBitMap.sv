module heartBitMap(
    input  logic        clk,
    input  logic        resetN,
    input  logic [10:0] offsetX,        // pixel X offset relative to first heart
    input  logic [10:0] offsetY,        // pixel Y offset relative to heart row
    input  logic [2:0]  currLives,      // number of hearts to draw

    output logic        drawingRequest, // pixel should be displayed
    output logic [7:0]  RGBout          // RGB value from the bitmap
);

localparam int OBJECT_HEIGHT_Y = 16;
localparam int OBJECT_WIDTH_X  = 16;

localparam int COLOR_LINE  = 8'hff;
localparam int COLOR_IN_FULL  = 8'hed;
localparam int COLOR_IN_EMPTY  = 8'h6D;
localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;

logic [7:0] currColor;

// -----------------------------------------------------------------------------
// Heart bitmap
logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][1:0] heart =   {
	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd2,2'd2,2'd2,2'd1,2'd0,2'd0},
	{2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0},
	{2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0},
	{2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0},
	{2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0},
	{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0,2'd0},
	{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd2,2'd2,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}};


// -----------------------------------------------------------------------------
// Combinational computation of source coordinates
logic localInside;
logic [3:0] srcX, srcY;
integer heartIndex;

always_comb begin
    localInside = 0;
    srcX = 0;
    srcY = 0;
    heartIndex = offsetX / OBJECT_WIDTH_X;

    // Is this pixel inside the row of hearts?
    if (offsetY < OBJECT_HEIGHT_Y && offsetX < 5 * OBJECT_WIDTH_X)
        localInside = 1;

    srcX = offsetX % OBJECT_WIDTH_X;
    srcY = offsetY;
end

always_comb begin
    currColor = TRANSPARENT_ENCODING;

    if (localInside) begin
        case (heart[srcY][srcX])
            2'd1: currColor = COLOR_LINE;  // outline
            2'd2: begin
                // determine if this heart should be full (red) or empty (gray)
                if (heartIndex < currLives)
                    currColor = COLOR_IN_FULL;
                else
                    currColor = COLOR_IN_EMPTY;
            end
            default: currColor = TRANSPARENT_ENCODING;
        endcase
    end
end

// -----------------------------------------------------------------------------
// Synchronous output
always_ff @(posedge clk) begin
    if (!resetN) begin
        RGBout 	<= TRANSPARENT_ENCODING;
    end else begin
		  RGBout	<= currColor;
    end
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
