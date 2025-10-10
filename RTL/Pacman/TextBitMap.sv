// Versatile Text/Number Bitmap Display Module
// Displays strings of characters from an input array

module TextBitMap #(
    parameter MAX_CHARS = 16,           // Maximum characters to display
    parameter CHAR_WIDTH = 16,          // Width of each character in pixels
    parameter CHAR_HEIGHT = 16,         // Height of each character in pixels
    parameter CHAR_SPACING = 2          // Spacing between characters
) (
    input  logic clk,
    input  logic resetN,
    input  logic [10:0] pixelX,         // Current pixel X coordinate
    input  logic [10:0] pixelY,         // Current pixel Y coordinate
    input  logic [10:0] topLeftX,       // Top left corner X of text area
    input  logic [10:0] topLeftY,       // Top left corner Y of text area
    
    // Input: Array of character codes to display
    input  logic [5:0] charArray [0:MAX_CHARS-1],  // 6 bits per char (0-63)
    input  logic [3:0] numChars,        // Number of characters to display (1-16)
    
    // Color input
    input  logic [7:0] textColor,       // Color for the text
    
    output logic drawingRequest,        // Pixel should be displayed
    output logic [7:0] RGBout           // Pixel color
);

  // Character encoding (6 bits = 64 possible characters)
  // 0-9:  Digits 0-9
  // 10-35: Letters A-Z
  // 36: Space
  // 37-63: Special characters (can be extended)
  
  localparam CHAR_0 = 6'd0;
  localparam CHAR_1 = 6'd1;
  localparam CHAR_2 = 6'd2;
  localparam CHAR_3 = 6'd3;
  localparam CHAR_4 = 6'd4;
  localparam CHAR_5 = 6'd5;
  localparam CHAR_6 = 6'd6;
  localparam CHAR_7 = 6'd7;
  localparam CHAR_8 = 6'd8;
  localparam CHAR_9 = 6'd9;
  localparam CHAR_A = 6'd10;
  localparam CHAR_B = 6'd11;
  localparam CHAR_C = 6'd12;
  localparam CHAR_D = 6'd13;
  localparam CHAR_E = 6'd14;
  localparam CHAR_F = 6'd15;
  localparam CHAR_G = 6'd16;
  localparam CHAR_H = 6'd17;
  localparam CHAR_I = 6'd18;
  localparam CHAR_J = 6'd19;
  localparam CHAR_K = 6'd20;
  localparam CHAR_L = 6'd21;
  localparam CHAR_M = 6'd22;
  localparam CHAR_N = 6'd23;
  localparam CHAR_O = 6'd24;
  localparam CHAR_P = 6'd25;
  localparam CHAR_Q = 6'd26;
  localparam CHAR_R = 6'd27;
  localparam CHAR_S = 6'd28;
  localparam CHAR_T = 6'd29;
  localparam CHAR_U = 6'd30;
  localparam CHAR_V = 6'd31;
  localparam CHAR_W = 6'd32;
  localparam CHAR_X = 6'd33;
  localparam CHAR_Y = 6'd34;
  localparam CHAR_Z = 6'd35;
  localparam CHAR_SPACE = 6'd36;

  // Internal signals
  logic [10:0] relX, relY;             // Relative position within text area
  logic [3:0] charIndex;               // Which character we're in
  logic [4:0] charOffsetX, charOffsetY; // Offset within a character
  logic [5:0] currentChar;             // Current character code
  logic insideTextArea;
  logic pixelOn;

  // Character bitmaps (16x16 each)
  bit [0:15][0:15] charBitmaps [0:36];
  
  // Initialize character bitmaps
  initial begin
    // Digit 0
    charBitmaps[0] = '{
      16'b0000111111100000,
      16'b0011111111110000,
      16'b0111100001111000,
      16'b0111000000111000,
      16'b1110000000011100,
      16'b1110000000011100,
      16'b1110000000011100,
      16'b1110000000011100,
      16'b1110000000011100,
      16'b0111000000111000,
      16'b0111100001111000,
      16'b0011111111110000,
      16'b0000111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 1
    charBitmaps[1] = '{
      16'b0000001110000000,
      16'b0000011110000000,
      16'b0000111110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0001111111110000,
      16'b0001111111110000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 2
    charBitmaps[2] = '{
      16'b0001111111100000,
      16'b0011111111110000,
      16'b0111000001111000,
      16'b0000000000111000,
      16'b0000000001110000,
      16'b0000000011100000,
      16'b0000000111000000,
      16'b0000001110000000,
      16'b0000011100000000,
      16'b0000111000000000,
      16'b0001110000000000,
      16'b0111111111111000,
      16'b0111111111111000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 3
    charBitmaps[3] = '{
      16'b0001111111100000,
      16'b0011111111110000,
      16'b0111000001111000,
      16'b0000000000111000,
      16'b0000000001110000,
      16'b0000111111100000,
      16'b0000111111100000,
      16'b0000000001110000,
      16'b0000000000111000,
      16'b0000000000111000,
      16'b0111000001111000,
      16'b0011111111110000,
      16'b0001111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 4
    charBitmaps[4] = '{
      16'b0000000011100000,
      16'b0000000111100000,
      16'b0000001111100000,
      16'b0000011101110000,
      16'b0000111001110000,
      16'b0001110001110000,
      16'b0011100001110000,
      16'b0111111111111000,
      16'b0111111111111000,
      16'b0000000001110000,
      16'b0000000001110000,
      16'b0000000001110000,
      16'b0000000001110000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 5
    charBitmaps[5] = '{
      16'b0111111111110000,
      16'b0111111111110000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111111111100000,
      16'b0011111111110000,
      16'b0000000001111000,
      16'b0000000000111000,
      16'b0000000000111000,
      16'b0000000000111000,
      16'b0111000001111000,
      16'b0011111111110000,
      16'b0001111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 6
    charBitmaps[6] = '{
      16'b0000111111100000,
      16'b0011111111110000,
      16'b0111100001111000,
      16'b0111000000000000,
      16'b1110000000000000,
      16'b1111111111000000,
      16'b1111111111110000,
      16'b1110000001111000,
      16'b1110000000111000,
      16'b0111000000111000,
      16'b0111100001111000,
      16'b0011111111110000,
      16'b0000111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 7
    charBitmaps[7] = '{
      16'b0111111111111000,
      16'b0111111111111000,
      16'b0000000000111000,
      16'b0000000001110000,
      16'b0000000011100000,
      16'b0000000111000000,
      16'b0000001110000000,
      16'b0000011100000000,
      16'b0000111000000000,
      16'b0000111000000000,
      16'b0000111000000000,
      16'b0000111000000000,
      16'b0000111000000000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 8
    charBitmaps[8] = '{
      16'b0001111111100000,
      16'b0011111111110000,
      16'b0111000001111000,
      16'b0111000000111000,
      16'b0111000001111000,
      16'b0001111111100000,
      16'b0001111111100000,
      16'b0111000001111000,
      16'b0111000000111000,
      16'b0111000000111000,
      16'b0111000001111000,
      16'b0011111111110000,
      16'b0001111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Digit 9
    charBitmaps[9] = '{
      16'b0001111111100000,
      16'b0011111111110000,
      16'b0111100001111000,
      16'b0111000000111000,
      16'b0111000000111000,
      16'b0111100001111100,
      16'b0011111111111100,
      16'b0000111111011100,
      16'b0000000000111000,
      16'b0111000001111000,
      16'b0111100011110000,
      16'b0011111111100000,
      16'b0001111111000000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter A
    charBitmaps[10] = '{
      16'b0000001110000000,
      16'b0000011111000000,
      16'b0000111111000000,
      16'b0001110001110000,
      16'b0011100000111000,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111111111111100,
      16'b0111111111111100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter B
    charBitmaps[11] = '{
      16'b0111111111100000,
      16'b0111111111110000,
      16'b0111000001111000,
      16'b0111000000111000,
      16'b0111000001111000,
      16'b0111111111110000,
      16'b0111111111110000,
      16'b0111000001111000,
      16'b0111000000111000,
      16'b0111000000111000,
      16'b0111000001111000,
      16'b0111111111110000,
      16'b0111111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter C
    charBitmaps[12] = '{
      16'b0000011111100000,
      16'b0001111111110000,
      16'b0011110001111000,
      16'b0011100000111000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0011100000111000,
      16'b0011110001111000,
      16'b0001111111110000,
      16'b0000011111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter D
    charBitmaps[13] = '{
      16'b0111111111000000,
      16'b0111111111110000,
      16'b0111000001111000,
      16'b0111000000111000,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000111000,
      16'b0111000001111000,
      16'b0111111111110000,
      16'b0111111111000000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter E
    charBitmaps[14] = '{
      16'b0111111111111100,
      16'b0111111111111100,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111111111110000,
      16'b0111111111110000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111111111111100,
      16'b0111111111111100,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter F
    charBitmaps[15] = '{
      16'b0111111111111100,
      16'b0111111111111100,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111111111110000,
      16'b0111111111110000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0111000000000000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter G
    charBitmaps[16] = '{
      16'b0000111111110000,
      16'b0011111111111000,
      16'b0111100001111000,
      16'b0111000000111000,
      16'b1110000000000000,
      16'b1110000000000000,
      16'b1110001111111100,
      16'b1110001111111100,
      16'b1110000000111000,
      16'b0111000000111000,
      16'b0111100001111000,
      16'b0011111111110000,
      16'b0000111111100000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter H
    charBitmaps[17] = '{
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111111111111100,
      16'b0111111111111100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0111000000011100,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter I
    charBitmaps[18] = '{
      16'b0011111111111000,
      16'b0011111111111000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0000001110000000,
      16'b0011111111111000,
      16'b0011111111111000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter J - R (add more as needed)
    // For brevity, I'll create simplified versions
    charBitmaps[19] = charBitmaps[18]; // J (placeholder)
    charBitmaps[20] = charBitmaps[17]; // K (placeholder)
    charBitmaps[21] = charBitmaps[14]; // L (placeholder)
    charBitmaps[22] = charBitmaps[17]; // M (placeholder)
    charBitmaps[23] = charBitmaps[17]; // N (placeholder)
    charBitmaps[24] = charBitmaps[0];  // O (use digit 0)
    charBitmaps[25] = charBitmaps[15]; // P (placeholder)
    charBitmaps[26] = charBitmaps[0];  // Q (placeholder)
    
    // Letter R
    charBitmaps[27] = '{
      16'b0111111111100000,
      16'b0111111111110000,
      16'b0111000001111000,
      16'b0111000000111000,
      16'b0111000001111000,
      16'b0111111111110000,
      16'b0111111111000000,
      16'b0111001110000000,
      16'b0111000111000000,
      16'b0111000011100000,
      16'b0111000001110000,
      16'b0111000000111000,
      16'b0111000000011100,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Letter S
    charBitmaps[28] = '{
      16'b0000111111110000,
      16'b0001111111111000,
      16'b0011110001111000,
      16'b0011100000111000,
      16'b0011110000000000,
      16'b0001111111000000,
      16'b0000111111110000,
      16'b0000000011111000,
      16'b0000000001111000,
      16'b0011100001111000,
      16'b0011110011110000,
      16'b0001111111100000,
      16'b0000111111000000,
      16'b0000000000000000,
      16'b0000000000000000,
      16'b0000000000000000
    };
    
    // Remaining letters T-Z (simplified/placeholder)
    charBitmaps[29] = charBitmaps[18]; // T
    charBitmaps[30] = charBitmaps[0];  // U
    charBitmaps[31] = charBitmaps[10]; // V
    charBitmaps[32] = charBitmaps[17]; // W
    charBitmaps[33] = charBitmaps[10]; // X
    charBitmaps[34] = charBitmaps[18]; // Y
    charBitmaps[35] = charBitmaps[2];  // Z
    
    // Space
    charBitmaps[36] = '{default: 16'b0};
  end

  // Calculate relative position
  always_comb begin
    relX = (pixelX >= topLeftX) ? (pixelX - topLeftX) : 11'd0;
    relY = (pixelY >= topLeftY) ? (pixelY - topLeftY) : 11'd0;
    
    // Check if inside text area
    insideTextArea = (pixelX >= topLeftX) && 
                     (pixelY >= topLeftY) && 
                     (relY < CHAR_HEIGHT) &&
                     (relX < (numChars * (CHAR_WIDTH + CHAR_SPACING)));
    
    // Calculate which character and offset within character
    charIndex = relX / (CHAR_WIDTH + CHAR_SPACING);
    charOffsetX = relX % (CHAR_WIDTH + CHAR_SPACING);
    charOffsetY = relY;
    
    // Get current character
    currentChar = (charIndex < numChars) ? charArray[charIndex] : CHAR_SPACE;
    
    // Check if pixel is on (inside character, not in spacing)
    if (insideTextArea && charOffsetX < CHAR_WIDTH && currentChar < 37) begin
      pixelOn = charBitmaps[currentChar][charOffsetY][charOffsetX];
    end else begin
      pixelOn = 1'b0;
    end
  end

  // Output logic
  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      drawingRequest <= 1'b0;
    end else begin
      drawingRequest <= pixelOn;
    end
  end

  assign RGBout = textColor;

endmodule