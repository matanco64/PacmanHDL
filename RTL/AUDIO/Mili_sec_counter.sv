// (c) Technion IIT, Department of Electrical Engineering 2020
// Implements a slow clock as a 1/100 second counter
// Turbo input sets output 10 times faster
// Adds one_sec output for full second pulses
// Updated by Mor Dahan - January 2022
// Updated by Dudy BarOn - March 2025

module Mili_sec_counter
(
    input  logic clk,         // System clock
    input  logic resetN,      // Active-low reset
    input  logic turbo,       // Turbo mode: 10x faster
    output logic hundredth_sec, // Pulse every 1/100 sec
    output logic one_sec        // Pulse every 1 sec
);

    // Internal counters
    int hundredthSecCount;
    int hundredthSecLimit;
    int oneSecCount;

    // Parameters for simulation and hardware
    parameter logic SIMULATION_MODE = 1'b0;
    parameter int mSecPerTick = 10;
    parameter int PLLClock = 315;

    // Calculate tick limits
	 localparam int hundredthSecVal_REAL = 100 * PLLClock * mSecPerTick;
    localparam int hundredthSecVal_SIM  = 20;
    localparam int hundredthSecVal = SIMULATION_MODE ? hundredthSecVal_SIM : hundredthSecVal_REAL;

    // Adjust for turbo mode
    assign hundredthSecLimit = turbo ? hundredthSecVal / 10 : hundredthSecVal;

    // Main logic block
    always_ff @(posedge clk or negedge resetN)
    begin
        if (!resetN) begin
            // Reset all outputs and counters
            hundredth_sec     <= 1'b0;
            one_sec           <= 1'b0;
            hundredthSecCount <= 0;
            oneSecCount       <= 0;
        end
        else begin
            // Count clock cycles toward 1/100 second
            if (hundredthSecCount >= hundredthSecLimit) begin
                hundredth_sec     <= 1'b1;
                hundredthSecCount <= 0;

                // Count 100 hundredth_sec pulses to reach 1 second
                if (oneSecCount >= 99) begin
                    one_sec     <= 1'b1;
                    oneSecCount <= 0;
                end
                else begin
                    one_sec     <= 1'b0;
                    oneSecCount <= oneSecCount + 1;
                end
            end
            else begin
                hundredthSecCount <= hundredthSecCount + 1;
                hundredth_sec     <= 1'b0;
                one_sec           <= 1'b0;
            end
        end
    end

endmodule