// ==========================================
// Random number generator (LFSR-based)
// ==========================================
module random2 #(
    parameter WIDTH = 8      // number of bits for the random number
)(
    input  logic clk,
    input  logic resetN,
    output logic [WIDTH-1:0] rnd
);

    logic [WIDTH-1:0] lfsr;

    // LFSR taps depend on WIDTH (primitive polynomial)
    // Example: WIDTH=8 uses taps at [7,5,4,3]
    always_ff @(posedge clk or negedge resetN) begin
        if (!resetN) begin
            lfsr <= 'h1;   // must not be zero
        end else begin
            lfsr <= {lfsr[WIDTH-2:0], 
                     lfsr[WIDTH-1] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        end
    end

    assign rnd = lfsr;

endmodule
