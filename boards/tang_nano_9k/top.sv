// Sipeed Tang Nano 9K (GW1NR-LV9QN88PC6/I5) + 5" 800x480 RGB LCD.
//
// Clocking: 27 MHz crystal -> rPLL -> 33.75 MHz, used as both the LCD pixel
// clock and the game clock. 896 x 517 total raster = 72.9 Hz, matching the
// DE-10's 72.8 Hz VGA mode, so the game runs at its original speed.
module top (
  input  logic       XTAL_IN,      // 27 MHz
  input  logic       BTN_RESET_N,  // S1, active low
  input  logic       BTN_USER_N,   // S2, active low: next level
  input  logic       UART_RX,      // from the BL702 USB-serial bridge
  output logic       UART_TX,
  output logic       LCD_CLK,
  output logic       LCD_DEN,
  output logic       LCD_HSYNC,
  output logic       LCD_VSYNC,
  output logic [4:0] LCD_R,
  output logic [5:0] LCD_G,
  output logic [4:0] LCD_B,
  output logic [5:0] LED_N         // active low
);
  localparam int CLK_HZ = 33_750_000;

  // ---------------------------------------------------------------- clock
  logic clk, pllLock;

  rPLL #(
    .FCLKIN("27"),
    .DEVICE("GW1NR-9C"),
    .IDIV_SEL(3),        // 27 / 4  = 6.75 MHz PFD
    .FBDIV_SEL(4),       //   * 5   = 33.75 MHz
    .ODIV_SEL(16)        // VCO 540 MHz
  ) pll (
    .CLKIN(XTAL_IN),
    .CLKOUT(clk),
    .LOCK(pllLock),
    .CLKOUTP(), .CLKOUTD(), .CLKOUTD3(),
    .RESET(1'b0), .RESET_P(1'b0),
    .CLKFB(1'b0), .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
    .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0)
  );

  // ---------------------------------------------------------------- reset
  // asserted asynchronously, released synchronously
  logic [1:0] rstSync;
  logic       resetN, rawResetN;
  assign rawResetN = pllLock && BTN_RESET_N;
  always_ff @(posedge clk or negedge rawResetN)
    if (!rawResetN) rstSync <= 2'b00;
    else            rstSync <= {rstSync[0], 1'b1};
  assign resetN = rstSync[1];

  // ---------------------------------------------------------------- controls
  logic [7:0] rxByte, buttons;
  logic       rxValid;

  uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(115_200)) uart (
    .clk, .resetN, .rx(UART_RX), .data(rxByte), .valid(rxValid)
  );

  // The host resends the button mask several times a second; if it goes quiet
  // (script closed, cable pulled) release everything instead of sticking.
  localparam int TIMEOUT = CLK_HZ / 2;
  logic [$clog2(TIMEOUT+1)-1:0] quiet;
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      buttons <= '0;
      quiet   <= '0;
    end else if (rxValid) begin
      buttons <= rxByte;
      quiet   <= '0;
    end else if (quiet == TIMEOUT) begin
      buttons <= '0;
    end else begin
      quiet <= quiet + 1'b1;
    end
  end

  logic [3:0] keyPad;
  logic       keyPadValid, star, slash, num, pauseN;

  gamepad pad (
    .clk, .resetN, .buttons, .keyPad, .keyPadValid, .star, .slash, .num, .pauseN
  );

  logic [1:0] userSync;
  always_ff @(posedge clk) userSync <= {userSync[0], BTN_USER_N};

  // ---------------------------------------------------------------- video
  logic [10:0] pixelX, pixelY;
  logic        startOfFrame, inGame, de, hsync, vsync;

  lcd_timing #(
    .H_ACT(800), .H_FRONT(32), .H_SYNC(4), .H_BACK(60),
    .V_ACT(480), .V_FRONT(13), .V_SYNC(4), .V_BACK(20)
  ) timing (
    .clk, .resetN, .pixelX, .pixelY, .startOfFrame, .inGame,
    .de, .hsync, .vsync
  );

  logic [7:0] rgb;

  pacman_core #(.CLK_HZ(CLK_HZ)) game (
    .clk, .resetN,
    .pixelX, .pixelY, .startOfFrame,
    .keyPad, .keyPadValid, .star, .slash, .num, .pauseN,
    .turbo(1'b0),
    .level_key(userSync[1]),
    .RGB(rgb)
  );

  // RGB332 -> RGB565 by bit replication; black outside the game window
  logic [7:0] px;
  assign px = inGame ? rgb : 8'h00;

  always_ff @(posedge clk) begin
    LCD_DEN   <= de;
    LCD_HSYNC <= hsync;
    LCD_VSYNC <= vsync;
    LCD_R     <= {px[7:5], px[7:6]};
    LCD_G     <= {px[4:2], px[4:2]};
    LCD_B     <= {px[1:0], px[1:0], px[1]};
  end
  assign LCD_CLK = clk;

  assign UART_TX = 1'b1;
  // LEDs mirror the controller so the UART link can be checked at a glance
  assign LED_N = ~{!pauseN, buttons[4], buttons[3], buttons[2], buttons[1], buttons[0]};
endmodule
