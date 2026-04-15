/*
Módulo: co_processador
Descrição:
    Este módulo implementa o bloco de controle de um coprocessador em FPGA,
    sendo responsável por interpretar comandos provenientes de chaves (SW)
    e botões (KEY), convertendo-os em sinais de controle para uma máquina
    de estados finita (FSM).

    O sistema gerencia a escrita em diferentes memórias internas, incluindo
    imagem, pesos, bias e beta, além de controlar o fluxo de execução da
    inferência.

    Adicionalmente, o módulo realiza a interface com displays de 7 segmentos,
    permitindo a visualização do estado do sistema, da operação em execução
    e dos resultados obtidos.

Entradas:
    clk        : Sinal de clock do sistema.
	 
    ativacao   : Sinal de seleção da função de ativação utilizada na FSM,
                 permitindo alternar entre a função sigmoide e tangente 
					  hiperbólica.
					  
    KEY        : Botões físicos de controle:
                 - KEY[0]: reset (ativo em nível baixo)
                 - KEY[1]: sinal de confirmação (enter), utilizado para
                           disparo da instrução
									
    SW         : Chaves para entrada de comandos, endereços e dados.

Saídas:
    HEX0-HEX5  : Displays de 7 segmentos utilizados para visualização de
                 estados internos, opcode atual e resultado da inferência.
					  
*/
module co_processador(
    input  wire        clk,
	 input  wire ativacao,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [6:0]  HEX4,
    output wire [6:0]  HEX5
);


    wire rst_n    = KEY[0];
    wire key1_raw = ~KEY[1];
	 
	 reg show_status;
    
	 reg key1_d;
    wire key1_fall = ~key1_raw & key1_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key1_d <= 0;
        else        key1_d <= key1_raw;
    end

    wire        sw_start = SW[9];
    wire [2:0]  opcode   = SW[8:6];
    wire [2:0]  addr_sw  = SW[5:3];
    wire [2:0]  data_sw  = SW[2:0];

    localparam [2:0]
        OP_IMG    = 3'b000,
        OP_PES    = 3'b001,
        OP_BIA    = 3'b010,
        OP_BET    = 3'b011,
        OP_INFER  = 3'b100,
		  OP_STATUS = 3'b101;

    // Pulso de envio: KEY[1] caindo, SW[9]=0, opcode != INFER
    wire do_send  = ~sw_start & (SW != 0) & key1_fall & (opcode != OP_INFER) & (opcode != OP_STATUS);
	 
	 // Pulso de status: SW[9], opcode=OP_STATUS, KEY[1] caindo
	 wire do_status = ~sw_start & (opcode == OP_STATUS)  & key1_fall & (addr_sw == 0) & (data_sw == 0);
	 
    // Pulso de inferência: SW[9]=1, opcode=OP_INFER, KEY[1] caindo
    wire do_start = sw_start & (opcode == OP_INFER)  & key1_fall & (addr_sw == 0) & (data_sw == 0);
	 

    // imagem   : addr [9:0],  data [15:0]
    // pesos    : addr [16:0], data [15:0]
    // bias     : addr [6:0],  data [15:0]
    // beta     : addr [10:0], data [15:0]

    wire        img_we    = do_send & (opcode == OP_IMG);
    wire [9:0]  img_waddr = {7'b0, addr_sw};
    wire [15:0] img_wdata = {8'b0, data_sw, 5'b0};  

    wire        pesos_we    = do_send & (opcode == OP_PES);
    wire [16:0] pesos_waddr = {14'b0, addr_sw};
    wire [15:0] pesos_wdata = {13'b0, data_sw};

    wire        bias_we    = do_send & (opcode == OP_BIA);
    wire [6:0]  bias_waddr = {4'b0, addr_sw};
    wire [15:0] bias_wdata = {13'b0, data_sw};

    wire        beta_we    = do_send & (opcode == OP_BET);
    wire [10:0] beta_waddr = {8'b0, addr_sw};
    wire [15:0] beta_wdata = {13'b0, data_sw};
	 
	 wire        status_we    = do_send & (opcode == OP_STATUS);
	 wire [10:0] status_waddr = {10'b0};
	 wire [15:0] status_wdata = {15'b0};

    wire start_fsm = do_start;

    wire        done_w;
    wire        busy_w;
    wire [3:0]  pred_w;

    fsm u_fsm (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start_fsm),
		  .ativacao   (ativacao),
		  
        .img_we     (img_we),
        .img_waddr  (img_waddr),
        .img_wdata  (img_wdata),

        .pesos_we   (pesos_we),
        .pesos_waddr(pesos_waddr),
        .pesos_wdata(pesos_wdata),

        .beta_we    (beta_we),
        .beta_waddr (beta_waddr),
        .beta_wdata (beta_wdata),

        .bias_we    (bias_we),
        .bias_waddr (bias_waddr),
        .bias_wdata (bias_wdata),

		  .status_we   (status_we),
		  .status_waddr(status_waddr),
		  .status_wdata(status_wdata),
		  
        .done       (done_w),
        .pred       (pred_w),
        .busy       (busy_w)
    );


    display u_disp (
        .clk    (clk),
        .rst_n  (rst_n),
        .busy   (~busy_w),
        .done   (done_w),
        .pred   (pred_w),
		  .show_status (show_status),
        .opcode (opcode),
        .HEX0   (HEX0),
        .HEX1   (HEX1),
        .HEX2   (HEX2),
        .HEX3   (HEX3),
        .HEX4   (HEX4),
        .HEX5   (HEX5)
    );

endmodule