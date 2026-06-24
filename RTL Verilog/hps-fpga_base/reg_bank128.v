
/*************************************************************
	MODULO DO BANCO DE 128 REGISTRADORES PARA A REDE NEURAL
	DESENVOLVIDO POR MAIKE DE OLIVEIRA NASCIMENTO MONITOR DA MATERIA DE SISTEMAS DIGITAIS
	
**************************************************************/

module reg_bank128 (
    clk,
    wr_en,             
    addr_w,              
    data_in,     
    addr_r,              
    data_out   
);

    /*****************************************************
    Entradas e saidas do modulo
    *****************************************************/
    input wire clk;
    input wire wr_en;             
    input wire [6:0] addr_w;        
    input wire signed [15:0] data_in;
    input wire [6:0] addr_r;              
    output reg signed [15:0] data_out; 

    //Declaraçao da matriz de registradores
    reg signed [15:0] memoria [0:127];

    //A escrita ocorre sempre na borda de subida do clock assim como a leitura
    always @(posedge clk) begin
        if (wr_en) begin
            memoria[addr_w] <= data_in;
        end
		  data_out = memoria[addr_r];
    end
endmodule