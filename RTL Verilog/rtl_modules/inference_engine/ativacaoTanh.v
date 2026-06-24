module ativacaoTanh (
    input  wire signed [15:0] d_in,
    output reg  signed [15:0] d_out
);

    localparam signed [15:0] ONE  = 16'h1000;   
    localparam signed [15:0] MONE = 16'hF000;   

    localparam signed [15:0] T00 = 16'h0000;   // tanh(0.00) = 0.000000
    localparam signed [15:0] T01 = 16'h03EB;   // tanh(0.25) = 0.244919
    localparam signed [15:0] T02 = 16'h0765;   // tanh(0.50) = 0.462117
    localparam signed [15:0] T03 = 16'h0A2A;   // tanh(0.75) = 0.635149
    localparam signed [15:0] T04 = 16'h0C2F;   // tanh(1.00) = 0.761594
    localparam signed [15:0] T05 = 16'h0D93;   // tanh(1.25) = 0.848284
    localparam signed [15:0] T06 = 16'h0E7B;   // tanh(1.50) = 0.905148
    localparam signed [15:0] T07 = 16'h0F10;   // tanh(1.75) = 0.941376
    localparam signed [15:0] T08 = 16'h0F6D;   // tanh(2.00) = 0.964028
    localparam signed [15:0] T09 = 16'h0FC9;   // tanh(2.50) = 0.986614
    localparam signed [15:0] T10 = 16'h0FEC;   // tanh(3.00) = 0.995055
    localparam signed [15:0] T11 = 16'h0FF9;   // tanh(3.50) = 0.998178

    //  Limites superiores de cada segmento
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

        //  Tabela piecewise linear para x >= 0
        //
        //  Slopes aproximados com shifts (máx 2 termos):
        //    [0.00, 0.25]  slope=0.9795 → dx - (dx>>>6)           err 0.5%
        //    [0.25, 0.50]  slope=0.8691 → dx - (dx>>>3)           err 0.7%
        //    [0.50, 0.75]  slope=0.6924 → dx - (dx>>>2)           err 8.3% (*)
        //    [0.75, 1.00]  slope=0.5049 → (dx>>>1) + (dx>>>8)     err 0.2%
        //    [1.00, 1.25]  slope=0.3477 → (dx>>>1) - (dx>>>3)     err 7.9% (*)
        //    [1.25, 1.50]  slope=0.2266 → (dx>>>2) - (dx>>>5)     err 3.4%
        //    [1.50, 1.75]  slope=0.1455 → (dx>>>3) + (dx>>>6)     err 3.4%
        //    [1.75, 2.00]  slope=0.0908 → (dx>>>3) - (dx>>>5)     err 3.2%
        //    [2.00, 2.50]  slope=0.0449 → (dx>>>4) - (dx>>>6)     err 4.3%
        //    [2.50, 3.00]  slope=0.0171 → (dx>>>6) + (dx>>>9)     err 2.9%
        //    [3.00, 3.50]  slope=0.0063 → (dx>>>7) - (dx>>>9)     err 7.7%
        if      (x < L01) begin dx = x;        d_out = T00 + dx          - (dx >>> 6); end
        else if (x < L02) begin dx = x - L01;  d_out = T01 + dx          - (dx >>> 3); end
        else if (x < L03) begin dx = x - L02;  d_out = T02 + dx          - (dx >>> 2); end
        else if (x < L04) begin dx = x - L03;  d_out = T03 + (dx >>> 1)  + (dx >>> 8); end
        else if (x < L05) begin dx = x - L04;  d_out = T04 + (dx >>> 1)  - (dx >>> 3); end
        else if (x < L06) begin dx = x - L05;  d_out = T05 + (dx >>> 2)  - (dx >>> 5); end
        else if (x < L07) begin dx = x - L06;  d_out = T06 + (dx >>> 3)  + (dx >>> 6); end
        else if (x < L08) begin dx = x - L07;  d_out = T07 + (dx >>> 3)  - (dx >>> 5); end
        else if (x < L09) begin dx = x - L08;  d_out = T08 + (dx >>> 4)  - (dx >>> 6); end
        else if (x < L10) begin dx = x - L09;  d_out = T09 + (dx >>> 6)  + (dx >>> 9); end
        else if (x < L11) begin dx = x - L10;  d_out = T10 + (dx >>> 7)  - (dx >>> 9); end
        else begin
            dx    = 16'h0000;
            d_out = ONE;
        end

        if (negativo)
            d_out = -d_out;

        if (d_out >  ONE)  d_out =  ONE;
        if (d_out <  MONE) d_out =  MONE;
    end
endmodule
