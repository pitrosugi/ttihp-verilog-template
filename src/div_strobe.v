// Generate 1-cycle strobe every 'divisor' cycles (divisor>=1)
module div_strobe(
    input  wire        clk, rst,
    input  wire [15:0] divisor,
    output reg         stb
);
    reg [15:0] cnt;
    always @(posedge clk) begin
        if (rst) begin
            cnt <= 16'd0;
            stb <= 1'b0;
        end else begin
            if (cnt == divisor-1) begin
                cnt <= 16'd0;
                stb <= 1'b1;
            end else begin
                cnt <= cnt + 16'd1;
                stb <= 1'b0;
            end
        end
    end
endmodule
