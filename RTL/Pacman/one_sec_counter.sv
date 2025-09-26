module one_sec_counter (
    input wire clk,         // 50 MHz clock input
    input wire reset,       // Active-high synchronous reset
    output reg [3:0] count  // 4-bit counter output
);

    // 26-bit register to count 50 million clock cycles
    reg [25:0] clk_divider;

    always @(posedge clk) begin
        if (reset) begin
            clk_divider <= 0;
            count <= 0;
        end else begin
            if (clk_divider == 26'd49_999_999) begin
                clk_divider <= 0;
                count <= count + 1;
            end else begin
                clk_divider <= clk_divider + 1;
            end
        end
    end

endmodule
