// Simple 2nd-order sigma-delta for audio (signed input)
// clk_en asserts at PDM rate (derived from clk by divider)
module sigma_delta_2nd #(parameter INW=16, parameter ACCW=24)(
    input  wire                 clk, rst,
    input  wire                 clk_en,
    input  wire signed [INW-1:0] din,
    output reg                  dout
);
    // scale input to ACCW
    wire signed [ACCW-1:0] xin = {{(ACCW-INW){din[INW-1]}}, din};

    reg signed [ACCW-1:0] e1, e2;   // error accumulators
    reg signed [ACCW-1:0] y;        // 1-bit DAC feedback as +/- full-scale

    always @(posedge clk) begin
        if (rst) begin
            e1 <= 0; e2 <= 0; y <= 0; dout <= 1'b0;
        end else if (clk_en) begin
            // 1-bit DAC: y = +FS or -FS
            y   <= dout ? {{(ACCW-1){1'b0}},1'b1} <<< (ACCW-2) : - ({{(ACCW-1){1'b0}},1'b1} <<< (ACCW-2));
            // loop
            e1  <= e1 + (xin - y);
            e2  <= e2 + (e1 - y);
            // quantizer
            dout<= ~e2[ACCW-1]; // sign
        end
    end
endmodule
