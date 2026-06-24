module CoProcessor(
    clk,
    data_in,
    enable,
    clr_operation,
    rst,
    data_out
);
    input [31:0] data_in;
    input enable, rst, clr_operation;
    output [31:0] data_out;
    input clk;
	 
    // Instruções
    localparam STORE_IMG=3'b000, STORE_WEIGTHS_ADDR=3'b001, STORE_WEIGTHS_VALUE=3'b010, 
               STORE_BIAS=3'b011, STORE_BETA=3'b100, START=3'b101, STATUS=3'b110, NOP=3'b111;
    
    // Estados
    localparam ST_IDLE=3'b000, ST_DECODE=3'b001, ST_MEMORY=3'b010, ST_INFERENCE=3'b011;
    reg [2:0] state;
    
    // Registradores de Instrução e Endereço
    reg [31:0] data_in_register;
    reg [9:0]  addr_img_register;
    reg [6:0]  addr_bias_register;
    reg [16:0] addr_weigth_register;
    reg [10:0] addr_beta_register;
    
    // Dados para Gravação
    reg [7:0]  data_img_register;
    reg [15:0] data_weigth_register;
    reg [15:0] data_bias_register;
    reg [15:0] data_beta_register;

    // Flags de Status
    reg fl_error;
    reg fl_processor_busy;
    reg fl_processor_done;
    reg [3:0] predicted_digit_register;
    
    // Controles Manuais das Memórias (Escrita via Instrução)
    reg wr_img_en, wr_bias_en, wr_beta_en, wr_weigth_en;
    reg lsu_img_en_inst, lsu_bias_en_inst, lsu_beta_en_inst, lsu_weigth_en_inst;
    
    // Fios de Resposta dos LSUs
    wire lsu_img_done, lsu_bias_done, lsu_beta_done, lsu_weigth_done;
    wire [7:0] data_img_output;
    wire [15:0] data_bias_output, data_beta_output, data_weigth_output;
    
    // Sinais da Unidade Neural
    wire inference_done;
    wire [3:0] inference_output;
    wire req_bias, req_beta, req_win, req_pixel;
    wire [9:0] addr_img_read;
    wire [6:0] addr_bias_read;
    wire [16:0] addr_weigth_read;
    wire [10:0] addr_beta_read;
    
    reg inference_controller;

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            fl_error <= 1'b0;
            fl_processor_busy <= 1'b0;
            fl_processor_done <= 1'b0;
            inference_controller <= 1'b0;
            predicted_digit_register <= 4'd0;
            
            wr_img_en <= 1'b0; 
				wr_bias_en <= 1'b0; 
				wr_beta_en <= 1'b0; 
				wr_weigth_en <= 1'b0;
            lsu_img_en_inst <= 1'b0; 
				lsu_bias_en_inst <= 1'b0; 
				lsu_beta_en_inst <= 1'b0; 
				lsu_weigth_en_inst <= 1'b0;
        end else begin
            
            if (clr_operation) begin
                fl_error <= 1'b0;
                fl_processor_done <= 1'b0;
            end
            
            case(state)
                ST_IDLE: begin
                    wr_img_en <= 1'b0; 
						  wr_bias_en <= 1'b0; 
						  wr_beta_en <= 1'b0; 
						  wr_weigth_en <= 1'b0;
                    lsu_img_en_inst <= 1'b0; 
						  lsu_bias_en_inst <= 1'b0; 
						  lsu_beta_en_inst <= 1'b0; 
						  lsu_weigth_en_inst <= 1'b0;
                    inference_controller <= 1'b0;
                    
                    // Handshake Seguro: Só aceita instrução se não estiver ocupado.
                    // E só libera o 'busy' quando o sinal 'enable' principal baixar.
                    if (enable && !fl_processor_busy) begin
                        data_in_register <= data_in;
                        fl_processor_busy <= 1'b1;
                        state <= ST_DECODE;
                    end else if (!enable) begin
                        fl_processor_busy <= 1'b0;
                    end
                end
                
                ST_DECODE: begin
                    if (fl_error) begin
                        state <= ST_IDLE;
                    end else begin
                        case (data_in_register[2:0])
                            STORE_BETA: begin
											if(data_in_register[13:3] >= 1280) begin
												fl_error <= 1'b1;
											end else begin
												fl_error <= 1'b0;
											end
                                addr_beta_register <= data_in_register[13:3];
                                data_beta_register <= data_in_register[29:14];
                                wr_beta_en <= 1'b1;
                                lsu_beta_en_inst <= 1'b1;
                                state <= ST_MEMORY;
                            end
                            STORE_BIAS: begin
											if(data_in_register[9:3] >= 128) begin
												fl_error <= 1'b1;
											end else begin
												fl_error <= 1'b0;
											end
                                addr_bias_register <= data_in_register[9:3];
                                data_bias_register <= data_in_register[25:10];
                                wr_bias_en <= 1'b1;
                                lsu_bias_en_inst <= 1'b1;
                                state <= ST_MEMORY;
                            end
                            STORE_IMG: begin
										  if(data_in_register[12:3] >= 784) begin
												fl_error <= 1'b1;
											end else begin
												fl_error <= 1'b0;
											end
                                addr_img_register <= data_in_register[12:3];
                                data_img_register <= data_in_register[20:13];   
                                wr_img_en <= 1'b1;
                                lsu_img_en_inst <= 1'b1;
                                state <= ST_MEMORY;
                            end
                            STORE_WEIGTHS_ADDR: begin
										  if(data_in_register[19:3] >= 100352) begin
												fl_error <= 1'b1;
											end else begin
												fl_error <= 1'b0;
											end
                                addr_weigth_register <= data_in_register[19:3];
                                state <= ST_IDLE; 
                            end
                            STORE_WEIGTHS_VALUE: begin
                                data_weigth_register <= data_in_register[18:3];
                                wr_weigth_en <= 1'b1;
                                lsu_weigth_en_inst <= 1'b1;
                                state <= ST_MEMORY;
                            end
                            START: begin
                                inference_controller <= 1'b1;
                                fl_processor_done <= 1'b0;
                                state <= ST_INFERENCE;
                            end
                            STATUS: begin
                                state <= ST_IDLE;
                            end
                            NOP: begin
                                state <= ST_IDLE;
                            end
                            default: begin
                                fl_error <= 1'b1;
                                state <= ST_IDLE;
                            end
                        endcase
                    end
                end
                
                ST_MEMORY: begin //aguarda as operaçoes de escrita acontecerem
                    if (lsu_img_done || lsu_bias_done || lsu_beta_done || lsu_weigth_done) begin
                        wr_img_en <= 1'b0; 
								wr_bias_en <= 1'b0; 
								wr_beta_en <= 1'b0; 
								wr_weigth_en <= 1'b0;
                        lsu_img_en_inst <= 1'b0; 
								lsu_bias_en_inst <= 1'b0; 
								lsu_beta_en_inst <= 1'b0; 
								lsu_weigth_en_inst <= 1'b0;
                        state <= ST_IDLE;
								fl_processor_done <= 1'b1;
                    end
                end
                
                ST_INFERENCE: begin //aguarda a inferencia acontecer
                    if (inference_done) begin
                        predicted_digit_register <= inference_output;
                        fl_processor_done <= 1'b1;
                        inference_controller <= 1'b0;
                        state <= ST_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // MULTIPLEXADOR DE BARRAMENTO DAS MEMÓRIAS
    // =========================================================================
    // Se a inferência roda, a rede toma o controle. Se não, o controle é do restante do coprocessador.
    wire lsu_img_en_final    = inference_controller ? req_pixel : lsu_img_en_inst;
    wire lsu_bias_en_final   = inference_controller ? req_bias  : lsu_bias_en_inst;
    wire lsu_beta_en_final   = inference_controller ? req_beta  : lsu_beta_en_inst;
    wire lsu_weigth_en_final = inference_controller ? req_win   : lsu_weigth_en_inst;

    wire is_available_img    = inference_controller ? lsu_img_done    : 1'b0;
    wire is_available_bias   = inference_controller ? lsu_bias_done   : 1'b0;
    wire is_available_beta   = inference_controller ? lsu_beta_done   : 1'b0;
    wire is_available_weigth = inference_controller ? lsu_weigth_done : 1'b0;

    // Instanciação
    lsu_controller #(.DATA_WIDTH(8), 
	 .MEM_SIZE(784), 
	 .CYCLES_PER_OP(3), 
	 .DEVICE_FAMILY("Cyclone V"), 
	 .RAM_TYPE("AUTO")) mem_img(
        .addr_write(addr_img_register), 
		  .addr_read(addr_img_read), 
		  .clk(clk),
        .write_en(wr_img_en), 
		  .data_in(data_img_register), 
		  .data_out(data_img_output),
        .done(lsu_img_done), 
		  .enable(lsu_img_en_final), 
		  .rst(rst)
    );
    
    lsu_controller #(.DATA_WIDTH(16), 
	 .MEM_SIZE(128), 
	 .CYCLES_PER_OP(3), 
	 .DEVICE_FAMILY("Cyclone V"), 
	 .RAM_TYPE("AUTO")) mem_bias(
        .addr_write(addr_bias_register), 
		  .addr_read(addr_bias_read), 
		  .clk(clk),
        .write_en(wr_bias_en), 
		  .data_in(data_bias_register), 
		  .data_out(data_bias_output),
        .done(lsu_bias_done), 
		  .enable(lsu_bias_en_final), 
		  .rst(rst)
    );
    
    lsu_controller #(.DATA_WIDTH(16), 
	 .MEM_SIZE(1280), 
	 .CYCLES_PER_OP(3), 
	 .DEVICE_FAMILY("Cyclone V"), 
	 .RAM_TYPE("AUTO")) mem_beta(
        .addr_write(addr_beta_register), 
		  .addr_read(addr_beta_read), 
		  .clk(clk),
        .write_en(wr_beta_en), 
		  .data_in(data_beta_register), 
		  .data_out(data_beta_output),
        .done(lsu_beta_done), 
		  .enable(lsu_beta_en_final), 
		  .rst(rst)
    );
    
    lsu_controller #(.DATA_WIDTH(16), 
	 .MEM_SIZE(100352), 
	 .CYCLES_PER_OP(3), 
	 .DEVICE_FAMILY("Cyclone V"), 
	 .RAM_TYPE("AUTO")) mem_weigth(
        .addr_write(addr_weigth_register), 
		  .addr_read(addr_weigth_read), 
		  .clk(clk),
        .write_en(wr_weigth_en), 
		  .data_in(data_weigth_register), 
		  .data_out(data_weigth_output),
        .done(lsu_weigth_done), 
		  .enable(lsu_weigth_en_final), 
		  .rst(rst)
    );

    neural_unit inf_machine(
        .addr_mem_bias(addr_bias_read), 
		  .addr_mem_pixel(addr_img_read),
        .addr_mem_win(addr_weigth_read), 
		  .addr_mem_beta(addr_beta_read),
        .req_bias(req_bias), 
		  .req_win(req_win), 
		  .req_beta(req_beta), 
		  .req_pixel(req_pixel),
        .is_available_bias(is_available_bias), 
		  .is_available_beta(is_available_beta),
        .is_available_win(is_available_weigth), 
		  .is_available_pixel(is_available_img),
        .data_in_bias(data_bias_output), 
		  .data_in_beta(data_beta_output),
        .data_in_win(data_weigth_output), 
		  .data_in_pixel(data_img_output),
        .clk(clk), 
		  .enable(inference_controller), 
		  .rst(rst),
        .output_digit(inference_output), 
		  .done(inference_done)
    );

    assign data_out = { 25'b0, fl_error, fl_processor_busy, fl_processor_done, predicted_digit_register };

endmodule