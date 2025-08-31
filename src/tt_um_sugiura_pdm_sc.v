// TinyTapeout user macro: PDM + Class-D driver + SC clocks + 1-bit CIC ADC path
// Author: sugiura (for TinyTapeout)
// License: MIT

module tt_um_sugiura_pdm_sc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ena,

    input  wire [7:0]  ui_in,    // inputs
    output wire [7:0]  uo_out,   // outputs
    input  wire [7:0]  uio_in,   // bidir in
    output wire [7:0]  uio_out,  // bidir out
    output wire [7:0]  uio_oe    // bidir oe (1=drive)
);

    // ------------------------------
    // Pin mapping
    // ------------------------------
    wire sdm_in   = ui_in[0];

    // uio: SPI & extra GPIO
    wire spi_sclk = uio_in[0];
    wire spi_mosi = uio_in[1];
    wire spi_cs_n = uio_in[3];
    reg  spi_miso_r;
    assign uio_out[2] = spi_miso_r;
    assign uio_oe[2]  = 1'b1;      // drive MISO
    assign uio_oe[4]  = 1'b1;      // drive sw3
    assign uio_out[4] = sw_ctrl[3];

    // rest uio tristate
    assign uio_out[7:5] = 3'b000;
    assign uio_oe[7:5]  = 3'b000;
    assign uio_out[1:0] = 2'b00;   // MOSI/SCLK are inputs
    assign uio_oe[1:0]  = 2'b00;
    assign uio_out[3]   = 1'b0;    // CS is input
    assign uio_oe[3]    = 1'b0;

    // ------------------------------
    // Global reset/enable
    // ------------------------------
    wire rst = ~rst_n | ~ena;  // disable when ena=0

    // ------------------------------
    // Simple SPI (Mode 0) register interface
    //   Address 8-bit, data 8-bit
    //   Writes push TX FIFO on addr 0x10 (LSB/MSB pair)
    //   Reads pop RX on 0x11 (LSB first)
    // ------------------------------
    wire        reg_wr, reg_rd;
    wire [7:0]  reg_addr;
    wire [7:0]  reg_wdata;
    reg  [7:0]  reg_rdata;

    spi_smallbus #(
        .ADDR_BITS(8),
        .DATA_BITS(8)
    ) u_spi (
        .clk       (clk),
        .rst       (rst),
        .sclk      (spi_sclk),
        .mosi      (spi_mosi),
        .miso      (spi_miso_r),
        .cs_n      (spi_cs_n),
        .wr_stb    (reg_wr),
        .rd_stb    (reg_rd),
        .addr      (reg_addr),
        .wdata     (reg_wdata),
        .rdata     (reg_rdata)
    );

    // ------------------------------
    // Registers
    // ------------------------------
    localparam [7:0] REG_VERSION     = 8'h00;
    localparam [7:0] REG_CTRL        = 8'h01;
    localparam [7:0] REG_CLKDIV_AUDIO= 8'h02;
    localparam [7:0] REG_PDM_OSR     = 8'h03;
    localparam [7:0] REG_DEADTIME    = 8'h04;
    localparam [7:0] REG_SC_DIV      = 8'h05;
    localparam [7:0] REG_SC_GAP      = 8'h06;
    localparam [7:0] REG_TX_FIFO     = 8'h10;
    localparam [7:0] REG_RX_DATA     = 8'h11;
    localparam [7:0] REG_STATUS      = 8'h12;

    // defaults
    reg        en_core       = 1'b0;
    reg        mute_pdm      = 1'b0;
    reg        classd_en     = 1'b0;
    reg        sc_en         = 1'b0;
    reg [15:0] clkdiv_audio  = 16'd1000;   // example divider
    reg [15:0] pdm_osr       = 16'd8;      // oversample factor
    reg [15:0] deadtime_cyc  = 16'd4;      // deadtime cycles at PDM clock
    reg [15:0] sc_div        = 16'd500;    // SC base divider
    reg [15:0] sc_gap        = 16'd8;      // non-overlap gap

    // TX sample write packing
    reg        tx_half;        // 0: expect LSB, 1: expect MSB
    reg [15:0] tx_sample_w;

    // RX sample read packing
    reg        rx_half;        // 0: read LSB, 1: read MSB
    wire [15:0] rx_sample_r;
    wire        rx_valid, rx_pop;
    reg         rx_pop_r;

    // simple status
    wire tx_empty, tx_full;
    reg  rx_overrun;

    // register write
    always @(posedge clk) begin
        if (rst) begin
            en_core      <= 1'b0;
            mute_pdm     <= 1'b0;
            classd_en    <= 1'b0;
            sc_en        <= 1'b0;
            clkdiv_audio <= 16'd1000;
            pdm_osr      <= 16'd8;
            deadtime_cyc <= 16'd4;
            sc_div       <= 16'd500;
            sc_gap       <= 16'd8;
            tx_half      <= 1'b0;
            rx_half      <= 1'b0;
            rx_overrun   <= 1'b0;
        end else begin
            if (reg_wr) begin
                case (reg_addr)
                    REG_CTRL: begin
                        en_core   <= reg_wdata[0];
                        mute_pdm  <= reg_wdata[1];
                        classd_en <= reg_wdata[2];
                        sc_en     <= reg_wdata[3];
                    end
                    REG_CLKDIV_AUDIO: clkdiv_audio[7:0] <= reg_wdata;
                    REG_CLKDIV_AUDIO+1: clkdiv_audio[15:8] <= reg_wdata;
                    REG_PDM_OSR:       pdm_osr[7:0] <= reg_wdata;
                    REG_PDM_OSR+1:     pdm_osr[15:8] <= reg_wdata;
                    REG_DEADTIME:      deadtime_cyc[7:0] <= reg_wdata;
                    REG_DEADTIME+1:    deadtime_cyc[15:8] <= reg_wdata;
                    REG_SC_DIV:        sc_div[7:0] <= reg_wdata;
                    REG_SC_DIV+1:      sc_div[15:8] <= reg_wdata;
                    REG_SC_GAP:        sc_gap[7:0] <= reg_wdata;
                    REG_SC_GAP+1:      sc_gap[15:8] <= reg_wdata;

                    // TX FIFO write: write LSB (addr 0x10), then MSB (0x11) to push
                    REG_TX_FIFO: begin
                        tx_sample_w[7:0] <= reg_wdata;
                        tx_half <= 1'b1;
                    end
                    REG_TX_FIFO+1: begin
                        if (tx_half && !tx_full) begin
                            tx_sample_w[15:8] <= reg_wdata;
                            tx_half <= 1'b0;
                            tx_push <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
            // latch RX overrun
            if (rx_valid && !rx_pop) rx_overrun <= 1'b1;
            if (reg_rd && reg_addr==REG_STATUS) rx_overrun <= 1'b0;
        end
    end

    // register read mux
    always @(*) begin
        case (reg_addr)
            REG_VERSION:       reg_rdata = 8'h25; // simple version tag
            REG_CTRL:          reg_rdata = {4'b0, sc_en, classd_en, mute_pdm, en_core};
            REG_CLKDIV_AUDIO:  reg_rdata = clkdiv_audio[7:0];
            REG_CLKDIV_AUDIO+1:reg_rdata = clkdiv_audio[15:8];
            REG_PDM_OSR:       reg_rdata = pdm_osr[7:0];
            REG_PDM_OSR+1:     reg_rdata = pdm_osr[15:8];
            REG_DEADTIME:      reg_rdata = deadtime_cyc[7:0];
            REG_DEADTIME+1:    reg_rdata = deadtime_cyc[15:8];
            REG_SC_DIV:        reg_rdata = sc_div[7:0];
            REG_SC_DIV+1:      reg_rdata = sc_div[15:8];
            REG_SC_GAP:        reg_rdata = sc_gap[7:0];
            REG_SC_GAP+1:      reg_rdata = sc_gap[15:8];

            // RX sample read LSB/MSB
            REG_RX_DATA:       reg_rdata = rx_sample_r[7:0];
            REG_RX_DATA+1:     reg_rdata = rx_sample_r[15:8];

            REG_STATUS:        reg_rdata = {4'b0, rx_overrun, rx_valid, tx_full, tx_empty};
            default:           reg_rdata = 8'h00;
        endcase
    end

    // generate rx_pop when host reads MSB
    always @(posedge clk) begin
        rx_pop_r <= 1'b0;
        if (!rst && reg_rd && reg_addr == (REG_RX_DATA+1))
            rx_pop_r <= 1'b1;
    end
    assign rx_pop = rx_pop_r;

    // ------------------------------
    // Audio TX path: TX FIFO -> sample strobe -> 2nd-order ΣΔ -> 1-bit
    // ------------------------------
    reg        tx_push;
    wire [15:0] tx_sample_r;
    wire        tx_valid, tx_pop;
    simple_fifo #(.WIDTH(16), .DEPTH(16)) u_tx_fifo (
        .clk(clk), .rst(rst),
        .wr_en(tx_push), .din(tx_sample_w),
        .rd_en(tx_pop), .dout(tx_sample_r),
        .empty(tx_empty), .full(tx_full)
    );
    // clear tx_push after one cycle
    always @(posedge clk) if (rst) tx_push <= 1'b0; else if (tx_push) tx_push <= 1'b0;

    // sample rate strobe from clkdiv_audio
    wire sample_stb;
    div_strobe u_stb_audio (.clk(clk), .rst(rst), .divisor(clkdiv_audio), .stb(sample_stb));

    // hold last sample if FIFO empty
    reg [15:0] cur_sample;
    always @(posedge clk) begin
        if (rst) cur_sample <= 16'sd0;
        else if (en_core && sample_stb) begin
            if (!tx_empty) begin
                cur_sample <= tx_sample_r;
            end
        end
    end
    assign tx_pop = en_core && sample_stb && !tx_empty;

    // PDM clock from pdm_osr divider
    wire pdm_clk_en;
    div_strobe u_stb_pdm (.clk(clk), .rst(rst), .divisor(pdm_osr), .stb(pdm_clk_en));

    // 2nd-order sigma-delta modulator (fixed-point 16-bit input)
    wire pdm_bit;
    sigma_delta_2nd #(.INW(16), .ACCW(24)) u_sdm (
        .clk(clk), .rst(rst),
        .clk_en(pdm_clk_en && en_core),
        .din(mute_pdm ? 16'sd0 : cur_sample),
        .dout(pdm_bit)
    );

    // ------------------------------
    // Class-D complementary with deadtime
    // ------------------------------
    wire classd_hi_w, classd_lo_w;
    classd_deadtime u_classd (
        .clk(clk), .rst(rst),
        .clk_en(pdm_clk_en && en_core && classd_en),
        .in_bit(pdm_bit),
        .deadtime(deadtime_cyc),
        .hi(classd_hi_w),
        .lo(classd_lo_w)
    );

    // ------------------------------
    // Switched-Capacitor 2-phase non-overlap clock
    // ------------------------------
    wire phi1_w, phi2_w;
    sc_nonoverlap u_sc (
        .clk(clk), .rst(rst),
        .enable(sc_en && en_core),
        .base_div(sc_div),
        .gap(sc_gap),
        .phi1(phi1_w),
        .phi2(phi2_w)
    );

    // ------------------------------
    // 1-bit SDM input -> CIC decimator -> 16-bit PCM
    // ------------------------------
    wire cic_stb;
    // run CIC strobe at sample_stb (same as TX side) for simplicity
    assign cic_stb = sample_stb & en_core;

    cic_decim_1bit #(.STAGES(3), .OUTW(16)) u_cic (
        .clk(clk), .rst(rst),
        .bit_in(sdm_in),
        .sample_stb(cic_stb),
        .dout(rx_sample_r),
        .dout_valid(rx_valid),
        .pop(rx_pop)
    );

    // ------------------------------
    // Sw control lines (for external analog switches)
    // simple mirror of CTRL bits and phi signals; can be extended by register map
    // ------------------------------
    wire [3:0] sw_ctrl = {phi2_w, phi1_w, classd_en, en_core};

    // ------------------------------
    // Outputs
    // ------------------------------
    assign uo_out[0] = pdm_bit;
    assign uo_out[1] = classd_hi_w;
    assign uo_out[2] = classd_lo_w;
    assign uo_out[3] = phi1_w;
    assign uo_out[4] = phi2_w;
    assign uo_out[5] = sw_ctrl[0];
    assign uo_out[6] = sw_ctrl[1];
    assign uo_out[7] = sw_ctrl[2];

endmodule
