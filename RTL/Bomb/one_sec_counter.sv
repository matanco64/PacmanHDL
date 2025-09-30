// (c) Technion IIT, Department of Electrical Engineering 2020 

// Implements a slow clock as an one-second counter
// Turbo input sets output 10 times faster
// Updated by Mor Dahan - January 2022
// Updated by Dudy BarOn - October 2023

 
 module one_sec_counter      	
	(
	input  logic clk, 
	input  logic resetN, 
	input  logic turbo,
	output logic one_sec
   );
	
	int oneSecCount ;
	int sec ;		 // gets either one seccond or Turbo top value

parameter logic SIMULATION_MODE = 0 ;// to update in outside table: 1 for simulation, 0 for DE10 board
	
//       ----------------------------------------------	counter limit setting
   localparam int oneSecVal_REAL = 32'd31_500_000; // for 31.5 MHz board clock
	localparam oneSecVal_SIM = 32'd20; // for quartus simulation 
	localparam oneSecVal= SIMULATION_MODE ? oneSecVal_SIM : oneSecVal_REAL ; //select what to use 
//       ----------------------------------------------	
	
	assign sec = turbo ? oneSecVal/5 : oneSecVal;  // it is legal to devide by 10, as it is done by the compiler not by logic (actual transistors) 


	
   always_ff @( posedge clk or negedge resetN )
   begin
	
		// asynchronous reset
		if ( !resetN ) begin
			one_sec <= 1'b0;
			oneSecCount <= 32'd0;
		end // if reset
		
		// executed once every clock 	
		else begin
			if (oneSecCount >= sec) begin
				one_sec <= 1'b1;
				oneSecCount <= 0;
			end
			else begin
				oneSecCount <= oneSecCount + 1;
				one_sec		<= 1'b0;
			end
		end 
		
	end
	
endmodule