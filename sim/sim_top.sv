// Simulation top: the same core, timing and controller mapping as the Tang
// board, minus the PLL, UART and pin-level details.
module sim_top #(
  parameter int CLK_HZ  = 33_750_000,
  // defaults match the Tang Nano 9K board; the interactive simulator uses a
  // compact raster (no side borders, short blanking) to run faster
  parameter int H_ACT   = 800,
  parameter int H_FRONT = 32,
  parameter int H_SYNC  = 4,
  parameter int H_BACK  = 60,
  parameter int V_FRONT = 13,
  parameter int V_SYNC  = 4,
  parameter int V_BACK  = 20
) (
  input  logic       clk,
  input  logic       resetN,
  input  logic [7:0] buttons,    // gamepad mask, see rtl/io/gamepad.sv
  input  logic       levelKeyN,  // onboard S2
  output logic [7:0] rgb,        // RRRGGGBB, black outside the game window
  output logic       de,
  output logic       vsync
);
  logic [10:0] pixelX, pixelY;
  logic        startOfFrame, inGame, hsync;

  lcd_timing #(
    .H_ACT(H_ACT), .H_FRONT(H_FRONT), .H_SYNC(H_SYNC), .H_BACK(H_BACK),
    .V_ACT(480), .V_FRONT(V_FRONT), .V_SYNC(V_SYNC), .V_BACK(V_BACK)
  ) timing (
    .clk, .resetN, .pixelX, .pixelY, .startOfFrame, .inGame,
    .de, .hsync, .vsync
  );

  logic [3:0] keyPad;
  logic       keyPadValid, star, slash, num, pauseN;

  gamepad pad (
    .clk, .resetN, .buttons, .keyPad, .keyPadValid, .star, .slash, .num, .pauseN
  );

  logic [7:0] coreRgb;

  pacman_core #(.CLK_HZ(CLK_HZ)) game (
    .clk, .resetN,
    .pixelX, .pixelY, .startOfFrame,
    .keyPad, .keyPadValid, .star, .slash, .num, .pauseN,
    .turbo(1'b0),
    .level_key(levelKeyN),
    .RGB(coreRgb)
  );

  assign rgb = inGame ? coreRgb : 8'h00;
endmodule
