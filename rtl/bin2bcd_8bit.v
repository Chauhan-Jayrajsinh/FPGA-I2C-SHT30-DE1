// ============================================================================
// 8-Bit Binary to BCD Converter (Combinational Shift-Add-3)
// ============================================================================
module bin2bcd_8bit (
    input  wire [7:0] bin,
    output reg  [3:0] tens,
    output reg  [3:0] ones
);
    reg [3:0] hundreds; // Internal, not displayed
    integer i;
    always @(*) begin
        hundreds = 4'd0; tens = 4'd0; ones = 4'd0;
        for (i = 7; i >= 0; i = i - 1) begin
            if (hundreds >= 5) hundreds = hundreds + 3;
            if (tens >= 5)     tens = tens + 3;
            if (ones >= 5)     ones = ones + 3;
            hundreds = {hundreds[2:0], tens[3]};
            tens     = {tens[2:0], ones[3]};
            ones     = {ones[2:0], bin[i]};
        end
    end
endmodule
