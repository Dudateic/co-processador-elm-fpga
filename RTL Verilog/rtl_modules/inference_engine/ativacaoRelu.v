module ativacaoRelu (
    input  wire signed [15:0] d_in,
    output wire signed [15:0] d_out
);

    assign d_out = d_in[15] ? 16'sd0 : d_in;

endmodule