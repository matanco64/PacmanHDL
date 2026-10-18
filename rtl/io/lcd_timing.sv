// Raster timing for a parallel-RGB LCD (DE mode), presenting the game with the
// same scan semantics as the DE-10 VGA_Controller:
//   * pixelX/pixelY count 0..GAME_W-1 / 0..GAME_H-1 inside the game window and
//     are held at 0 outside it (the game logic has always seen that in blanking)
//   * startOfFrame is a 1-clock pulse once per frame, during vertical blanking
// The game window is centered horizontally inside the panel's active area.
module lcd_timing #(
  parameter int H_ACT   = 800,
  parameter int H_FRONT = 32,
  parameter int H_SYNC  = 4,
  parameter int H_BACK  = 60,
  parameter int V_ACT   = 480,
  parameter int V_FRONT = 13,
  parameter int V_SYNC  = 4,
  parameter int V_BACK  = 20,
  parameter int GAME_W  = 640,
  parameter int GAME_H  = 480
) (
  input  logic        clk,
  input  logic        resetN,
  output logic [10:0] pixelX,
  output logic [10:0] pixelY,
  output logic        startOfFrame,
  output logic        inGame,       // current position is inside the game window
  output logic        de,
  output logic        hsync,        // active low
  output logic        vsync         // active low
);
  localparam int H_TOTAL = H_BACK + H_ACT + H_FRONT + H_SYNC;
  localparam int V_TOTAL = V_BACK + V_ACT + V_FRONT + V_SYNC;
  localparam int GAME_X0 = (H_ACT - GAME_W) / 2;
  localparam int GAME_Y0 = (V_ACT - GAME_H) / 2;

  // h/v count from the first active pixel; blanking is at the end of the line
  logic [10:0] h, v;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      h <= '0;
      v <= '0;
    end else if (h == H_TOTAL - 1) begin
      h <= '0;
      v <= (v == V_TOTAL - 1) ? '0 : v + 1'b1;
    end else begin
      h <= h + 1'b1;
    end
  end

  logic inX, inY;
  assign de     = (h < H_ACT) && (v < V_ACT);
  assign inX    = (h >= GAME_X0) && (h < GAME_X0 + GAME_W);
  assign inY    = (v >= GAME_Y0) && (v < GAME_Y0 + GAME_H);
  assign inGame = inX && inY;
  // like the VGA controller, X keeps sweeping during vertical blanking (Y = 0)
  assign pixelX = inX ? 11'(h - GAME_X0) : '0;
  assign pixelY = inY ? 11'(v - GAME_Y0) : '0;

  assign hsync = !((h >= H_ACT + H_FRONT) && (h < H_ACT + H_FRONT + H_SYNC));
  assign vsync = !((v >= V_ACT + V_FRONT) && (v < V_ACT + V_FRONT + V_SYNC));

  // pulse at the start of vertical sync, like the VGA controller's VS edge
  assign startOfFrame = (v == V_ACT + V_FRONT) && (h == 0);
endmodule
