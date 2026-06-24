module ativacaoSigm (
    input  wire signed [15:0] d_in,
    output reg  signed [15:0] d_out
);

    localparam signed [15:0] ONE  = 16'h1000;   // 1.0
    localparam signed [15:0] ZERO = 16'h0000;   // 0.0

    localparam signed [15:0] S00 = 16'h0800;   // sigmoid(0.00) = 0.500000
    localparam signed [15:0] S01 = 16'h08FF;   // sigmoid(0.25) = 0.562256
    localparam signed [15:0] S02 = 16'h09F6;   // sigmoid(0.50) = 0.622559
    localparam signed [15:0] S03 = 16'h0ADE;   // sigmoid(0.75) = 0.679199
    localparam signed [15:0] S04 = 16'h0BB2;   // sigmoid(1.00) = 0.730957
    localparam signed [15:0] S05 = 16'h0C70;   // sigmoid(1.25) = 0.777344
    localparam signed [15:0] S06 = 16'h0D15;   // sigmoid(1.50) = 0.817627
    localparam signed [15:0] S07 = 16'h0DA2;   // sigmoid(1.75) = 0.852051
    localparam signed [15:0] S08 = 16'h0E18;   // sigmoid(2.00) = 0.880859
    localparam signed [15:0] S09 = 16'h0EC9;   // sigmoid(2.50) = 0.924072
    localparam signed [15:0] S10 = 16'h0F3E;   // sigmoid(3.00) = 0.952637
    localparam signed [15:0] S11 = 16'h0F88;   // sigmoid(3.50) = 0.970703
    localparam signed [15:0] S12 = 16'h0FB6;   // sigmoid(4.00) = 0.981934
    localparam signed [15:0] S13 = 16'h0FD3;   // sigmoid(4.50) = 0.989014
    localparam signed [15:0] S14 = 16'h0FE5;   // sigmoid(5.00) = 0.993408
    localparam signed [15:0] S15 = 16'h0FEF;   // sigmoid(5.50) = 0.995850
    localparam signed [15:0] S16 = 16'h0FF6;   // sigmoid(6.00) = 0.997559
    localparam signed [15:0] S17 = 16'h0FFA;   // sigmoid(6.50) = 0.998535
    localparam signed [15:0] S18 = 16'h0FFC;   // sigmoid(7.00) = 0.999023
    localparam signed [15:0] S19 = 16'h0FFE;   // sigmoid(7.50) = 0.999512
    localparam signed [15:0] S20 = 16'h0FFF;   // sigmoid(8.00) = 0.999756

    localparam signed [15:0] L01 = 16'h0400;   //  0.25
    localparam signed [15:0] L02 = 16'h0800;   //  0.50
    localparam signed [15:0] L03 = 16'h0C00;   //  0.75
    localparam signed [15:0] L04 = 16'h1000;   //  1.00
    localparam signed [15:0] L05 = 16'h1400;   //  1.25
    localparam signed [15:0] L06 = 16'h1800;   //  1.50
    localparam signed [15:0] L07 = 16'h1C00;   //  1.75
    localparam signed [15:0] L08 = 16'h2000;   //  2.00
    localparam signed [15:0] L09 = 16'h2800;   //  2.50
    localparam signed [15:0] L10 = 16'h3000;   //  3.00
    localparam signed [15:0] L11 = 16'h3800;   //  3.50
    localparam signed [15:0] L12 = 16'h4000;   //  4.00
    localparam signed [15:0] L13 = 16'h4800;   //  4.50
    localparam signed [15:0] L14 = 16'h5000;   //  5.00
    localparam signed [15:0] L15 = 16'h5800;   //  5.50
    localparam signed [15:0] L16 = 16'h6000;   //  6.00
    localparam signed [15:0] L17 = 16'h6800;   //  6.50
    localparam signed [15:0] L18 = 16'h7000;   //  7.00
    localparam signed [15:0] L19 = 16'h7800;   //  7.50

    reg        negativo;
    reg signed [15:0] x;    // |d_in|
    reg signed [15:0] dx;   // offset dentro do segmento

    
    always @(*) begin
        negativo = d_in[15];

        if (d_in == -16'sd32768)
            x = 16'sd32767;
        else if (d_in < 0)
            x = -d_in;
        else
            x = d_in;

        if      (x < L01) begin dx = x;        d_out = S00 + (dx >>> 2); end
        else if (x < L02) begin dx = x - L01;  d_out = S01 + (dx >>> 2); end
        else if (x < L03) begin dx = x - L02;  d_out = S02 + (dx >>> 2); end
        else if (x < L04) begin dx = x - L03;  d_out = S03 + (dx >>> 2); end
        else if (x < L05) begin dx = x - L04;  d_out = S04 + (dx >>> 3); end
        else if (x < L06) begin dx = x - L05;  d_out = S05 + (dx >>> 3); end
        else if (x < L07) begin dx = x - L06;  d_out = S06 + (dx >>> 3); end
        else if (x < L08) begin dx = x - L07;  d_out = S07 + (dx >>> 3); end
        else if (x < L09) begin dx = x - L08;  d_out = S08 + (dx >>> 4); end
        else if (x < L10) begin dx = x - L09;  d_out = S09 + (dx >>> 4); end
        else if (x < L11) begin dx = x - L10;  d_out = S10 + (dx >>> 5); end
        else if (x < L12) begin dx = x - L11;  d_out = S11 + (dx >>> 6); end
        else if (x < L13) begin dx = x - L12;  d_out = S12 + (dx >>> 6); end
        else if (x < L14) begin dx = x - L13;  d_out = S13 + (dx >>> 7); end
        else if (x < L15) begin dx = x - L14;  d_out = S14 + (dx >>> 8); end
        else if (x < L16) begin dx = x - L15;  d_out = S15 + (dx >>> 8); end
        else if (x < L17) begin dx = x - L16;  d_out = S16 + (dx >>> 9); end
        else if (x < L18) begin dx = x - L17;  d_out = S17 + (dx >>> 10); end
        else if (x < L19) begin dx = x - L18;  d_out = S18 + (dx >>> 10); end
        else begin
            dx    = 16'h0000;
            d_out = S20;       
        end

        if (negativo)
            d_out = ONE - d_out;

        if (d_out < ZERO) d_out = ZERO;
        if (d_out > ONE)  d_out = ONE;
    end

endmodule