module sideBitMapV1	(	
  input  logic        clk,
  input  logic        resetN,
  input  logic [10:0] offsetX,
  input  logic [10:0] offsetY,
  input  logic        InsideRectangle,
  input  logic [2:0]  gameState,

  output logic        drawingRequest,
  output logic [7:0]  RGBout
);

  // --- game states (copied from your original)
  localparam RESET_ST       = 3'b000;
  localparam START_WAIT_ST  = 3'b001;
  localparam PLAYING_ST     = 3'b010;
  localparam PAUSED_ST      = 3'b011;
  localparam GHOST_HIT_ST   = 3'b100;
  localparam WIN_ST         = 3'b101;
  localparam LOSE_ST        = 3'b110;
  localparam POWER_UP_ST    = 3'b111;

  // bound to 64x64; use only low 6 bits
  wire [5:0] x = offsetX[5:0];
  wire [5:0] y = offsetY[5:0];

  // addr = y*64 + x  => {y, x} because 64 = 2^6
  wire [11:0] addr = {y, x};

  // ROM outputs (1-bit pixels), synchronous 1-cycle late
  logic pix_start, pix_play, pix_pause, pix_win, pix_lose;

  rom #(.WIDTH(1), .DEPTH(4096), .INIT_FILE("assets/side/start.hex")) u_rom_start (
    .clk (clk), .addr (addr), .q (pix_start)
  );

  rom #(.WIDTH(1), .DEPTH(4096), .INIT_FILE("assets/side/play.hex")) u_rom_play (
    .clk (clk), .addr (addr), .q (pix_play)
  );

  rom #(.WIDTH(1), .DEPTH(4096), .INIT_FILE("assets/side/pause.hex")) u_rom_pause (
    .clk (clk), .addr (addr), .q (pix_pause)
  );

  rom #(.WIDTH(1), .DEPTH(4096), .INIT_FILE("assets/side/win.hex")) u_rom_win (
    .clk (clk), .addr (addr), .q (pix_win)
  );

  rom #(.WIDTH(1), .DEPTH(4096), .INIT_FILE("assets/side/lose.hex")) u_rom_lose (
    .clk (clk), .addr (addr), .q (pix_lose)
  );

  // Pipeline control signals to align with ROM read latency
  logic inside_d1;
  logic [2:0] state_d1;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      inside_d1 <= 1'b0;
      state_d1  <= PLAYING_ST;
    end else begin
      // Gate “inside” and also ensure x,y are in-range (defensive)
      inside_d1 <= InsideRectangle & (offsetX[10:6] == 5'd0) & (offsetY[10:6] == 5'd0);
      state_d1  <= gameState;
    end
  end

  // Select the pixel for the delayed state; default to "play"
  logic selected_pix;
  always_comb begin
    unique case (state_d1)
      START_WAIT_ST: selected_pix = pix_start;
      PAUSED_ST:     selected_pix = pix_pause;
      WIN_ST:        selected_pix = pix_win;
      LOSE_ST:       selected_pix = pix_lose;
      default:       selected_pix = pix_play;
    endcase
  end

  // Final registered output (optional; you can make it purely combinational if you like)
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      drawingRequest <= 1'b0;
    end else begin
      drawingRequest <= (inside_d1 ? selected_pix : 1'b0);
    end
  end

  // Same as your original
  assign RGBout = 8'hFF;

endmodule