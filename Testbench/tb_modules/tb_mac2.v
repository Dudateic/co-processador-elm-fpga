`timescale 1ns / 1ps

module tb_mac;

    parameter integer N_INPUTS  = 128;
    parameter integer N_NEURONS = 10;
    parameter integer SHIFT_VAL = 12;

    reg        clk;
    reg        reset;
    reg        start;

    reg  signed [15:0] pixel;
    reg  signed [15:0] peso;

    reg  [9:0]  n_ops;
    reg  [4:0]  shift;

    wire [9:0]  addr;
    wire        done;
    wire signed [15:0] saida;

    reg signed [15:0] imagem  [0 : N_INPUTS-1];
    reg signed [15:0] pesos   [0 : N_NEURONS*N_INPUTS-1];
    reg signed [15:0] saidas  [0 : N_NEURONS-1];

    reg [7:0]  neuron_idx;

    integer fd_hex;
    integer i;
    integer max_idx;
    reg signed [15:0] max_val;

    mac uut (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .pixel (pixel),
        .peso  (peso),
        .bias  (16'sd0),
        .n_ops (n_ops),
        .shift (shift),
        .addr  (addr),
        .done  (done),
        .saida (saida)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @(addr, neuron_idx) begin
        pixel = imagem[addr];
        peso  = pesos[addr * N_NEURONS + neuron_idx];
    end

    task run_neuron;
        input [7:0] n;
        begin
            neuron_idx = n;
            start      = 1'b1;

            @(posedge done);

            @(posedge clk); #1;
            start = 1'b0;

            @(negedge done);
        end
    endtask

    initial begin

        $readmemh("saidas/ativacao.hex", imagem);
        $readmemh("pesosvies/beta_q.hex", pesos);

        fd_hex = $fopen("saidas/saida_final.hex", "w");

        reset      = 1'b1;
        start      = 1'b0;
        n_ops      = N_INPUTS[9:0];
        shift      = SHIFT_VAL[4:0];
        neuron_idx = 0;

        @(posedge clk); #1;
        reset = 1'b0;
        @(posedge clk); #1;

        $display("===========================================");
        $display(" SEGUNDA CAMADA");
        $display("===========================================");
        $display("Classe | Valor(dec) | Hex");
        $display("===========================================");

        for (neuron_idx = 0;
            neuron_idx < N_NEURONS;
            neuron_idx = neuron_idx + 1) begin

            run_neuron(neuron_idx);

            saidas[neuron_idx] = saida;

            $fwrite(fd_hex,"%04X\n", saida & 16'hFFFF);

            $display(
                "%6d | %10d | %04X",
                neuron_idx,
                $signed(saida),
                saida & 16'hFFFF
            );

        end


        // Predição
        max_val = -32768;
        max_idx = 0;

        for(i = 0; i < N_NEURONS; i = i + 1) begin
            if(saidas[i] > max_val) begin
                max_val = saidas[i];
                max_idx = i;
            end
        end

        $display("===========================================");
        $display("Predicao Final: %0d", max_idx);
        $display("===========================================");

        $fclose(fd_hex);
        $finish;

    end


    initial begin
        #(N_NEURONS * (N_INPUTS + 20) * 10 + 10000);
        $display("[TIMEOUT] Simulação excedeu tempo");
        $finish;
    end

endmodule
