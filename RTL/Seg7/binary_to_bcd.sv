module binary_to_bcd (
    input  logic [9:0] binary_in,    // max 1023
    output logic [3:0] hundreds,
    output logic [3:0] tens,
    output logic [3:0] ones
);
    integer i;
    logic [19:0] shift_reg; 

    always_comb begin
        shift_reg = {10'b0, binary_in};

        for (i = 0; i < 10; i++) begin
            // if gratter than 5 add 3
            if (shift_reg[19:16] >= 5)
                shift_reg[19:16] += 3;
            if (shift_reg[15:12] >= 5)
                shift_reg[15:12] += 3;
            if (shift_reg[11:8] >= 5)
                shift_reg[11:8] += 3;

            // shift left
            shift_reg = shift_reg << 1;
        end

        // final
        hundreds = shift_reg[19:16];
        tens     = shift_reg[15:12];
        ones     = shift_reg[11:8];
    end
endmodule
