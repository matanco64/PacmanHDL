// (c) Technion IIT, Department of Electrical Engineering 2022 
// Written By Liat Schwartz August 2018 
// Updated by Mor Dahan - January 2022

// Implements a BCD down counter 99 down to 0 with several enable inputs and loadN data
// having countL, countH and tc outputs
// by instantiating two one bit down-counters


module bcddn
	(
	input  logic clk, 
	input  logic resetN, 
	input  logic loadN, 
	input  logic enable1, 
	input  logic enable2,
	input  logic [3:0] datainL,
	input  logic [3:0] datainH,
	
	output logic [3:0] countL, 
	output logic [3:0] countH,
	output logic tc
   );

	
	logic  tclow, tchigh;// internal variables terminal count 
	
// Low counter instantiation
	down_counter lowc(.clk(clk), 
							.resetN(resetN),
							.loadN(loadN),	
							.enable1(enable1), 
							.enable2(enable2),
							.enable3(1'b1), 	
							.datain(datainL), 
							.count(countL), 
							.tc(tclow) );
	
// High counter instantiation			
	 
	down_counter highc (
		 .clk(clk),
		 .resetN(resetN),
		 .loadN(loadN),
		 .enable1(enable1),
		 .enable2(enable2),
		 .enable3(tclow),      
		 .datain(datainH),
		 .count(countH),
		 .tc(tchigh)
	);
//------------------------------------------------------------------------------------------ 
	assign tc = (tclow && tchigh);
//--------------------------------------------------------------------------------------------------------------------			

endmodule
