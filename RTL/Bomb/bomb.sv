// (c) Technion IIT, Department of Electrical Engineering 2018 
// Written By Liat Schwartz August 2018 
// Updated September 2020 Dudy.
// Updated by Mor Dahan - January 2022
// Updated by Aviad Etzion - October 2023
// 
// Implements the state machine of the bomb mini-project

module bomb
	(
	input logic clk, 
	input logic resetN, 
	input logic startN, 
	input logic pauseN, 
	input logic OneSecPulse, 
	input logic tc,
	
	output logic countLoadN, 
	output logic countEnable, 
	output logic lampEnable,
	output logic show88
   );

//-------------------------------------------------------------------------------------------

// state machine declaration 
   enum logic [2:0] {s_idle,s_arm, s_run, s_pause, s_lampOff, s_lampOn} SMbomb;
	logic [2:0] timer;
 	
//--------------------------------------------------------------------------------------------

//  syncronous code:  executed once every clock to update the current state 
always @(posedge clk or negedge resetN)
   begin
	   
   if ( !resetN ) begin // Asynchronic reset
		SMbomb <= s_idle;
		countLoadN <= 1'b1;
		countEnable <= 1'b0;
		lampEnable  <= 1'b0;
		show88 <= 1'b0;
		end 

   
	else 		// Synchronic logic FSM
		begin
		// default outputs 
		countLoadN <= 1'b1;
		countEnable <= 1'b0;
		lampEnable  <= 1'b1;
		show88 <= 1'b0;
		
	
	
	case (SMbomb) // logically defining what is the next state, and the ouptput
		
//      ======		
			s_idle: begin
//      ======		
				lampEnable  <= 1'b0;
				countLoadN <= 1'b0; // load
				if (startN == 1'b0) 
					SMbomb <= s_arm; 
			end // idle
			
			s_arm: begin
				 countLoadN <= 1'b0;  // load
				 SMbomb <= s_run;
			end

			s_run: begin
				 countEnable <= 1'b1; // counting
				 if (pauseN == 1'b0)
					  SMbomb <= s_pause;
				 else if (startN == 1'b0) 
					SMbomb <= s_arm;   
				 else if (tc == 1'b1)
					  SMbomb <= s_idle;
			end

			s_pause: begin
				if (pauseN == 1'b1) begin
					SMbomb <= s_run;
					timer <= 'b000;
				end
			end
			
//			s_delay: begin
//				 lampEnable  <= 1'b0;
//				 if (OneSecPulse)
//					timer <= timer + 'b1;
//				 if (timer == 3'b111)
//					SMbomb <= s_run;
//			end

//			s_lampOff: begin
//				 lampEnable <= 1'b0;
//				 if (OneSecPulse)
//					  SMbomb <= s_lampOn;
//			end
//
//			s_lampOn: begin
//				 show88 <= 1'b1;
//				 if (OneSecPulse)
//					  SMbomb <= s_lampOff;
//			end					

//  		  =========		
			  default : begin   
//         =========			
					SMbomb <= s_idle;  
			 end // default
						
		endcase
	end //else
		
	end // always sync
	
		
endmodule
