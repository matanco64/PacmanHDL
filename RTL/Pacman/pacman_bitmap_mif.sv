module pacman_bitmap_mif #(
  parameter int W = 32,
  parameter int H = 32
)(
  input  logic        clk,
  input  logic        resetN,
  input  logic [10:0] offsetX,          // pixel X within the local rect (dst)
  input  logic [10:0] offsetY,          // pixel Y within the local rect (dst)
  input  logic        InsideRectangle,  // "this pixel is inside my draw box"
  input  logic [3:0]  inputDirection,   // keypad-derived direction
  input  logic        startOfFrame,     // 1-pulse per frame (for animation)

  output logic        drawingRequest,
  output logic [7:0]  RGBout,           // 8-bit palette value
  output logic [2:0]  HitEdgeCode       // unused here, kept for interface
);
  // --- constants and direction mapping
  localparam logic [7:0] TRANSPARENT = 8'he3;

  localparam logic [3:0] DIR_RIGHT = 4'd6;
  localparam logic [3:0] DIR_UP    = 4'd8;
  localparam logic [3:0] DIR_LEFT  = 4'd4;
  localparam logic [3:0] DIR_DOWN  = 4'd2;

  // --- rotation mapping outputs
  logic [10:0] srcX, srcY;
  logic [10:0] displayWidth, displayHeight;
  logic        localInside;

  // ----------------------- Direction / rotation mapping ----------------------
  always_comb begin
    displayWidth  = W;
    displayHeight = H;
    srcX = 0;
    srcY = 0;

    unique case (inputDirection)
      DIR_RIGHT: begin
        displayWidth  = W;
        displayHeight = H;
        srcX = offsetX;
        srcY = offsetY;
      end

      DIR_UP: begin
        // rotate +90° CCW: srcX = W-1 - dstY; srcY = dstX
        displayWidth  = H;
        displayHeight = W;
        srcX = W - 1 - offsetY;
        srcY = offsetX;
      end

      DIR_LEFT: begin
        // rotate 180°: srcX = W-1 - dstX; srcY = H-1 - dstY
        displayWidth  = W;
        displayHeight = H;
        srcX = W - 1 - offsetX;
        srcY = H - 1 - offsetY;
      end

      DIR_DOWN: begin
        // rotate -90° (CW): srcX = dstY; srcY = H-1 - dstX
        displayWidth  = H;
        displayHeight = W;
        srcX = offsetY;
        srcY = H - 1 - offsetX;
      end

      default: begin
        displayWidth  = W;
        displayHeight = H;
        srcX = offsetX;
        srcY = offsetY;
      end
    endcase

    localInside = (offsetX < displayWidth) && (offsetY < displayHeight);
  end

  // ----------------------- Animation: mouth open/close -----------------------
  logic [3:0] frameCnt;
  logic       mouthOpen;
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      frameCnt  <= 4'd0;
      mouthOpen <= 1'b0;
    end else if (startOfFrame) begin
      frameCnt <= (frameCnt == 4'd7) ? 4'd0 : (frameCnt + 4'd1);
      if (frameCnt == 4'd7) mouthOpen <= ~mouthOpen;
    end
  end

  // ------------------------ Addressing and pipeline --------------------------
  // Row-major address: addr = srcY*W + srcX (W=32 => multiply is shift by 5)
  logic [9:0] addr;         // 0..1023
  logic       addr_valid;

  always_comb begin
    addr_valid = localInside && (srcX < W) && (srcY < H);
    addr       = (srcY[9:0] << $clog2(W)) + srcX[9:0]; // with W=32, shift by 5
  end

  // ROM synchronous read latency = 1 cycle -> pipeline valid + mouthOpen
  logic       addr_valid_d;
  logic       mouthOpen_d;
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      addr_valid_d <= 1'b0;
      mouthOpen_d  <= 1'b0;
    end else begin
      addr_valid_d <= addr_valid;
      mouthOpen_d  <= mouthOpen;
    end
  end

  // ------------------------------ Two ROMs -----------------------------------
  logic [7:0] q_open, q_closed;

  sprite_rom_mif_1k8 #(.MIF_FILE("pacman_mouth_open.mif"))  u_rom_open  (
    .clk (clk),
    .addr(addr),
    .q   (q_open)
  );

  sprite_rom_mif_1k8 #(.MIF_FILE("pacman_mouth_close.mif")) u_rom_close (
    .clk (clk),
    .addr(addr),
    .q   (q_closed)
  );

  // ------------------------------- Outputs -----------------------------------
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      RGBout      <= 8'h00;
      HitEdgeCode <= 3'h0;
    end else begin
      HitEdgeCode <= 3'h0;

      if (addr_valid_d) begin
        // q_* are valid now (1 cycle after addr), align with mouthOpen_d
        RGBout <= (mouthOpen_d ? q_open : q_closed);
      end else begin
        RGBout <= TRANSPARENT;
      end
    end
  end

  assign drawingRequest = (RGBout != TRANSPARENT);

endmodule