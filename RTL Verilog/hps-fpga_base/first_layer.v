/*************************************************************
	MODULO DA PRIMEIRA CAMADA DA REDE NEURAL
	DESENVOLVIDO POR MAIKE DE OLIVEIRA NASCIMENTO MONITOR DA MATERIA DE SISTEMAS DIGITAIS
	
**************************************************************/

module first_layer(
    enable,
    clk,
    rst,
    is_avaliable_pixel,
    req_pixel,
    addr_pixel,
    data_in_pixel,
    is_avaliable_win,
    req_win,
    addr_win,
    data_in_win,
    is_avaliable_bias,
    req_bias,
    addr_bias,
    data_in_bias,
    iteration_counter,
    done,
    data_to_raw_in_register,
    addr_to_raw_in_register,
    enable_register_write
);

	/*******************************************
	Entradas e saidas do modulo
	*******************************************/
    input is_avaliable_bias, is_avaliable_pixel, is_avaliable_win;
    input signed [15:0] data_in_bias, data_in_win;
    input [7:0] data_in_pixel;
    input clk, rst, enable;

    output reg [4:0] iteration_counter;
    output reg done;
    output reg enable_register_write;
    output reg signed [15:0] data_to_raw_in_register;
    output reg [6:0] addr_to_raw_in_register;
    
    output reg req_bias, req_pixel, req_win;
    output reg [9:0] addr_pixel;
    output reg [6:0] addr_bias;
    output reg [16:0] addr_win;
	 
	 
    /****************************************************
	 Estados da primeira FMS da camada 1 (Fr FMS)
	 *****************************************************/
    localparam RQ_PIXEL= 4'h0, ST_PIXEL= 4'h1, RQ_WIN0= 4'h2,
    ST_WIN0= 4'h3, RQ_WIN1= 4'h4, ST_WIN1= 4'h5,
    RQ_WIN2= 4'h6, ST_WIN2= 4'h7, RQ_WIN3= 4'h8,
    ST_WIN3= 4'h9, CALC= 4'ha, WAIT_SD_FMS= 4'hb;
    
	 
	 /****************************************************
	 Estados da segunda FMS da camada 1 (Sd FMS)
	 *****************************************************/
    localparam VF_LAST_PIXEL = 5'h0, RQ_BIAS0=5'h1, ST_BIAS0 = 5'h2, 
    RQ_BIAS1 = 5'h3, ST_BIAS1 = 5'h4, RQ_BIAS2 = 5'h5, 
    ST_BIAS2 = 5'h6, RQ_BIAS3 = 5'h7, ST_BIAS3 = 5'h8, 
    SUM_BIAS = 5'h9, ST_RES0 = 5'ha, WAIT_RES0 = 5'hb,
    ST_RES1 = 5'hc, WAIT_RES1 = 5'hd, ST_RES2 = 5'he,
    WAIT_RES2 = 5'hf, ST_RES3 = 5'h10, WAIT_RES3 = 5'h11,
    INCREMENT = 5'h12, DONE_FMS = 5'h13;
    
	 /*******************************************************
	 Fios e registradores de dados
	 ********************************************************/
	 reg [9:0] pixel_counter;
    reg [7:0] data_a_pixel;
    reg signed [15:0] data_b_win[3:0];
	 reg [8:0] data_to_a_sd_fms;
    reg signed [15:0] data_to_b_sd_fms[3:0];
	 wire signed [15:0] data_out_nodes[3:0];
	 wire signed [15:0] data_to_b[3:0];
    wire [8:0] data_to_a;
	 wire signed [15:0] data_out_after_activation[3:0];
	 
	 
	 /********************************
	 Fios e registradores de controle
	 *********************************/
	 reg iteration_done;
	 reg enable_sd_fms;
	 reg enable_nodes_by_fr_fms;
    reg clear_acc;
    reg enable_nodes_by_sd_fms;
    wire enable_nodes;
    
    
    /*********************************
	 Registradores de estado
	 *********************************/
    reg [3:0] fr_fms_state;
    reg [4:0] sd_fms_state;
  
    
    
    
    /******************************************
	 Logica sequencial da primeira FMS (FR FMS)
	 ******************************************/
	 always @(posedge clk or posedge rst) begin
		  if (rst) begin
				fr_fms_state <= RQ_PIXEL;
				data_a_pixel <= 8'd0;
				data_b_win[0] <= 16'd0;
				data_b_win[1] <= 16'd0;
				data_b_win[2] <= 16'd0;
				data_b_win[3] <= 16'd0;
		  end else if (enable) begin
				case (fr_fms_state)
					 RQ_PIXEL: begin
						 if (is_avaliable_pixel) begin
							fr_fms_state <= ST_PIXEL;
						 end
					 end
					 ST_PIXEL: begin 
						  data_a_pixel <= data_in_pixel;
						  if (is_avaliable_pixel) begin /*handshake*/
								fr_fms_state <= ST_PIXEL;
						  end else begin
								fr_fms_state <= RQ_WIN0;
						  end
					 end
					 RQ_WIN0: begin
						if (is_avaliable_win) begin
							fr_fms_state <= ST_WIN0;
						 end
					 end
					 ST_WIN0: begin
						  data_b_win[0] <= data_in_win;
						  if (is_avaliable_win) begin
								fr_fms_state <= ST_WIN0;
						  end else begin
								fr_fms_state <= RQ_WIN1;
						  end
					 end
					 RQ_WIN1: begin 
						if (is_avaliable_win) begin
							fr_fms_state <= ST_WIN1;
						end
					 end
					 ST_WIN1: begin
						  data_b_win[1] <= data_in_win;
						  if (is_avaliable_win) begin 
								fr_fms_state <= ST_WIN1;
						  end else  begin
								fr_fms_state <= RQ_WIN2;
							end
					 end
					 RQ_WIN2: begin
						if (is_avaliable_win) begin
							fr_fms_state <= ST_WIN2;
						end
					end
					 ST_WIN2: begin
						  data_b_win[2] <= data_in_win;
						  if (is_avaliable_win) begin
								fr_fms_state <= ST_WIN2;
						  end else begin
								fr_fms_state <= RQ_WIN3;
						  end
					 end
					 RQ_WIN3: begin
						if (is_avaliable_win) begin
							fr_fms_state <= ST_WIN3;
						end
					 end
					 ST_WIN3: begin
						  data_b_win[3] <= data_in_win;
						  if (is_avaliable_win) begin 
								fr_fms_state <= ST_WIN3;
						  end else begin
								fr_fms_state <= CALC;
						  end
					 end
					 CALC: begin
						fr_fms_state <= WAIT_SD_FMS;
					 end
					 WAIT_SD_FMS: begin
						  if (iteration_done) begin
								fr_fms_state <= RQ_PIXEL;
							end
					 end
					 default: begin 
						fr_fms_state <= RQ_PIXEL;
					 end
				endcase
		  end
	 end
    
    /**************************************************
		Circuito combinacional da primeira FMS (FR FMS)
	 
	 **************************************************/
    always @(*) begin
        /* valores default para evitar a criçao de latches indesejados*/
        enable_sd_fms = 1'b0;
        req_win = 1'b0;
        req_pixel = 1'b0;
        enable_nodes_by_fr_fms = 1'b0;
        addr_pixel = 10'd0;
        addr_win = 17'd0;
        
        if (enable) begin
            case (fr_fms_state)
                RQ_PIXEL: begin
                    req_pixel = 1'b1;
                    addr_pixel = pixel_counter;
                end
                RQ_WIN0: begin
                    req_win = 1'b1;
                    addr_win = pixel_counter + (iteration_counter * 17'd3136);
                end
                RQ_WIN1: begin
                    req_win = 1'b1;
                    addr_win = pixel_counter + (iteration_counter * 17'd3136) + 17'd784;
                end
                RQ_WIN2: begin
                    req_win = 1'b1;
                    addr_win = pixel_counter + (iteration_counter * 17'd3136) + 17'd1568;
                end
                RQ_WIN3: begin
                    req_win = 1'b1;
                    addr_win = pixel_counter + (iteration_counter * 17'd3136) + 17'd2352;
                end
                CALC: enable_nodes_by_fr_fms = 1'b1;
                WAIT_SD_FMS: enable_sd_fms = 1'b1;
            endcase
        end
    end
    
    /********************************************
	 Circuito sequencial da segunda FMS (SD FMS)
	 *********************************************/
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            iteration_counter <= 5'd0;
            sd_fms_state <= VF_LAST_PIXEL;
            pixel_counter <= 10'd0;
            clear_acc <= 1'b0;
            done <= 1'b0;
            data_to_b_sd_fms[0] <= 16'd0;
            data_to_b_sd_fms[1] <= 16'd0;
            data_to_b_sd_fms[2] <= 16'd0;
            data_to_b_sd_fms[3] <= 16'd0;
        end else if (enable_sd_fms) begin
            case (sd_fms_state)
                VF_LAST_PIXEL: begin
                    if (pixel_counter == 10'd783) sd_fms_state <= RQ_BIAS0;
                    else sd_fms_state <= INCREMENT;
                end
                RQ_BIAS0: if (is_avaliable_bias) sd_fms_state <= ST_BIAS0;
                ST_BIAS0: begin
                    data_to_b_sd_fms[0] <= data_in_bias;
                    if (is_avaliable_bias) sd_fms_state <= ST_BIAS0;
                    else sd_fms_state <= RQ_BIAS1;
                end
                RQ_BIAS1: if (is_avaliable_bias) sd_fms_state <= ST_BIAS1;
                ST_BIAS1: begin
                    data_to_b_sd_fms[1] <= data_in_bias;
                    if (is_avaliable_bias) sd_fms_state <= ST_BIAS1;
                    else sd_fms_state <= RQ_BIAS2;
                end
                RQ_BIAS2: if (is_avaliable_bias) sd_fms_state <= ST_BIAS2;
                ST_BIAS2: begin
                    data_to_b_sd_fms[2] <= data_in_bias;
                    if (is_avaliable_bias) sd_fms_state <= ST_BIAS2;
                    else sd_fms_state <= RQ_BIAS3;
                end
                RQ_BIAS3: if (is_avaliable_bias) sd_fms_state <= ST_BIAS3;
                ST_BIAS3: begin
                    data_to_b_sd_fms[3] <= data_in_bias;
                    if (is_avaliable_bias) sd_fms_state <= ST_BIAS3;
                    else sd_fms_state <= SUM_BIAS;
                end
                SUM_BIAS: sd_fms_state <= ST_RES0;
                ST_RES0: sd_fms_state <= WAIT_RES0;
                WAIT_RES0: sd_fms_state <= ST_RES1;
                ST_RES1: sd_fms_state <= WAIT_RES1;
                WAIT_RES1: sd_fms_state <= ST_RES2;
                ST_RES2: sd_fms_state <= WAIT_RES2;
                WAIT_RES2: sd_fms_state <= ST_RES3;
                ST_RES3: sd_fms_state <= WAIT_RES3;
                WAIT_RES3: sd_fms_state <= INCREMENT;
                INCREMENT: begin
                    if (iteration_counter == 5'd31 && pixel_counter == 10'd783) done <= 1'b1;
                    else done <= 1'b0;
                    
                    if (pixel_counter == 10'd783) begin
                        iteration_counter <= iteration_counter + 1;
                        pixel_counter <= 10'd0;
                        clear_acc <= 1'b1;
                    end else begin
                        pixel_counter <= pixel_counter + 1;
                    end
                    sd_fms_state <= DONE_FMS;
                end
                DONE_FMS: begin
                    clear_acc <= 1'b0;
                    sd_fms_state <= VF_LAST_PIXEL;
                end
                default: sd_fms_state <= VF_LAST_PIXEL;
            endcase
        end
    end
    
    /******************************************************
		Circuito combinacional da segunda FMS (SD FMS)
	 *******************************************************/
    always @(*) begin
			/*Valores padrao para evitar a criacao de latches indesejados*/
        iteration_done = 1'b0;
        req_bias = 1'b0;
        enable_register_write = 1'b0;
        enable_nodes_by_sd_fms = 1'b0; 
        data_to_a_sd_fms = 9'd0;
        addr_bias = 7'd0;
        addr_to_raw_in_register = 7'd0;
        data_to_raw_in_register = 16'd0;
        
        case (sd_fms_state)
            RQ_BIAS0: begin
                req_bias = 1'b1;
                addr_bias = (iteration_counter<<2);
            end
            RQ_BIAS1: begin
                req_bias = 1'b1;
                addr_bias = (iteration_counter<<2) + 1;
            end
            RQ_BIAS2: begin
                req_bias = 1'b1;
                addr_bias = (iteration_counter<<2) + 2;
            end
            RQ_BIAS3: begin
                req_bias = 1'b1;
                addr_bias = (iteration_counter<<2) + 3;
            end
            SUM_BIAS: begin
                data_to_a_sd_fms = 9'd256;
                enable_nodes_by_sd_fms = 1'b1;
            end
            ST_RES0: begin
                addr_to_raw_in_register = (iteration_counter << 2);
                data_to_raw_in_register = data_out_after_activation[0];
                enable_register_write = 1'b1;
            end
            WAIT_RES0: begin
                addr_to_raw_in_register = (iteration_counter << 2);
                data_to_raw_in_register = data_out_after_activation[0];
            end
            ST_RES1: begin
                addr_to_raw_in_register = (iteration_counter << 2) + 1;
                data_to_raw_in_register = data_out_after_activation[1];
                enable_register_write = 1'b1;
            end
            WAIT_RES1: begin
                addr_to_raw_in_register = (iteration_counter << 2) + 1;
                data_to_raw_in_register = data_out_after_activation[1];
            end
            ST_RES2: begin
                addr_to_raw_in_register = (iteration_counter << 2) + 2;
                data_to_raw_in_register = data_out_after_activation[2];
                enable_register_write = 1'b1;
            end
            WAIT_RES2: begin
                addr_to_raw_in_register = (iteration_counter << 2) + 2;
                data_to_raw_in_register = data_out_after_activation[2];
            end
            ST_RES3: begin
                addr_to_raw_in_register = (iteration_counter << 2) + 3;
                data_to_raw_in_register = data_out_after_activation[3];
                enable_register_write = 1'b1;
            end
            WAIT_RES3: begin
                addr_to_raw_in_register = (iteration_counter << 2) + 3;
                data_to_raw_in_register = data_out_after_activation[3];
            end
            DONE_FMS: iteration_done = 1'b1;
        endcase
    end
    
    
    /*Multiplexadores para determinar de ondem vem as entradas dos acumuladores*/
    assign data_to_a = (enable_sd_fms) ? data_to_a_sd_fms:{1'b0,data_a_pixel};
    assign data_to_b[0] = (enable_sd_fms) ? data_to_b_sd_fms[0]:data_b_win[0];
    assign data_to_b[1] = (enable_sd_fms) ? data_to_b_sd_fms[1]:data_b_win[1];
    assign data_to_b[2] = (enable_sd_fms) ? data_to_b_sd_fms[2]:data_b_win[2];
    assign data_to_b[3] = (enable_sd_fms) ? data_to_b_sd_fms[3]:data_b_win[3];
    assign enable_nodes = (enable_sd_fms) ? enable_nodes_by_sd_fms:enable_nodes_by_fr_fms;
    
	 /***************************************************
	 Instanciamento dos acumuladores 
	 ***************************************************/
	 
	 
    mac_first_layer node0(
        .weigth_or_bias(data_to_b[0]),
        .one_or_pixel(data_to_a),
        .clk(clk),
        .enable(enable_nodes),
        .rst(rst),
        .clear_acc(clear_acc),
        .out_q4_12(data_out_nodes[0])
    );
    mac_first_layer node1(
        .weigth_or_bias(data_to_b[1]),
        .one_or_pixel(data_to_a),
        .clk(clk),
        .enable(enable_nodes),
        .rst(rst),
        .clear_acc(clear_acc),
        .out_q4_12(data_out_nodes[1])
    );
    mac_first_layer node2(
        .weigth_or_bias(data_to_b[2]),
        .one_or_pixel(data_to_a),
        .clk(clk),
        .enable(enable_nodes),
        .rst(rst),
        .clear_acc(clear_acc),
        .out_q4_12(data_out_nodes[2])
    );
    mac_first_layer node3(
        .weigth_or_bias(data_to_b[3]),
        .one_or_pixel(data_to_a),
        .clk(clk),
        .enable(enable_nodes),
        .rst(rst),
        .clear_acc(clear_acc),
        .out_q4_12(data_out_nodes[3])
    );
    
    
	/**************************************************
	Instanciamento das funçoes de ativacao de cada neuronio
	**************************************************/
	tanh_pwl_q4_12 tanh_activation0(
		 .x(data_out_nodes[0]),
		 .y(data_out_after_activation[0])
	);
	tanh_pwl_q4_12 tanh_activation1(
		 .x(data_out_nodes[1]),
		 .y(data_out_after_activation[1])
	);
	tanh_pwl_q4_12 tanh_activation2(
		 .x(data_out_nodes[2]),
		 .y(data_out_after_activation[2])
	);
	tanh_pwl_q4_12 tanh_activation3(
		 .x(data_out_nodes[3]),
		 .y(data_out_after_activation[3])
	);
    
endmodule
