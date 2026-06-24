`include "constants.vh"

module fsm (
	input  wire clk,
	input  wire rst,
	input  wire start,
	input  wire [1:0]  ativacao,
	input  wire        img_we,
	input  wire [9:0]  img_waddr,
	input  wire [15:0] img_wdata,
	input  wire        pesos_we,
	input  wire [16:0] pesos_waddr,
	input  wire [15:0] pesos_wdata,
	input  wire        beta_we,
	input  wire [10:0] beta_waddr,
	input  wire [15:0] beta_wdata,
	input  wire        bias_we,
	input  wire [6:0]  bias_waddr,
	input  wire [15:0] bias_wdata,
	input  wire		   status_we,

    output reg  [31:0] cycles_out,
	output reg  [3:0] pred,
	output reg  done,
	output reg  busy
);

	parameter IMG_SIZE  = 784;
	parameter N_HIDDEN  = 128;
	parameter N_CLASSES = 10;


	(* ramstyle = "MLAB" *)
	reg signed [15:0] hid [0 : N_HIDDEN - 1];
	
	reg  [7:0]         neuron_idx;
	reg  signed [15:0] neuron_out;
	reg                class_valid;
	reg  [3:0]         class_idx;
	reg  signed [15:0] class_out;

	reg signed [15:0] pixel_reg;
	reg signed [15:0] peso_reg;
	reg signed [15:0] bias_reg;
	reg  signed [15:0] mac_saida_reg;

	reg [16:0] pesos_raddr;
	reg [10:0] beta_raddr;
	reg [16:0] pesos_base;
	reg [10:0] beta_base;
	reg [31:0] cycles;
	
	reg [7:0] n_cnt;
	reg [3:0] c_cnt;
	reg [9:0] mac_n_ops;
	reg [4:0] mac_shift;
	reg [4:0] state;

	reg [31:0] cycles_final;
	
	reg argmax_start;
	reg argmax_reset;
	reg mac_reset;
	reg mac_start;
	reg layer2;

	wire signed [15:0] sig_in  = mac_saida_reg;
	wire signed [15:0] sig_out_sigmoid;
	wire signed [15:0] sig_out_tanh;
	wire signed [15:0] sig_out_relu;
	wire signed [15:0] sig_out;
	wire signed [15:0] bias_dout;
	wire signed [15:0] mac_saida;
	wire signed [15:0] beta_dout;
	wire signed [15:0] pesos_dout;
	wire signed [15:0] img_dout;

	wire [9:0]  mac_addr;
	wire [3:0] pred_wire;
	wire [3:0] leds;
	
	
	reg        cycles_we;  
	reg [3:0]  cycles_waddr;
	reg [31:0] cycles_idx;
	reg [3:0]  cycles_wdata;
	wire signed [31:0] cycles_dout;

	  
   wire mac_done;
   wire argmax_done;

	integer i;

	// { 4 zeros | 8 bits do pixel | 4 zeros } = pixel * 16
	wire signed [15:0] img_normalizado = { 4'b0000, img_dout[7:0], 4'b0000 };
	
	wire signed [15:0] mac_pixel_raw = layer2 ? hid[mac_addr[6:0]] : img_normalizado;
	wire signed [15:0] mac_peso_raw  = layer2 ? beta_dout : pesos_dout;
	wire signed [15:0] mac_bias_raw  = (!layer2 && mac_addr == mac_n_ops - 1) ? bias_dout : 16'sd0;

	
    imagem u_ram_img (
        .clock   (clk),
        .wren    (img_we),
        .address (img_we ? img_waddr : mac_addr[9:0]),
        .data    (img_wdata),
        .rden    (1'b1),
        .q       (img_dout)
    );

    pesos u_ram_pesos (
        .clock   (clk),
        .wren    (pesos_we),
        .address (pesos_we ? pesos_waddr : pesos_raddr),
        .data    (pesos_wdata),
        .rden    (1'b1),
        .q       (pesos_dout)
    );

    beta u_ram_beta (
        .clock   (clk),
        .wren    (beta_we),
        .address (beta_we ? beta_waddr : beta_raddr[10:0]),
        .data    (beta_wdata),
        .rden    (1'b1),
        .q       (beta_dout)
    );

    
    bias u_ram_bias (
        .clock   (clk),
        .wren    (bias_we),
        .address (bias_we ? bias_waddr : n_cnt[6:0]),
        .data    (bias_wdata),
        .rden    (1'b1),
        .q       (bias_dout)
    );
	 
    mac mac_inst (
        .clk   (clk),
        .reset (mac_reset),
        .start (mac_start),
        .pixel (pixel_reg),
        .peso  (peso_reg),
        .bias  (bias_reg),
        .shift (mac_shift),
        .n_ops (mac_n_ops),
        .addr  (mac_addr),
        .done  (mac_done),
        .saida (mac_saida)
    );


    ativacaoSigm sigmoid_inst (
		  .d_in(sig_in), 
		  .d_out(sig_out_sigmoid)
	);

	ativacaoTanh tanh_inst (
		 .d_in  (sig_in),
		 .d_out (sig_out_tanh)
	);

    assign sig_out_relu = (sig_in[15] == 1'b1) ? 16'sd0 : sig_in;
    assign sig_out = (ativacao == `SIGMOID) ? sig_out_sigmoid :
                     (ativacao == `RELU)    ? sig_out_relu    :
                                              sig_out_tanh;

    argmax argmax_inst (
        .clk   (clk),
        .reset (argmax_reset),
        .start (argmax_start),
        .y_in  (class_out),
        .idx   (class_idx),
        .pred  (pred_wire),
        .done  (argmax_done)
    );

	 	
	always @(posedge clk) begin
		 pixel_reg <= mac_pixel_raw;
		 peso_reg  <= mac_peso_raw;
		 bias_reg  <= mac_bias_raw;
	end
		

    localparam [4:0]
        IDLE          = 5'd0,
        H_RESET       = 5'd1,
        W_H_RST       = 5'd2,
        H_WAIT_ADDR   = 5'd3,
        H_PRIME       = 5'd4,
        W_H_PRIME     = 5'd5,
        H_WAIT_PIPE   = 5'd6,
        H_RUN         = 5'd7,
        H_WAIT_DONE   = 5'd8,
        H_LATCH       = 5'd9,
        W_H_LATCH     = 5'd10,
        H_SIG         = 5'd11,
        W_H_SIG       = 5'd12,
        H_WRITE       = 5'd13,
        W_H_WRITE     = 5'd14,
        O_RESET       = 5'd15,
        W_O_RST       = 5'd16,
        O_WAIT_BETA   = 5'd17,
        O_PRIME       = 5'd18,
        W_O_PRIME     = 5'd19,
        O_WAIT_PIPE   = 5'd20,
        O_RUN         = 5'd21,
        O_WAIT_DONE   = 5'd22,
        O_LATCH       = 5'd23,
        W_O_LATCH     = 5'd24,
        O_WRITE       = 5'd25,
        W_O_WRITE     = 5'd26,
        DONE_ST       = 5'd27,
		ERROR         = 5'd28;


    always @(posedge clk) begin
        if (rst) begin
		  
            for (i = 0; i < N_HIDDEN; i = i + 1) begin
                hid[i] <= 0;
				end
					 
            state         <= IDLE;
            done          <= 0;
			   cycles        <= 0;
			   cycles_out    <= 0;
            n_cnt         <= 0;
            c_cnt         <= 0;
            layer2        <= 0;
            pesos_base    <= 0;
            pesos_raddr   <= 0;
            beta_base     <= 0;
            beta_raddr    <= 0;
            mac_reset     <= 1;
            mac_start     <= 0;
            mac_n_ops     <= 0;
            mac_shift     <= 0;
            mac_saida_reg <= 0;
            class_valid   <= 0;
            class_idx     <= 0;
            class_out     <= 0;
            argmax_start  <= 0;
            argmax_reset  <= 1;
            pred          <= 0;
            neuron_idx    <= 0;
            neuron_out    <= 0;
			   busy 		     <= 0;
        end else begin
            mac_reset     <= 0;
            mac_start     <= 0;
            class_valid   <= 0;
            argmax_start  <= 0;
            argmax_reset  <= 0;

            if (busy) cycles <= cycles + 1;
				
            case (state)
                // IDLE
                IDLE: begin
                    done        <= 0;					
                    n_cnt       <= 0;
                    c_cnt       <= 0;
                    layer2      <= 0;
                    pesos_base  <= 0;
                    pesos_raddr <= 0;
                    beta_raddr  <= 0;

                    if (start) begin
                        state  <= H_RESET;
                        busy   <= 1;
                        cycles <= 0;
                    end
                end

                // CAMADA OCULTA
                // Configura MAC e pega endereço base do peso na RAM
                H_RESET: begin
                    mac_reset   <= 1;
                    mac_shift   <= 12;
                    mac_n_ops   <= IMG_SIZE;
                    pesos_raddr <= pesos_base;
                    state       <= W_H_RST;     
                end

                // Espera o reset do MAC por 1 ciclo
                W_H_RST: begin
                    pesos_raddr <= pesos_base;
                    state       <= H_WAIT_ADDR; 
                end

                // Espera o endereço registrado para a RAM começar a buscar os dados
                H_WAIT_ADDR: begin
                    pesos_raddr <= pesos_base;
                    state       <= H_PRIME;
                end

                // Força addr=0 para o primeiro peso/pixel
                H_PRIME: begin
                    pesos_raddr <= pesos_base;
                    state       <= W_H_PRIME;   
                end

                // Espera a saída da RAM (pesos_dout/img_dout)
                W_H_PRIME: begin
                    state <= H_WAIT_PIPE;       
                end

                // Espera o pixel_reg e peso_reg registrado
                H_WAIT_PIPE: begin
                    state <= H_RUN;
                end

                // MAC em execução: atualiza endereço a cada ciclo
                H_RUN: begin
                    mac_start   <= 1;
                    pesos_raddr <= pesos_base + mac_addr + 1;
                    if (mac_done)
                        state <= H_WAIT_DONE;   
                end

                // Espera o mac_done confirmar por 1 ciclo
                H_WAIT_DONE: begin
                    state <= H_LATCH;
                end

                // Pega o resultado do MAC
                H_LATCH: begin
                    mac_saida_reg <= mac_saida;
                    state         <= W_H_LATCH; 
                end

                // Espera a mac_saida_reg estabilizar antes de entrar na ativação
                W_H_LATCH: begin
                    state <= H_SIG;
                end

                //  Bloco de ativação
                H_SIG: begin
                    state <= W_H_SIG;
                end

                // Espera o sig_out
                W_H_SIG: begin
                    state <= H_WRITE;
                end

                // Grava o neurônio da camada oculto
                H_WRITE: begin
                    hid[n_cnt] <= sig_out;
                    neuron_idx <= n_cnt;
                    neuron_out <= sig_out;
                    state      <= W_H_WRITE;    
                end

                // Espera a escrita em hid[] edps decide o próximo neurônio
                W_H_WRITE: begin
                    if (n_cnt == N_HIDDEN - 1) begin
                        c_cnt  <= 0;
                        layer2 <= 1;
                        state  <= O_RESET;
                    end else begin
                        n_cnt      <= n_cnt + 1;
                        pesos_base <= pesos_base + IMG_SIZE;
                        state      <= H_RESET;
                    end
                end

                // Camada de saida
                O_RESET: begin
                    mac_reset    <= 1;
                    argmax_reset <= (c_cnt == 0);
                    mac_shift    <= 12;
                    mac_n_ops    <= N_HIDDEN;
                    beta_base    <= {{7{1'b0}}, c_cnt[3:0]};
                    beta_raddr   <= {{7{1'b0}}, c_cnt[3:0]};
                    state        <= W_O_RST;        // ESPERA 9
                end

                // Espera o reset MAC inicia o beta_raddr registrado na RAM
                W_O_RST: begin
                    state <= O_WAIT_BETA;          
                end

                // Espera a saída de beta_dout válida no próximo ciclo
                O_WAIT_BETA: begin
                    beta_base  <= beta_base + N_CLASSES;
                    beta_raddr <= beta_base + N_CLASSES;
                    state      <= O_PRIME;
                end

                O_PRIME: begin
                    beta_base  <= beta_base + N_CLASSES;
                    beta_raddr <= beta_base + N_CLASSES;
                    state      <= W_O_PRIME;        
                end

                // Espera o primeiro beta_dout válido na saída da RAM
                W_O_PRIME: begin
                    state <= O_WAIT_PIPE;           
                end

                // Espera o pixel_reg/peso_reg serem registrados
                O_WAIT_PIPE: begin
                    state <= O_RUN;
                end

                O_RUN: begin
                    mac_start  <= 1;
                    beta_raddr <= beta_base;
                    beta_base  <= beta_base + N_CLASSES;
                    if (mac_done)
                        state <= O_WAIT_DONE;       
                end

                // Espera a mac_done ser confirmada por 1 ciclo
                O_WAIT_DONE: begin
                    state <= O_LATCH;
                end

                O_LATCH: begin
                    mac_saida_reg <= mac_saida;
                    state         <= W_O_LATCH;    
                end

                // Espera a mac_saida_reg
                W_O_LATCH: begin
                    state <= O_WRITE;
                end

                O_WRITE: begin
                    class_valid  <= 1;
                    class_idx    <= c_cnt;
                    class_out    <= mac_saida_reg;
                    argmax_start <= 1;
                    state        <= W_O_WRITE;      
                end

                // Espera o pulso argmax_start completado para decidir o proximo estado
                W_O_WRITE: begin
                    if (c_cnt == N_CLASSES - 1) begin
                        state <= DONE_ST;
                    end else begin
                        c_cnt <= c_cnt + 1;
                        state <= O_RESET;
                    end
                end

                DONE_ST: begin
                    if (argmax_done) begin
                        done <= 1;
                        pred <= pred_wire;
                        busy <= 0;
								
                        cycles_out <= cycles;
                        
                        state <= IDLE;
                    end
						  
                end

                default: state <= ERROR;
            endcase
        end
    end

    reg [127:0] state_name;
    always @(*) begin
        case (state)
            IDLE        : state_name = "IDLE        ";
            H_RESET     : state_name = "H_RESET     ";
            W_H_RST     : state_name = "W_H_RST     ";
            H_WAIT_ADDR : state_name = "H_WAIT_ADDR ";
            H_PRIME     : state_name = "H_PRIME     ";
            W_H_PRIME   : state_name = "W_H_PRIME   ";
            H_WAIT_PIPE : state_name = "H_WAIT_PIPE ";
            H_RUN       : state_name = "H_RUN       ";
            H_WAIT_DONE : state_name = "H_WAIT_DONE ";
            H_LATCH     : state_name = "H_LATCH     ";
            W_H_LATCH   : state_name = "W_H_LATCH   ";
            H_SIG       : state_name = "H_SIG       ";
            W_H_SIG     : state_name = "W_H_SIG     ";
            H_WRITE     : state_name = "H_WRITE     ";
            W_H_WRITE   : state_name = "W_H_WRITE   ";
            O_RESET     : state_name = "O_RESET     ";
            W_O_RST     : state_name = "W_O_RST     ";
            O_WAIT_BETA : state_name = "O_WAIT_BETA ";
            O_PRIME     : state_name = "O_PRIME     ";
            W_O_PRIME   : state_name = "W_O_PRIME   ";
            O_WAIT_PIPE : state_name = "O_WAIT_PIPE ";
            O_RUN       : state_name = "O_RUN       ";
            O_WAIT_DONE : state_name = "O_WAIT_DONE ";
            O_LATCH     : state_name = "O_LATCH     ";
            W_O_LATCH   : state_name = "W_O_LATCH   ";
            O_WRITE     : state_name = "O_WRITE     ";
            W_O_WRITE   : state_name = "W_O_WRITE   ";
            DONE_ST     : state_name = "DONE        ";
            default     : state_name = "ERROR         ";
        endcase
    end
endmodule