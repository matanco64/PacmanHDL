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
localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;

// -----------------------------------------------------------------------------
// Heart bitmap
logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][7:0] heart = {
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'hff,8'hff,8'hff,8'h00,8'h00,8'h00,8'h00,8'hff,8'hff,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'hff,8'hed,8'hed,8'hed,8'hff,8'hff,8'hff,8'hff,8'hed,8'hed,8'hf1,8'hff,8'h00,8'h00},
	{8'h00,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'hff,8'hed,8'hed,8'hed,8'hed,8'hf1,8'hff,8'h00},
	{8'h00,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'h00},
	{8'h00,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'h00},
	{8'h00,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'h00},
	{8'h00,8'h00,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'h00,8'h00},
	{8'h00,8'h00,8'hff,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'hff,8'hff,8'hed,8'hed,8'hed,8'hed,8'hed,8'hed,8'hff,8'hff,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'hff,8'hff,8'hed,8'hed,8'hed,8'hed,8'hff,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hff,8'hed,8'hed,8'hff,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hff,8'hff,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00},
	{8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00}};


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

    if (offsetY < OBJECT_HEIGHT_Y && heartIndex < currLives && offsetX < currLives * OBJECT_WIDTH_X) begin
        localInside = 1;
        srcX = offsetX % OBJECT_WIDTH_X;
        srcY = offsetY;
    end
end

// -----------------------------------------------------------------------------
// Synchronous output
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        RGBout <= TRANSPARENT_ENCODING;
    end else begin
        if (localInside)
            RGBout <= heart[srcY][srcX];
        else
            RGBout <= TRANSPARENT_ENCODING;
    end
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
