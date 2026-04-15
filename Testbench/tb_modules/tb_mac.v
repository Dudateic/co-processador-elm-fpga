`timescale 1ns / 1ps

module tb_mac;
    parameter integer N_INPUTS  = 784;
    parameter integer N_NEURONS = 128;
    parameter integer SHIFT_VAL = 12;

    reg        clk;
    reg        reset;
    reg        start;

    reg  signed [15:0] pixel;
    reg  signed [15:0] peso;
    reg  signed [15:0] bias;

    reg  [9:0]  n_ops;
    reg  [4:0]  shift;

    wire [9:0]  addr;
    wire        done;
    wire signed [15:0] saida;

    reg signed [15:0] imagem  [0 : N_INPUTS-1];
    reg signed [15:0] pesos   [0 : N_NEURONS*N_INPUTS-1];
    reg signed [15:0] biases  [0 : N_NEURONS-1];
    reg signed [15:0] golden  [0 : N_NEURONS-1];

    reg [7:0]  neuron_idx;
    integer    fd_hex;

    mac uut (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .pixel (pixel),
        .peso  (peso),
        .bias  (bias),
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
        peso  = pesos[neuron_idx * N_INPUTS + addr];
    end

    task run_neuron;
        input [7:0] n;
        begin
            neuron_idx = n;
            bias       = biases[n];
            start      = 1'b1;

            @(posedge done);

            @(posedge clk); #1;
            start = 1'b0;

            @(negedge done);
        end
    endtask

    initial begin
        $readmemh("imgs/92.hex",           imagem);
        $readmemh("pesosvies/W_in_q.hex", pesos);
        $readmemh("pesosvies/b_q.hex",    biases);

        fd_hex = $fopen("saidas/camada1.hex", "w");

        reset      = 1'b1;
        start      = 1'b0;
        n_ops      = N_INPUTS[9:0];
        shift      = SHIFT_VAL[4:0];
        neuron_idx = 0;

        @(posedge clk); #1;
        reset = 1'b0;
        @(posedge clk); #1;

        $display("==========================================================");
        $display("TESTE - %0d neuronios x %0d entradas", N_NEURONS, N_INPUTS);
        $display("==========================================================");

        for (neuron_idx = 0;
            neuron_idx < N_NEURONS;
            neuron_idx = neuron_idx + 1) begin

            run_neuron(neuron_idx);
            $fwrite(fd_hex,"%04X\n", saida & 16'hFFFF);
            
            $display("Neuronio %3d | %6d (%04X)",
                    neuron_idx,
                    $signed(saida),
                    saida & 16'hFFFF);
        end
        
        $fclose(fd_hex);
        $finish;
    end

    initial begin
        #(N_NEURONS * (N_INPUTS + 20) * 10 + 10000);
        $display("[TIMEOUT] Simulação excedeu tempo");
        $finish;
    end
endmodule
