`timescale 1ns / 1ps

module tb_ativacao;
    parameter N_NEURONS = 128;

    reg  signed [15:0] d_in;
    wire signed [15:0] d_out;

    ativacao dut (
        .d_in(d_in),
        .d_out(d_out)
    );

    reg signed [15:0] entrada [0:N_NEURONS-1];
    reg signed [15:0] saida   [0:N_NEURONS-1];

    integer i;
    integer fd_hex;

    function real q412_to_real;
        input signed [15:0] v;
        begin
            q412_to_real = v / 4096.0;
        end
    endfunction

    initial begin

        $display("==========================================");
        $display(" Teste Funcao Sigmoide");
        $display("==========================================");

        $readmemh("saidas/camada1.hex", entrada);
        fd_hex = $fopen("saidas/ativacao.hex", "w");

        #10;

        for (i = 0; i < N_NEURONS; i = i + 1) begin
            d_in = entrada[i];

            #1;

            saida[i] = d_out;

            $fdisplay(fd_hex,"%04h", d_out);

            $display("%3d | %6d | %8f | %6d | %8f | %04h",
                    i,
                    entrada[i],
                    q412_to_real(entrada[i]),
                    d_out,
                    q412_to_real(d_out),
                    d_out
            );
        end

        $fclose(fd_hex);

        #10;
        $finish;

    end

endmodule
