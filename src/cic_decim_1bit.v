// Simple 1-bit CIC decimator (3-stage integrator/comb default).
// bit_in is +/-1 mapped from 0/1. sample_stb emits at output sample rate.
// pop pulses when host consumed the last provided sample.

module cic_decim_1bit #(parameter STAGES=3, parameter OUTW=16)(
    input  wire clk, rst,
    input  wire bit_in,
    input  wire sample_stb,
    output reg  [OUTW-1:0] dout,
    output reg  dout_valid,
    input  wire pop
);
    // map 0->-1, 1->+1
    wire signed [1:0] xin = bit_in ? 2'sd1 : -2'sd1;

    // integrators
    reg signed [23:0] i1,i2,i3;
    always @(posedge clk) begin
        if (rst) begin i1<=0; i2<=0; i3<=0; end
        else begin
            i1 <= i1 + xin;
            i2 <= i2 + i1;
            i3 <= i3 + i2;
        end
    end

    // combs on sample_stb
    reg signed [23:0] z1,z2,z3;
    reg signed [23:0] c1,c2,c3;
    always @(posedge clk) begin
        if (rst) begin
            z1<=0; z2<=0; z3<=0;
            c1<=0; c2<=0; c3<=0;
            dout<=0; dout_valid<=1'b0;
        end else begin
            if (sample_stb) begin
                c1 <= i3 - z1; z1 <= i3;
                c2 <= c1 - z2; z2 <= c1;
                c3 <= c2 - z3; z3 <= c2;
                // simple scaling/saturation to OUTW
                // take MSBs
                dout <= c3[23 -: OUTW];
                dout_valid <= 1'b1;
            end
            if (pop) dout_valid <= 1'b0;
        end
    end
endmodule
