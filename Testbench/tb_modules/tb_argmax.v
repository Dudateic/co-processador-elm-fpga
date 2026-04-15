`timescale 1ns / 1ps

module tb_argmax;

    reg clk;
    reg reset;
    reg start;

    reg signed [15:0] y_in;
    reg [3:0] idx;

    wire [3:0] pred;
    wire done;

    // DUT
    argmax uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .y_in(y_in),
        .idx(idx),
        .pred(pred),
        .done(done)
    );

    always #5 clk = ~clk;

    reg signed [15:0] valores [0:9];

    integer i;
    reg signed [15:0] golden_max;
    reg [3:0] golden_idx;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        y_in = 0;
        idx = 0;

        valores[0] = 10;
        valores[1] = 5;
        valores[2] = 30;
        valores[3] = 7;
        valores[4] = 2;
        valores[5] = 99;
        valores[6] = 1;
        valores[7] = 50;
        valores[8] = 12;
        valores[9] = 8;

        #20 reset = 0;

        start = 1;

        golden_max = -32768;
        golden_idx = 0;

        $display("TESTE ARGMAX");
        for (i = 0; i < 10; i = i + 1) begin

            @(posedge clk);

            y_in = valores[i];
            idx  = i;

            // golden model
            if (valores[i] > golden_max) begin
                golden_max = valores[i];
                golden_idx = i;
            end

            $display("i=%0d | y_in=%0d | pred=%0d", i, y_in, pred);
        end

        wait(done == 1);

        #10;

        $display("RESULTADO FINAL");
        $display("DUT    : pred = %0d", pred);
        $display("GOLDEN : pred = %0d", golden_idx);

        if (pred == golden_idx)
            $display("STATUS : OK");
        else
            $display("STATUS : ERRO");

        $finish;
    end

endmodule