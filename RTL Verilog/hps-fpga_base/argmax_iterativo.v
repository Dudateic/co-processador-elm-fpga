
/*****************************************************************************************
	MODULO DE ARGMAX PARA A REDE NEURAL
	DESENVOLVIDO POR MAIKE DE OLIVEIRA NASCIMENTO MONITOR DA MATERIA DE SISTEMAS DIGITAIS
*****************************************************************************************/


module argmax_iterativo (
	clk,
    rst,
	enable,
    addr_r,
    data_in, 
	predicted_digit, 
	done                   
);
	
	/***********************************************
	Entradas e saidas do modulo
	***********************************************/
	input clk, rst, enable;
	input signed [15:0] data_in;
	output [3:0] addr_r;
	output reg [3:0] predicted_digit;
	output reg done;
	
	
	/*************************************************
	Estados da FMS do argmax
	
	*************************************************/
	
	localparam IDLE = 2'd0;
    localparam REQUEST_DATA = 2'd1;
    localparam EVALUATE = 2'd2;
	
	/****************************************
	Registradores e wires de dados
	****************************************/
    reg [3:0] counter;
    reg signed [15:0] max_score;
    reg [3:0] best_digit;
    
    /***************************************
	Registrador de estado
	***************************************/
    reg [1:0] state;
    
	
	/*O endereço a ser buscado sera o mesmo do contador*/
    assign addr_r = counter;

	
	/****************************************************
	Logica sequencial e combinacional do argmax
	
	****************************************************/
    always @(posedge clk) begin
        if (rst) begin
            counter <= 4'd0;
            max_score <= -16'sd32768; /*inicia armazenando o menor valor possivel para o argmax*/
            best_digit <= 4'd0;
            predicted_digit <= 4'd0;
            done <= 1'b0;
            state <= IDLE;
        end else if (enable) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    max_score <= -16'sd32768;
                    state <= REQUEST_DATA;
                end
                
                REQUEST_DATA: begin
                    state <= EVALUATE;
                end
                
                EVALUATE: begin
                    if (data_in > max_score) begin
                        max_score <= data_in;
                        best_digit <= counter;
                    end                  
                    if (counter == 4'd9) begin
                        if (data_in > max_score) begin
                            predicted_digit <= counter;
                        end else begin
                            predicted_digit <= best_digit;
                        end                        
                        done <= 1'b1; 
                        state <= IDLE;
                    end else begin
                        counter <= counter + 4'd1;
                        state <= REQUEST_DATA;
                    end
                end
            endcase
        end else begin
            done <= 1'b0;
            counter <= 4'd0;
            state <= IDLE;
        end
    end

endmodule