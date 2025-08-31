// Convert 1-bit stream to complementary outputs with deadtime.
// When in_bit toggles, enforce both low for 'deadtime' clk_en pulses.

module classd_deadtime(
    input  wire        clk, rst,
    input  wire        clk_en,        // one tick per PDM bit
    input  wire        in_bit,
    input  wire [15:0] deadtime,      // cycles of clk_en
    output reg         hi,
    output reg         lo
);
    reg last_bit;
    reg [15:0] dt_cnt;
    reg        in_dead;

    always @(posedge clk) begin
        if (rst) begin
            last_bit <= 1'b0;
            dt_cnt   <= 16'd0;
            in_dead  <= 1'b0;
            hi <= 1'b0; lo <= 1'b0;
        end else if (clk_en) begin
            if (in_dead) begin
                if (dt_cnt == 16'd0) begin
                    in_dead <= 1'b0;
                end else begin
                    dt_cnt <= dt_cnt - 16'd1;
                end
                hi <= 1'b0; lo <= 1'b0;
            end else begin
                if (in_bit != last_bit) begin
                    // enter deadtime
                    in_dead  <= 1'b1;
                    dt_cnt   <= (deadtime==0)?16'd0:(deadtime-16'd1);
                    hi <= 1'b0; lo <= 1'b0;
                end else begin
                    // drive complementary
                    hi <= in_bit;
                    lo <= ~in_bit;
                end
                last_bit <= in_bit;
            end
        end
    end
endmodule
