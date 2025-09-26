// (c) Technion IIT, Department of Electrical Engineering 2018 
// Written By Liat Schwartz August 2018 
// Updated September 2020 Dudy.
// Updated by Mor Dahan - January 2022
// Updated by Aviad Etzion & Dudy Bar-on - October 2023

// Implements a simple traffic lights controller by using state machine
// This module has a single allways_ff:
//   - Synchronous code: executed once every clock to update the current state 


module ramzor
	(
	input logic clk, // 50 MHz clock 
	input logic resetN, 
	input logic switchN, // pedestrian switch to change the light 
		
	output logic redLight,	  //  output to the red lamp 
	output logic yellowLight, //  output to the yellow lamp 
	output logic greenLight	  //  output to the green lamp 
								// add output for the second part assignment in Lab
   );	
		
		
//---------------------------------------------------------
		localparam SIMULATION_MODE_ON = 0 ; //  Run mode : unmask the line for real run 
 //   localparam SIMULATION_MODE_ON = 1 ; //  Simulation mode: unmask the line for simulation
//---------------------------------------------------------


// state machine and parameters declaration 

	enum logic [1:0] {s_red, s_red_yellow, s_green, s_yellow} SMramzor; // state machine
	logic [3:0] counter; // count down second timer 
	
   logic t_sec; // A short pulse, once every second 
	assign timerEnded = (counter == 4'b0) ; 

//------------------------------------------------------------------------------------------------------------
// **** Fill your code below - Update the "TIME" parameters acording to the number given in the homework table
//------------------------------------------------------------------------------------------------------------

	localparam logic [3:0] RED_OR_GREEN_TIME = 'd5; 
	localparam logic [3:0] YELLOW_TIME = 'd2; 


	localparam logic LED_ON = 1'b1; 
	localparam logic LED_OFF = 1'b0;

	
//--------------------------------------------------------------------------------------------
// Instance of 1Hz sub module as a time counter for the state machine 

one_sec_counter #(.SIMULATION_MODE(SIMULATION_MODE_ON)) one_sec_counter (.clk(clk),
								 .resetN(resetN),
								 .turbo(0),
								 .one_sec(t_sec) );
	
//--------------------------------------------------------------------------------------------------------------------


//   syncronous code executed once every clock to update the current state and outputs 
	
always_ff @(posedge clk or negedge resetN) // State machine logic ////
   begin
	   
   if ( !resetN ) begin // Asynchronic reset, initialize the state machine 
		SMramzor <= s_red;
		counter  <= RED_OR_GREEN_TIME;
		redLight  <= 1'b1 ; 
		yellowLight <=1'b0 ;
		greenLight <= 1'b0 ;
		
		
	end // asynch
	else begin 			// Synchronic logic of the state machine; once every clock 
		
//--------------------------------------------------------------------------------------------------------------------
		if ( t_sec ) begin  // perform once every timer pulse 

			if ( !timerEnded )  // timer didn't finish
				counter <= counter - 4'b1; // decremnt the counter

		end 
//--------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  fill your code and paste to the report #1 
//--------------------------------------------------------------------------------------------------------------------
	
	
	// state machine 
	
		// default outputs 
		redLight  <= 1'b0 ; 
		yellowLight <=1'b0 ;
		greenLight <= 1'b0 ;
		
		case ( SMramzor )

		//          ============		
						s_red: begin
		//          ============		
							redLight  <= 1'b1 ; 
			
							if ( timerEnded || !switchN )  // timer finished 
								begin 
 									SMramzor <= s_red_yellow;  //next state 
									counter <= YELLOW_TIME; // reload counter with the next value 
								end // if 

						end // s_red		

				
		//          ============		
						s_red_yellow: begin
		//          ============		
							redLight  <= 1'b1 ; 
							yellowLight <=1'b1 ;
			
							if ( timerEnded )  // timer finished 
								begin 
 									SMramzor <= s_green;  //next state 
									counter <= RED_OR_GREEN_TIME; // reload counter with the next value 
								end // if 

						end // s_red_yellow
						
		//          ============		
						s_green: begin
		//          ============		
							greenLight  <= 1'b1 ; 
			
							if ( timerEnded )  // timer finished 
								begin 
 									SMramzor <= s_yellow;  //next state 
									counter <= YELLOW_TIME; // reload counter with the next value 
								end // if 

						end // s_green	
						
		//          ============		
						s_yellow: begin
		//          ============		
							yellowLight  <= 1'b1 ; 
			
							if ( timerEnded )  // timer finished 
								begin 
 									SMramzor <= s_red;  //next state 
									counter <= RED_OR_GREEN_TIME; // reload counter with the next value 
								end // if 

						end // s_yellow							
						
								
//--------------------------------------------------------------------------------------------------------------------
// &&&&&&&&&&&&&&  end of paste SM to the report #1 
//--------------------------------------------------------------------------------------------------------------------			
		
		//  		  =========		
					  default : begin   
		//         =========			
							SMramzor <= s_red;  //next state 
						end // default
		  		
		endcase
	end // if reset 
			

end // always_ff state machine ///////////////////////////////

			 
						 
endmodule