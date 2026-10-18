// sideBitMapTop: converted from the Quartus schematic RTL/Bitmaps/sideBitMapTop.bdf (see DE-10 branch).
module sideBitMapTop #(
  parameter COLOR = 8'b11111110,
  parameter WIDTH = 8,
  parameter HEIGHT = 16
) (
  input logic clk,
  input logic resetN,
  input logic [10:0] pixelX,
  input logic [10:0] pixelY,
  input logic [10:0] topLeftX,
  input logic [10:0] topLeftY,
  input logic [2:0] gameState,
  output logic sideDR,
  output logic [7:0] RGBside
);
  logic BoxDrawingRequest;
  logic [7:0] BoxRGB;
  logic [10:0] Box_offsetX;
  logic [10:0] Box_offsetY;

  square_object #(.OBJECT_WIDTH_X(WIDTH), .OBJECT_HEIGHT_Y(HEIGHT), .OBJECT_COLOR(COLOR)) inst8 (
    .clk(clk),
    .resetN(resetN),
    .pixelX(pixelX[10:0]),
    .pixelY(pixelY[10:0]),
    .topLeftX(topLeftX[10:0]),
    .topLeftY(topLeftY[10:0]),
    .offsetX(Box_offsetX[10:0]),
    .offsetY(Box_offsetY[10:0]),
    .drawingRequest(BoxDrawingRequest),
    .RGBout(BoxRGB[7:0])
  );
  sideBitMapV1 inst (
    .clk(clk),
    .resetN(resetN),
    .offsetX(Box_offsetX[10:0]),
    .offsetY(Box_offsetY[10:0]),
    .InsideRectangle(BoxDrawingRequest),
    .gameState(gameState[2:0]),
    .drawingRequest(sideDR),
    .RGBout(RGBside[7:0])
  );
endmodule
