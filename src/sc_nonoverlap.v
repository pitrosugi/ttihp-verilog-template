// 2-phase non-overlap generator:
// base_div sets base period, gap inserts both-low region (non-overlap)

module sc_nonoverlap(
    input  wire        clk, rst,
    input  wire        enable,
    input  wire [15:0] base_div,
    input  wire [15:0] gap,
    output reg         phi1,
    output reg         phi2
);
    reg [15:0] cnt;
    localparam S_PHI1 = 2'd0, S_GAP1 = 2'd1, S_PHI2 = 2'd2, S_GAP2 = 2'd3;
    reg [1:0] state;

    always @(posedge clk) begin
        if (rst || !enable) begin
            cnt<=0; state<=S_PHI1; phi1<=1'b0; phi2<=1'b0;
        end else begin
            case (state)
                S_PHI1: begin
                    phi1<=1'b1; phi2<=1'b0;
                    if (cnt==base_div-1) begin cnt<=0; state<=S_GAP1; end
                    else cnt<=cnt+1;
                end
                S_GAP1: begin
                    phi1<=1'b0; phi2<=1'b0;
                    if (cnt==gap-1) begin cnt<=0; state<=S_PHI2; end
                    else cnt<=cnt+1;
                end
                S_PHI2: begin
                    phi1<=1'b0; phi2<=1'b1;
                    if (cnt==base_div-1) begin cnt<=0; state<=S_GAP2; end
                    else cnt<=cnt+1;
                end
                S_GAP2: begin
                    phi1<=1'b0; phi2<=1'b0;
                    if (cnt==gap-1) begin cnt<=0; state<=S_PHI1; end
                    else cnt<=cnt+1;
                end
            endcase
        end
    end
endmodule
