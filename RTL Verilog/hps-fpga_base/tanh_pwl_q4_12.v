module tanh_pwl_q4_12(
    x,
    y
);
    /***************************
    Entradas e saidas do modulo
    ***************************/
    input signed [15:0] x;
    output reg signed [15:0] y;

    /*****************************
    Fios e registradores de dados
    *****************************/
    reg signed [15:0] abs_x;
    reg signed [15:0] abs_y;

    /*******************************************************************************
    Logica da função de ativação aproximada por partes lineares
    *******************************************************************************/

    always @(*) begin
        // PASSO 1: Obter o valor absoluto de x
        if (x < 16'sd0) begin
            abs_x = -x;
        end else begin
            abs_x = x;
        end

        // PASSO 2: Calcular a aproximação linear (Agora com 4 degraus)
        if (abs_x >= 16'sd0 && abs_x < 16'sd2048) begin
            // 0 <= abs_x < 0.5
            abs_y = abs_x;
        end
        else if (abs_x >= 16'sd2048 && abs_x < 16'sd4096) begin
            // 0.5 <= abs_x < 1.0  |  y = 0.5x + 0.25
            abs_y = (abs_x >>> 1) + 16'sd1024; 
        end
        else if (abs_x >= 16'sd4096 && abs_x < 16'sd6144) begin
            // 1.0 <= abs_x < 1.5  |  y = 0.25x + 0.5
            abs_y = (abs_x >>> 2) + 16'sd2048;
        end
        else if (abs_x >= 16'sd6144 && abs_x < 16'sd10240) begin
            // 1.5 <= abs_x < 2.5  |  y = 0.125x + 0.6875
            abs_y = (abs_x >>> 3) + 16'sd2816;
        end
        else begin
            // abs_x >= 2.5  |  y = 1
            abs_y = 16'sd4096;
        end

        // PASSO 3: Reaplicar o sinal original para obter y
        if (x < 16'sd0) begin
            y = -abs_y;
        end else begin
            y = abs_y;
        end
    end

endmodule