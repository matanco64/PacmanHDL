// topCounters: converted from the Quartus schematic RTL/Bomb/topCounters.bdf (see DE-10 branch).
module topCounters #(
  parameter int CLK_HZ = 31_500_000
) (
  input logic clk,
  input logic resetN,
  input logic startN,
  input logic turbo,
  input logic [3:0] datainL,
  input logic [3:0] datainH,
  input logic pauseN,
  output logic [3:0] countL,
  output logic [3:0] countH,
  output logic oneSec,
  output logic [6:0] HEX0,
  output logic [6:0] HEX1,
  output logic timerEnd
);
  logic countEnable;
  logic countLoadN;
  logic lampEnable;
  logic show88;
  logic tc;

  hexss inst1 (
    .hexin(countL[3:0]),
    .darkN(lampEnable),
    .LampTest(show88),
    .ss(HEX0)
  );
  hexss inst3 (
    .hexin(countH[3:0]),
    .darkN(lampEnable),
    .LampTest(show88),
    .ss(HEX1)
  );
  bcddn inst (
    .clk(clk),
    .resetN(resetN),
    .loadN(countLoadN),
    .enable1(countEnable),
    .enable2(oneSec),
    .datainL(datainL[3:0]),
    .datainH(datainH[3:0]),
    .countL(countL[3:0]),
    .countH(countH[3:0]),
    .tc(tc)
  );
  one_sec_counter #(.SIMULATION_MODE(0), .CLK_HZ(CLK_HZ)) inst5 (
    .clk(clk),
    .resetN(resetN),
    .turbo(turbo),
    .one_sec(oneSec)
  );
  counter_initializer inst2 (
    .clk(clk),
    .resetN(resetN),
    .startN(startN),
    .pauseN(pauseN),
    .OneSecPulse(oneSec),
    .tc(tc),
    .countLoadN(countLoadN),
    .countEnable(countEnable),
    .lampEnable(lampEnable),
    .show88(show88),
    .timerEnd(timerEnd)
  );
endmodule
