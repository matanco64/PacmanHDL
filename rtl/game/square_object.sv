//-- Alex Grinshpun Apr 2017
//-- Dudy Nov 13 2017
// System-Verilog Alex Grinshpun May 2018
// New coding convention dudy December 2018
// (c) Technion IIT, Department of Electrical Engineering 2025 


module	square_object	(	
					input		logic	clk,
					input		logic	resetN,
					input 	logic signed	[10:0] pixelX,//  current VGA pixel 
					input 	logic signed	[10:0] pixelY,
					input 	logic signed	[10:0] topLeftX, //position on the screen 
					input 	logic	signed [10:0] topLeftY,   // can be negative , if the object is partliy outside 
					
					output 	logic	[10:0] offsetX,// offset inside bracket from top left position 
					output 	logic	[10:0] offsetY,
					output	logic	drawingRequest, // indicates pixel inside the bracket
					output	logic	[7:0]	 RGBout //optional color output for mux 
);

parameter  int OBJECT_WIDTH_X = 100;
parameter  int OBJECT_HEIGHT_Y = 100;
parameter  logic [7:0] OBJECT_COLOR = 8'h03 ; 
localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF ;// bitmap  representation for a transparent pixel 
 
logic signed [11:0] dX, dY ; // pixel minus top-left, cannot overflow 12 bits
logic insideBracket ; 

//////////--------------------------------------------------------------------------------------------------------------=
// pixelX >= topLeftX && pixelX < topLeftX + WIDTH  is the same as  0 <= dX < WIDTH,
// i.e. dX < WIDTH as an unsigned number. Written this way it is one subtractor
// per axis (shared with the offset outputs), and for power-of-two sizes the
// range check is just "upper bits are zero" - no extra carry chains.
function automatic logic below(input logic [11:0] d, input int limit);
	if ((limit & (limit - 1)) == 0) below = (d >> $clog2(limit)) == 0;
	else                            below = d < limit;
endfunction

assign dX = pixelX - topLeftX;
assign dY = pixelY - topLeftY;
assign	insideBracket  = below(dX, OBJECT_WIDTH_X) && below(dY, OBJECT_HEIGHT_Y);
		


//////////--------------------------------------------------------------------------------------------------------------=
always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
		RGBout			<=	8'b0;
		drawingRequest	<=	1'b0;
	end
	else begin 
		// DEFUALT outputs
	      RGBout <= TRANSPARENT_ENCODING ; // so it will not be displayed 
			drawingRequest <= 1'b0 ;// transparent color 
			offsetX	<= 0; //no offset
			offsetY	<= 0; //no offset
	
 
		if (insideBracket) // test if it is inside the rectangle 
		begin 
			RGBout  <= OBJECT_COLOR ;	// colors table 
			drawingRequest <= 1'b1 ;
			offsetX	<= dX[10:0]; //calculate relative offsets from top left corner allways a positive number 
			offsetY	<= dY[10:0];
		end 
		
	
	end
end 
endmodule 