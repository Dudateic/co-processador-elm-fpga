module display_resultado (
    resultado_bin, // Vem da saída 'predicted_digit' do Argmax
    hex_out        // Vai ligado diretamente ao pino físico HEX7
);
    /*
    Entradas e saidas do modulo
    */
    input wire [3:0] resultado_bin; // Vem da saída 'predicted_digit' do Argmax
    output reg [6:0] hex_out ;       // Vai ligado diretamente ao pino físico HEX7

    // Mapeamento dos segmentos: {g, f, e, d, c, b, a}
    // 0 = Acende, 1 = Apaga
    always @(*) begin
        case(resultado_bin)
            4'h0: hex_out = 7'b1000000; // Mostra "0"
            4'h1: hex_out = 7'b1111001; // Mostra "1"
            4'h2: hex_out = 7'b0100100; // Mostra "2"
            4'h3: hex_out = 7'b0110000; // Mostra "3"
            4'h4: hex_out = 7'b0011001; // Mostra "4"
            4'h5: hex_out = 7'b0010010; // Mostra "5"
            4'h6: hex_out = 7'b0000010; // Mostra "6"
            4'h7: hex_out = 7'b1111000; // Mostra "7"
            4'h8: hex_out = 7'b0000000; // Mostra "8"
            4'h9: hex_out = 7'b0010000; // Mostra "9"
            
            // Caso o Argmax ainda não tenha terminado ou o valor seja inválido (10 a 15)
            // Mantém o display totalmente apagado (ou você pode colocar um 'E' de Erro: 7'b0000110)
            default: hex_out = 7'b1111111; 
        endcase
    end

endmodule