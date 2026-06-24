// =============================================================================
//
//  relu_ativ.v — Função de ativação ReLU
//
//  ReLU(x) = max(0, x)
//
//  Representação: Q4.12 (signed 16 bits) — mesma da sigmoid e tanh
//      x < 0  →  d_out = 0
//      x >= 0 →  d_out = x  (passa direto, sem alteração)
//
// =============================================================================

module ativacaoRelu (
    input  wire signed [15:0] d_in,
    output wire signed [15:0] d_out
);

    assign d_out = d_in[15] ? 16'sd0 : d_in;
    //              ↑               ↑      ↑
    //          bit de sinal    negativo  positivo: passa direto
endmodule