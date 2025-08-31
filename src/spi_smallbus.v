// Minimal SPI slave, Mode 0: CPOL=0, CPHA=0
// Transaction: [8b addr][8b data], MSB-first.
// If MSB of addr=1 => READ, else WRITE.
// For READ, rdata is driven during data phase.
// cs_n must go low-high per transaction.

module spi_smallbus #(
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 8
)(
    input  wire                clk,
    input  wire                rst,
    input  wire                sclk,
    input  wire                mosi,
    output reg                 miso,
    input  wire                cs_n,

    output reg                 wr_stb,
    output reg                 rd_stb,
    output reg [ADDR_BITS-1:0] addr,
    output reg [DATA_BITS-1:0] wdata,
    input  wire [DATA_BITS-1:0] rdata
);
    reg sclk_d, cs_d;
    always @(posedge clk) begin
        sclk_d <= sclk;
        cs_d   <= cs_n;
    end
    wire sclk_rise = (sclk==1'b1 && sclk_d==1'b0);
    wire sclk_fall = (sclk==1'b0 && sclk_d==1'b1);
    wire cs_fall   = (cs_n==1'b0 && cs_d==1'b1);
    wire cs_rise   = (cs_n==1'b1 && cs_d==1'b0);

    reg [5:0] bitcnt;
    reg [7:0] shifter_in;
    reg [7:0] shifter_out;
    reg       phase_addr;
    reg       is_read;

    always @(posedge clk) begin
        wr_stb <= 1'b0;
        rd_stb <= 1'b0;
        if (rst) begin
            bitcnt     <= 6'd0;
            phase_addr <= 1'b1;
            miso       <= 1'b0;
        end else begin
            if (cs_rise) begin
                bitcnt     <= 6'd0;
                phase_addr <= 1'b1;
            end
            if (!cs_n && sclk_rise) begin
                // sample MOSI on rising edge (mode 0)
                shifter_in <= {shifter_in[6:0], mosi};
                bitcnt <= bitcnt + 6'd1;
                if (bitcnt == 6'd7 && phase_addr) begin
                    // just captured address
                    phase_addr <= 1'b0;
                end else if (bitcnt == 6'd15) begin
                    // full 16 bits captured
                    bitcnt <= 6'd0;
                    phase_addr <= 1'b1;
                end
            end
            if (!cs_n && sclk_fall) begin
                // drive MISO on falling edge
                miso <= shifter_out[7];
                shifter_out <= {shifter_out[6:0], 1'b0};
            end

            // decode when we complete address or data
            if (!cs_n && sclk_rise && (bitcnt==6'd8) && phase_addr==1'b0) begin
                // address is in shifter_in after 8 clocks
                // MSB=1 for read
                is_read <= shifter_in[7];
                addr    <= shifter_in;
                if (shifter_in[7]) begin
                    // prepare rdata into shifter_out
                    shifter_out <= rdata;
                end
            end
            if (!cs_n && sclk_rise && (bitcnt==6'd16)) begin
                // data phase complete
                if (is_read) begin
                    rd_stb <= 1'b1;
                end else begin
                    wdata  <= shifter_in;
                    wr_stb <= 1'b1;
                end
            end
        end
    end
endmodule
