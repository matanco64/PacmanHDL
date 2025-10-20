module sideBitMapV1	(	
					input		logic	clk,
					input		logic	resetN,
					input 	logic	[10:0] offsetX,
					input 	logic	[10:0] offsetY,
					input		logic	InsideRectangle,  
					input 	logic	[2:0] gameState,
					
					output	logic			drawingRequest,  
					output	logic	[7:0]	RGBout
);


// -----------------------------------------------------------------------------
// bitmaps
	logic [7:0] start_mem [0:4095];
	logic [7:0] play_mem  [0:4095];
	logic [7:0] win_mem   [0:4095];
	logic [7:0] lose_mem  [0:4095];
	logic [7:0] pause_mem [0:4095];


// load the .mem files (hex, one byte per line). Tools often support this for simulation and FPGA init.
initial begin
  // Files are expected in the simulation/synthesis path; adjust paths if needed.
  $readmemh("start.mem", start_mem);
  $readmemh("play.mem",  play_mem);
  $readmemh("win.mem",   win_mem);
  $readmemh("lose.mem",  lose_mem);
  $readmemh("pause.mem", pause_mem);
end

// -----------------------------------------------------------------------------


// game states
  parameter RESET_ST = 3'b000;
  parameter START_WAIT_ST = 3'b001;
  parameter PLAYING_ST = 3'b010;
  parameter PAUSED_ST = 3'b011;
  parameter GHOST_HIT_ST = 3'b100;
  parameter WIN_ST = 3'b101;
  parameter LOSE_ST = 3'b110;
  parameter POWER_UP_ST = 3'b111;

  localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;

  // compute linear address from X,Y (64 wide -> shift left by 6)
	logic [11:0] pixAddr;
	always_comb pixAddr = (offsetY << 6) + offsetX;

always_ff@(posedge clk or negedge resetN)
begin
	if(!resetN) begin
    	RGBout <= TRANSPARENT_ENCODING;
	end
	else begin	
		if (InsideRectangle) begin
			case (gameState)
				RESET_ST,
				START_WAIT_ST: RGBout <= start_mem[pixAddr];
				PAUSED_ST:      RGBout <= pause_mem[pixAddr];
				WIN_ST:         RGBout <= win_mem[pixAddr];
				LOSE_ST:        RGBout <= lose_mem[pixAddr];
				default:        RGBout <= play_mem[pixAddr];
			endcase
		end else begin
      		RGBout <= TRANSPARENT_ENCODING; // outside the rectangle
    	end		
	end 
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule