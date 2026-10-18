module characterBitMap (
    input logic        clk,
    input logic        resetN,
    input logic        oneSec,
    input logic [ 7:0] rnd,
    input logic [10:0] offsetX,          
    input logic [10:0] offsetY,
    input logic        InsideRectangle,  
    input logic        startOfFrame,
    input logic [ 1:0] characterSelect,  // 2-bit selector: 00=Pacman, 01=Pinky, 10=Inky, 11=Blinky
    input logic [ 2:0] gameState,
    input logic [ 3:0] countL,
    input logic [ 3:0] countH,
    input logic [ 1:0] ghostDir,

    output logic       drawingRequest,  // pixel should be displayed
    output logic [7:0] RGBout           // RGB value from the bitmap 
);

  localparam int OBJECT_HEIGHT_Y = 16;
  localparam int OBJECT_WIDTH_X = 16;
  localparam [2:0] POWER_UP_ST = 3'b111;
  localparam logic [7:0] TRANSPARENT_ENCODING = 8'he3;
  localparam logic [7:0] COLOR1 = 8'hCA;  // power mode ghost color1
  localparam logic [7:0] COLOR2 = 8'hFF;
  localparam logic [7:0] BODY = 8'he0;
  localparam logic [7:0] EYE = 8'hff;

  // 2-bit encoding values (saves 75% memory!)
  localparam logic [1:0] ENC_TRANSPARENT = 2'd0;
  localparam logic [1:0] ENC_BODY = 2'd1;
  localparam logic [1:0] ENC_DETAIL = 2'd2;  // Eyes or other details

  // Format: {top, bottom, left, right} per eye of the pupil
  // [direction][eye_index][top/bottom/left/right]
  localparam logic [3:0] EYE_BOUNDARIES[0:3][0:1][0:3] = '{

      '{  // UP
          '{2, 5, 3, 6},  // Left eye
          '{2, 5, 8, 11}  // Right eye
       },

      '{  // DOWN
          '{6, 9, 3, 6},  // Left eye
          '{6, 9, 8, 11}  // Right eye
       },

      '{  // LEFT
          '{4, 7, 2, 5},  // Left eye
          '{4, 7, 7, 10}  // Right eye
       },

      '{  // RIGHT
          '{4, 7, 4, 7},  // Left eye
          '{4, 7, 9, 12}  // Right eye
       }
  };
  localparam logic [7:0] BLINKY_COLOR = 8'he0;
  localparam logic [7:0] PINKY_COLOR = 8'hf7;
  localparam logic [7:0] INKY_COLOR = 8'h3f;
  localparam logic [7:0] CLYDE_COLOR = 8'hfc;

  logic [10:0] srcX, srcY;
  logic [10:0] displayWidth, displayHeight;
  logic [7:0] ghostBodyColor;

  logic localInside;


  // -----------------------------------------------------------------------------
  // Optimized 2-bit ghost bitmaps
  // -----------------------------------------------------------------------------

  logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][1:0] ghostShape = {
  	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
  	{2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd0,2'd0},
  	{2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd2,2'd2,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0,2'd0},
  	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}};

  logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][1:0] power = {
  	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0,2'd0,2'd0},
  	{2'd0,2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd2,2'd2,2'd1,2'd2,2'd2,2'd1,2'd2,2'd2,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd2,2'd1,2'd1,2'd2,2'd1,2'd1,2'd2,2'd1,2'd1,2'd2,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0,2'd0,2'd1,2'd1,2'd0,2'd1,2'd1,2'd1,2'd0},
  	{2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0,2'd0,2'd0,2'd1,2'd1,2'd0,2'd0,2'd1,2'd0,2'd0},
  	{2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0,2'd0}};
  // -----------------------------------------------------------------------------


  function logic isPupil(input logic [10:0] x, y, input logic [1:0] eyeIdx);
      isPupil = (y > EYE_BOUNDARIES[ghostDir][eyeIdx][0]) &&
                (y < EYE_BOUNDARIES[ghostDir][eyeIdx][1]) &&
                (x > EYE_BOUNDARIES[ghostDir][eyeIdx][2]) &&
                (x < EYE_BOUNDARIES[ghostDir][eyeIdx][3]);
  endfunction

  // compute mapping and bounding box depending on direction
  always_comb begin
    // default
    displayWidth = OBJECT_WIDTH_X;
    displayHeight = OBJECT_HEIGHT_Y;
    srcY = offsetY;
    srcX = offsetX;

    // compute inside rectangle flag
    localInside = (offsetX < displayWidth) && (offsetY < displayHeight);
  end

  always_comb begin
    case (characterSelect)
      2'b00:   ghostBodyColor = BLINKY_COLOR;
      2'b01:   ghostBodyColor = PINKY_COLOR;
      2'b10:   ghostBodyColor = INKY_COLOR;
      2'b11:   ghostBodyColor = CLYDE_COLOR;
      default: ghostBodyColor = BLINKY_COLOR;
    endcase
  end

  // ---------------------------------------------------------------------------
  // ghost map with 2-bit encoding decoder
  // ---------------------------------------------------------------------------

  // The shape lookup is a reset-free registered read so it maps to block RAM;
  // everything else the colour depends on is registered alongside it (with
  // the reset), so RGBout is the same as the original output register.
  (* ram_style = "block" *) logic [3:0] shapes [0:255];  // {power, ghostShape} at {srcY, srcX}
  initial
    for (int y = 0; y < OBJECT_HEIGHT_Y; y++)
      for (int x = 0; x < OBJECT_WIDTH_X; x++)
        shapes[{y[3:0], x[3:0]}] = {power[y][x], ghostShape[y][x]};

  logic [3:0] shapePixel;
  logic       drawQ, powerUpQ, blinkQ, pupilQ;

  always_ff @(posedge clk)
    shapePixel <= shapes[{srcY[3:0], srcX[3:0]}];

  always_ff @(posedge clk) begin
    if (!resetN) begin
      drawQ    <= 1'b0;
      powerUpQ <= 1'b0;
      blinkQ   <= 1'b0;
      pupilQ   <= 1'b0;
    end else begin
      drawQ    <= localInside && (srcX < OBJECT_WIDTH_X) && (srcY < OBJECT_HEIGHT_Y);
      powerUpQ <= gameState == POWER_UP_ST;
      blinkQ   <= (countH == 4'd0) && (countL <= 4'd4) && countL[0];
      pupilQ   <= isPupil(srcX, srcY, 0) || isPupil(srcX, srcY, 1);
    end
  end

  always_comb begin
    RGBout = TRANSPARENT_ENCODING;  // Default
    if (drawQ) begin
      if (powerUpQ) begin
        case (shapePixel[3:2])
          ENC_BODY:        RGBout = blinkQ ? COLOR2 : COLOR1;
          ENC_DETAIL:      RGBout = blinkQ ? COLOR1 : COLOR2;
          default:         RGBout = TRANSPARENT_ENCODING;
        endcase
      end else begin
        case (shapePixel[1:0])
          ENC_BODY:        RGBout = ghostBodyColor;
          ENC_DETAIL:      RGBout = pupilQ ? 8'h00 : EYE;
          default:         RGBout = TRANSPARENT_ENCODING;
        endcase
      end
    end
  end

  assign drawingRequest = (RGBout != TRANSPARENT_ENCODING) ? 1'b1 : 1'b0;

endmodule