// Turns an 8-button "held" mask into the game's original keypad-style controls.
// The mask is the same whether it comes from the UART host script or, later,
// physical buttons on GPIO, so the game never knows which one is in use.
//
//   bit 0 Up   1 Down   2 Left   3 Right   4 A   5 B   6 Select   7 Start
package gamepad_pkg;
  typedef enum logic [2:0] {
    BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT, BTN_A, BTN_B, BTN_SELECT, BTN_START
  } button_e;
endpackage

module gamepad (
  input  logic       clk,
  input  logic       resetN,
  input  logic [7:0] buttons,      // 1 = held
  output logic [3:0] keyPad,       // 8=up 2=down 4=left 6=right
  output logic       keyPadValid,
  output logic       star,         // A
  output logic       slash,        // B
  output logic       num,          // Select
  output logic       pauseN        // toggled by Start
);
  import gamepad_pkg::*;

  // first held direction wins, in a fixed priority order
  always_comb begin
    keyPadValid = 1'b1;
    if      (buttons[BTN_UP])    keyPad = 4'd8;
    else if (buttons[BTN_DOWN])  keyPad = 4'd2;
    else if (buttons[BTN_LEFT])  keyPad = 4'd4;
    else if (buttons[BTN_RIGHT]) keyPad = 4'd6;
    else begin
      keyPad      = 4'd0;
      keyPadValid = 1'b0;
    end
  end

  assign star  = buttons[BTN_A];
  assign slash = buttons[BTN_B];
  assign num   = buttons[BTN_SELECT];

  // Start toggles pause (on the DE-10 this was a slide switch)
  logic startPrev;
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      startPrev <= 1'b0;
      pauseN    <= 1'b1;
    end else begin
      startPrev <= buttons[BTN_START];
      if (buttons[BTN_START] && !startPrev) pauseN <= !pauseN;
    end
  end
endmodule
