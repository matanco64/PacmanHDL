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


  // // -----------------------------------------------------------------------------
  // // Ghosts bitmaps
  // // -----------------------------------------------------------------------------

  logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][7:0] ghostShape =  {
  	{8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'he0,8'he0,8'hff,8'hff,8'he0,8'he0,8'he0,8'hff,8'hff,8'he0,8'he0,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'he0,8'hff,8'hff,8'hff,8'hff,8'he0,8'hff,8'hff,8'hff,8'hff,8'he0,8'he0,8'he3,8'he3},
  	{8'he3,8'he0,8'he0,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'he0,8'he0,8'he3,8'he3},
  	{8'he3,8'he0,8'he0,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'hff,8'hff,8'hff,8'hff,8'he0,8'hff,8'hff,8'hff,8'hff,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he0,8'hff,8'hff,8'he0,8'he0,8'he0,8'hff,8'hff,8'he0,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he3,8'he3,8'he0,8'he0,8'he3,8'he0,8'he0,8'he0,8'he3},
  	{8'he3,8'he0,8'he0,8'he3,8'he3,8'he0,8'he3,8'he3,8'he3,8'he0,8'he0,8'he3,8'he3,8'he0,8'he3,8'he3},
  	{8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3}};

  logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][7:0] power = {
  	{8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'he3,8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3,8'he3,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3,8'he3,8'he3},
  	{8'he3,8'he3,8'hCA,8'hCA,8'hCA,8'hFF,8'hFF,8'hCA,8'hCA,8'hFF,8'hFF,8'hCA,8'hCA,8'hCA,8'he3,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hFF,8'hFF,8'hCA,8'hCA,8'hFF,8'hFF,8'hCA,8'hCA,8'hCA,8'he3,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hCA,8'hFF,8'hFF,8'hCA,8'hFF,8'hFF,8'hCA,8'hFF,8'hFF,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hFF,8'hCA,8'hCA,8'hFF,8'hCA,8'hCA,8'hFF,8'hCA,8'hCA,8'hFF,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'he3,8'hCA,8'hCA,8'hCA,8'he3,8'hCA,8'hCA,8'hCA,8'he3,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'he3,8'hCA,8'hCA,8'hCA,8'he3,8'he3,8'hCA,8'hCA,8'he3,8'hCA,8'hCA,8'hCA,8'he3},
  	{8'he3,8'hCA,8'hCA,8'he3,8'he3,8'hCA,8'he3,8'he3,8'he3,8'hCA,8'hCA,8'he3,8'he3,8'hCA,8'he3,8'he3},
  	{8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3,8'he3}};
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
  // ghost map
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      RGBout <= TRANSPARENT_ENCODING;
    end else begin
      RGBout <= TRANSPARENT_ENCODING;  // Default

      if (localInside && (srcX < OBJECT_WIDTH_X) && (srcY < OBJECT_HEIGHT_Y)) begin
        if (gameState == POWER_UP_ST) begin
          // --- Power pellet mode ---
          RGBout <= power[srcY][srcX];

          // --- flickering mode ---
          if ((countH == 4'd0) && (countL <= 4'd4) && countL[0]) begin // Alternate every second using countL LSB
            RGBout <= power[srcY][srcX] == COLOR1 ? COLOR2 :
						 power[srcY][srcX] == COLOR2 ? COLOR1 :
						 power[srcY][srcX] ; // Keep other colors unchanged
          end
        end else begin
          // --- Normal mode ---
          RGBout <= (ghostShape[srcY][srcX] == BODY) ? ghostBodyColor : (isPupil(srcX, srcY, 0) || isPupil(srcX, srcY, 1))?  8'h00 : ghostShape[srcY][srcX];
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // outputs
  // ---------------------------------------------------------------------------

  assign drawingRequest = (RGBout != TRANSPARENT_ENCODING) ? 1'b1 : 1'b0;

endmodule

