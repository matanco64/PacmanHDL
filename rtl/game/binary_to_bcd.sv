module binary_to_bcd (
    input logic [9:0] binary_in, // max 1023
    output logic [3:0] hundreds,
    output logic [3:0] tens,
    output logic [3:0] ones
);

logic [9:0] temp1, temp2;

always_comb begin
    // Calculate hundreds (0-10 for max 1023)
    if (binary_in >= 900)      hundreds = 9;
    else if (binary_in >= 800) hundreds = 8;
    else if (binary_in >= 700) hundreds = 7;
    else if (binary_in >= 600) hundreds = 6;
    else if (binary_in >= 500) hundreds = 5;
    else if (binary_in >= 400) hundreds = 4;
    else if (binary_in >= 300) hundreds = 3;
    else if (binary_in >= 200) hundreds = 2;
    else if (binary_in >= 100) hundreds = 1;
    else                       hundreds = 0;
    
    // Remainder after hundreds
    temp1 = binary_in - (hundreds * 100);
    
    // Calculate tens
    if (temp1 >= 90)      tens = 9;
    else if (temp1 >= 80) tens = 8;
    else if (temp1 >= 70) tens = 7;
    else if (temp1 >= 60) tens = 6;
    else if (temp1 >= 50) tens = 5;
    else if (temp1 >= 40) tens = 4;
    else if (temp1 >= 30) tens = 3;
    else if (temp1 >= 20) tens = 2;
    else if (temp1 >= 10) tens = 1;
    else                  tens = 0;
    
    // Ones is just the remainder
    ones = temp1 - (tens * 10);
end

endmodule