module fog_mask  #(
    parameter int TILE_SIZE   = 16,
    parameter int MAP_WIDTH_X = 31,
    parameter int MAP_HEIGHT_Y = 28
)(
    input  logic        clk,
    input  logic        resetN,

    input  logic signed [10:0] pixelX,   // current VGA pixel
    input  logic signed [10:0] pixelY,

    input  logic [3:0]  level,           
    input  logic [10:0] pactopLeftX,     // Pac-Man top-left position
    input  logic [10:0] pactopLeftY,

    output logic        fogDR,           // fog enable
    output logic [7:0]  RGBfog           // fog color
);

    // Color
    localparam [7:0] FOG_COLOR = 8'h6D;   // gray fog
    localparam [7:0] TRANSPARENT_ENCODING = 8'hE3;
	 
	 logic signed [10:0] dx, dy;
    logic [23:0] dist2;
    logic [19:0] R2;

    // Radius per level
    logic [9:0] vis_radius;
    always_comb begin
        case (level)
				4'd3: vis_radius = 120;
				4'd4: vis_radius = 90;
				4'd5: vis_radius = 70;
            default: vis_radius = 1000;
        endcase
    end

    always_comb begin
        dx =  ((pixelX - (pactopLeftX + TILE_SIZE/2))*5)/4;  ; // pac center & aspect ratio ~1.25
        dy = pixelY - (pactopLeftY + TILE_SIZE/2);
        dist2 = dx*dx + dy*dy;
        R2 = vis_radius * vis_radius;

        fogDR = (dist2 > R2) && pixelX <= MAP_WIDTH_X * TILE_SIZE; // Fog active outside visible circle but within map

    end

    // Fixed fog color
    assign RGBfog = FOG_COLOR;

endmodule
