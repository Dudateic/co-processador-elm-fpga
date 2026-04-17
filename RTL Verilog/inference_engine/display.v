/*
Módulo: display
Descrição:
    Este módulo implementa a interface de saída visual utilizando displays de
    7 segmentos, permitindo a visualização do estado do sistema, do opcode
    atual e do resultado da inferência.

    O comportamento do display é controlado por uma máquina de estados simples,
    que apresenta diferentes informações dependendo da condição do sistema:
        - IDLE : sistema em espera
        - BUSY : processamento em andamento
        - DONE : processamento finalizado
        - OP   : exibição do opcode selecionado

    Além disso, ao final da inferência, o valor da predição é armazenado
    e exibido no display.

Entradas:
    clk     : Clock do sistema.
    rst_n   : Reset assíncrono ativo em nível baixo.
    busy    : Indica que o sistema está em processamento.
    done    : Indica que o processamento foi concluído.
    pred    : Resultado da inferência (classe predita).
    opcode  : Código da operação atual.

Saídas:
    HEX0-HEX5 : Displays de 7 segmentos.

*/
module display (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        busy,
    input  wire        done,
    input  wire [3:0]  pred,
    input  wire [2:0]  opcode,

    output reg  [6:0]  HEX0,
    output reg  [6:0]  HEX1,
    output reg  [6:0]  HEX2,
    output reg  [6:0]  HEX3,
    output reg  [6:0]  HEX4,
    output reg  [6:0]  HEX5
);


    localparam [6:0]
        SEG_OFF = 7'h7F,
        SEG_I   = 7'h79,
        SEG_M   = 7'h2A,
        SEG_P   = 7'h0C,
        SEG_B   = 7'h03,
        SEG_G   = 7'h42,
        SEG_O   = 7'h40,
        SEG_A   = 7'h08,
        SEG_E   = 7'h06,
        SEG_R   = 7'h2F,
        SEG_Y   = 7'h11,
        SEG_U   = 7'h41,
        SEG_N   = 7'h2B,
        SEG_d   = 7'h21,
		  SEG_T   = 7'h07,
		  SEG_L   = 7'h47,
        SEG_S   = 7'h12;

    localparam [1:0]
        ST_IDLE = 2'd0,
        ST_BUSY = 2'd1,
        ST_DONE = 2'd2,
        ST_OP   = 2'd3;   
		  
    reg [1:0] state;
	 reg [1:0] status_reg;
	 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else if (done)
            state <= ST_DONE;
        else if (busy)
            state <= ST_BUSY;
        else if (~busy & ~done)
            state <= ST_OP;
    end


    reg [3:0] pred_latch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pred_latch <= 0;
        else if (done)
            pred_latch <= pred;
    end


    function [6:0] digit_seg;
        input [3:0] d;
        case (d)
            4'd0: digit_seg = 7'h40;
            4'd1: digit_seg = 7'h79;
            4'd2: digit_seg = 7'h24;
            4'd3: digit_seg = 7'h30;
            4'd4: digit_seg = 7'h19;
            4'd5: digit_seg = 7'h12;
            4'd6: digit_seg = 7'h02;
            4'd7: digit_seg = 7'h78;
            4'd8: digit_seg = 7'h00;
            4'd9: digit_seg = 7'h10;
            default: digit_seg = 7'h7F;
        endcase
    endfunction

    reg [6:0] o5, o4, o3, o2, o1;
    always @(*) begin
			
				case (opcode)

					3'b000: begin // IMG
						 o5 = SEG_I; 
						 o4 = SEG_M; 
						 o3 = SEG_G;
					end

					3'b001: begin // PES
						 o5 = SEG_P; 
						 o4 = SEG_E;
						 o3 = SEG_S;
					end

					3'b010: begin // BIA
						 o5 = SEG_B; 
						 o4 = SEG_I; 
						 o3 = SEG_A;
					end

					3'b011: begin // BET
						 o5 = SEG_B; 
						 o4 = SEG_E; 
						 o3 = SEG_T;
					end

					3'b100: begin // GO
						 o5 = SEG_G; 
						 o4 = SEG_O; 
						 o3 = SEG_OFF;
					end
					
					default: begin // ERROR
						 o5 = SEG_E;
						 o4 = SEG_R;
						 o3 = SEG_R;
						 o2 = SEG_O;
						 o1 = SEG_R;
					end
			endcase
    end

    always @(*) begin
        case (state)
            ST_IDLE: begin
                HEX5 = SEG_I;
                HEX4 = SEG_d;
                HEX3 = SEG_L;
                HEX2 = SEG_E;
                HEX1 = SEG_OFF;
                HEX0 = SEG_OFF;
            end

            ST_BUSY: begin
                HEX5 = SEG_B;
                HEX4 = SEG_U;
                HEX3 = SEG_S;
                HEX2 = SEG_Y;
                HEX1 = SEG_OFF;
                HEX0 = SEG_OFF;
            end

            ST_DONE: begin
                HEX5 = SEG_d;
                HEX4 = SEG_O;
                HEX3 = SEG_N;
                HEX2 = SEG_E;
                HEX1 = SEG_OFF;
					 if(opcode == 3'b101) 
						HEX0 = digit_seg(pred_latch);
					else
                    HEX0 = SEG_OFF;
            end

            ST_OP: begin
                HEX5 = o5;
                HEX4 = o4;
                HEX3 = o3;
                HEX2 = SEG_OFF;
                HEX1 = SEG_OFF;
                HEX0 = SEG_OFF;
            end

            default: begin
                HEX5 = o5; 
                HEX4 = o4;
                HEX3 = o3;
                HEX2 = o2;
                HEX1 = SEG_OFF;
                HEX0 = SEG_OFF;
            end
        endcase
    end

endmodule