/*************************************************************
	MODULO DA SEGUNDA CAMADA DA REDE NEURAL
	DESENVOLVIDO POR MAIKE DE OLIVEIRA NASCIMENTO MONITOR DA MATERIA DE SISTEMAS DIGITAIS
	
**************************************************************/

module second_layer(
	addr_beta,
	addr_register,
	data_in_beta,
	data_in_register,
	addr_register_raw,
	data_register_raw,
	enable_register_write,
	done,
	iteration_counter,
	clk,
	enable,
	rst,
	req_beta,
	is_avaliable_beta

);

	/*******************************************
	Entradas e saidas do modulo
	
	********************************************/
	input signed [15:0] data_in_beta, data_in_register;
	input enable, clk, rst, is_avaliable_beta;
	
	output reg enable_register_write;
	output reg signed [15:0] data_register_raw;
	output reg [3:0] addr_register_raw;
	output reg [10:0] addr_beta;
	output reg [6:0] addr_register;
	output reg req_beta;
	output reg iteration_counter, done;

	
	
	/***************************************************
	Estados da Primeira FMS da segunda camada (FR FMS)
	****************************************************/
	
	localparam RQ_REG = 4'h0, ST_REG = 4'h1, RQ_BETA1 = 4'h2,
	ST_BETA1 = 4'h3, RQ_BETA2 = 4'h4, ST_BETA2 = 4'h5, 
	RQ_BETA3 = 4'h6, ST_BETA3 = 4'h7, RQ_BETA4 = 4'h8,
	ST_BETA4 = 4'h9, RQ_BETA5 = 4'ha, ST_BETA5 = 4'hb,
	CALC = 4'hc, WAIT_SD_FMS = 4'hd;
	
	
	/***************************************************
	Estados da segunda FMS da segunda camada (SD FMS)
	****************************************************/
	
	localparam VF_LAST_DATA= 4'h0, ST_RES1 = 4'h1, WAIT_RES1 = 4'h2,
	ST_RES2 = 4'h3, WAIT_RES2 = 4'h4, ST_RES3 = 4'h5,
	WAIT_RES3 = 4'h6, ST_RES4 = 4'h7, WAIT_RES4 = 4'h8,
	ST_RES5 = 4'h9, WAIT_RES5 = 4'ha, INCREMENT = 4'hb,
	DONE_IT = 4'hc;
	
	/**************************************************
	Registradores e fios de dados
	**************************************************/
	wire signed [15:0] data_out_nodes[4:0];
	reg signed [15:0] data_to_a;
	reg signed [15:0] data_to_b[4:0];
	reg [6:0] tmp_reg_addr;
	
	/**********************************************
	Registradores e fios de controle
	**********************************************/
	reg iteration_done;
	reg enable_nodes;
	reg enable_sd_fms;
	reg clear_acc;
	
	/*******************************************************
	Registradores de estado
	*******************************************************/
	reg [3:0] fr_fms_state;
	reg [3:0] sd_fms_state;
	
	/****************************************
	Logica sequencia da Primeira FMS (FR FMS)
	*****************************************/

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			fr_fms_state <= RQ_REG;
		end else if (enable) begin
			case (fr_fms_state)
				RQ_REG: begin
					fr_fms_state <= ST_REG;
				end
				ST_REG: begin
					data_to_a = data_in_register;

					fr_fms_state <= RQ_BETA1;

				end
				RQ_BETA1: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA1;
					end else begin
						fr_fms_state <= RQ_BETA1;
					end
				end
				ST_BETA1: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA1;
					end else begin
						fr_fms_state <= RQ_BETA2;
					end
					data_to_b[0] = data_in_beta;
				end
				RQ_BETA2: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA2;
					end else begin
						fr_fms_state <= RQ_BETA2;
					end
					
				end
				ST_BETA2: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA2;
					end else begin
						fr_fms_state <= RQ_BETA3;
					end
					data_to_b[1] = data_in_beta;
					
				end
				RQ_BETA3: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA3;
					end else begin
						fr_fms_state <= RQ_BETA3;
					end
				end
				ST_BETA3: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA3;
					end else begin
						fr_fms_state <= RQ_BETA4;
					end
					data_to_b[2] = data_in_beta;
				end
				RQ_BETA4: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA4;
					end else begin
						fr_fms_state <= RQ_BETA4;
					end
				end
				ST_BETA4: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA4;
					end else begin
						fr_fms_state <= RQ_BETA5;
					end
					data_to_b[3] = data_in_beta;
				end
				RQ_BETA5: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA5;
					end else begin
						fr_fms_state <= RQ_BETA5;
					end
				end
				ST_BETA5: begin
					if (is_avaliable_beta) begin
						fr_fms_state <= ST_BETA5;
					end else begin
						fr_fms_state <= CALC;
					end
					data_to_b[4] = data_in_beta;
				end
				CALC: begin
					fr_fms_state <= WAIT_SD_FMS;
				end
				WAIT_SD_FMS: begin
					if (iteration_done) begin
						fr_fms_state <= RQ_REG;
					end else begin
						fr_fms_state <= WAIT_SD_FMS;
					end
				end
				default: begin
					fr_fms_state <= RQ_REG;
				end
			endcase
		end
	end
	
	/*********************************************
	Logica combinacional da Primeira FMS (FR FMS)
	**********************************************/
	always @(*) begin
		enable_nodes = 1'b0;
		enable_sd_fms = 1'b0;
		case (fr_fms_state)
			RQ_REG: begin
				enable_sd_fms = 1'b0;
				addr_register = tmp_reg_addr;
			end
			RQ_BETA1: begin
				req_beta = 1'b1;
				addr_beta = (tmp_reg_addr * 11'd10) + (iteration_counter * 11'd5);
			end
			ST_BETA1: begin
				req_beta = 1'b0;
			end
			RQ_BETA2: begin
				req_beta = 1'b1;
				addr_beta = (tmp_reg_addr * 11'd10) + (iteration_counter * 11'd5) + 11'd1;
			end
			ST_BETA2: begin
				req_beta = 1'b0;
			end
			RQ_BETA3: begin
				req_beta = 1'b1;
				addr_beta = (tmp_reg_addr * 11'd10) + (iteration_counter * 11'd5) + 11'd2;
			end
			ST_BETA3: begin
				req_beta = 1'b0;
				
			end
			RQ_BETA4: begin
				req_beta = 1'b1;
				addr_beta = (tmp_reg_addr * 11'd10) + (iteration_counter * 11'd5) + 11'd3;
			end
			ST_BETA4: begin
				req_beta = 1'b0;
			end
			RQ_BETA5: begin
				req_beta = 1'b1;
				addr_beta = (tmp_reg_addr * 11'd10) + (iteration_counter * 11'd5) + 11'd4;
			end
			ST_BETA5: begin
				req_beta = 1'b0;
			end
			CALC: begin
				enable_nodes = 1'b1;
			end
			WAIT_SD_FMS: begin
				enable_nodes = 1'b0;
				enable_sd_fms = 1'b1;
			end
		endcase
	end
	
	
	/*******************************************************
	Logica Sequencial da Segunda FMS (SD FMS)
	*******************************************************/
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			tmp_reg_addr <= 7'b0;
			iteration_counter <= 1'b0;
			sd_fms_state <= VF_LAST_DATA;
			clear_acc <= 1'b0;
			done <= 1'b0;
		end else if (enable_sd_fms) begin
			case (sd_fms_state)
				VF_LAST_DATA: begin
					if (tmp_reg_addr == 7'd127) begin
						sd_fms_state <= ST_RES1;
					end else begin
						sd_fms_state <= INCREMENT;
					end
				end
				ST_RES1: begin
					sd_fms_state <= WAIT_RES1;
				end
				WAIT_RES1: begin
					sd_fms_state <= ST_RES2;
				end
				ST_RES2: begin
					sd_fms_state <= WAIT_RES2;
				end
				WAIT_RES2: begin
					sd_fms_state <= ST_RES3;
				end
				ST_RES3: begin
					sd_fms_state <= WAIT_RES3;
				end
				WAIT_RES3: begin
					sd_fms_state <= ST_RES4;
				end
				ST_RES4: begin
					sd_fms_state <= WAIT_RES4;
				end
				WAIT_RES4: begin
					sd_fms_state <= ST_RES5;
				end
				ST_RES5: begin
					sd_fms_state <= WAIT_RES5;
				end
				WAIT_RES5: begin
					sd_fms_state <= INCREMENT;
				end
				INCREMENT: begin
					if (tmp_reg_addr == 7'd127 && iteration_counter) begin
						done <= 1'b1;
					end else begin
						done <= 1'b0;
					end
					if (tmp_reg_addr == 7'd127) begin
						iteration_counter <= iteration_counter + 1'b1;
						tmp_reg_addr <= 7'd0;
						clear_acc <= 1'b1;
					end else begin
						tmp_reg_addr <= tmp_reg_addr + 1'b1;
					end
					sd_fms_state <= DONE_IT;
				end
				DONE_IT: begin
					clear_acc <= 1'b0;
					sd_fms_state <= VF_LAST_DATA;
				end
				default: begin
					sd_fms_state <= VF_LAST_DATA;
				end
			endcase
		end	
	end
	
	
	/*************************************************
	Logica combinacional da segunda FMS (SD FMS)
	**************************************************/
	
	always @(*) begin
		enable_register_write = 1'b0;
		case (sd_fms_state)
			VF_LAST_DATA: begin
				iteration_done <= 1'b0;
			end
			ST_RES1: begin
				addr_register_raw = 4'd0 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[0];
				enable_register_write = 1'b1;
			end
			WAIT_RES1: begin
				addr_register_raw = 4'd0 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[0];
				enable_register_write = 1'b0;
			end
			ST_RES2: begin
				addr_register_raw = 4'd1 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[1];
				enable_register_write = 1'b1;
			end
			WAIT_RES2: begin
				addr_register_raw = 4'd1 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[1];
				enable_register_write = 1'b0;
			end
			ST_RES3: begin
				addr_register_raw = 4'd2 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[2];
				enable_register_write = 1'b1;
			end
			WAIT_RES3: begin
				addr_register_raw = 4'd2 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[2];
				enable_register_write = 1'b0;
			end
			ST_RES4: begin
				addr_register_raw = 4'd3 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[3];
				enable_register_write = 1'b1;
			end
			WAIT_RES4: begin
				addr_register_raw = 4'd3 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[3];
				enable_register_write = 1'b0;
			end
			ST_RES5: begin
				addr_register_raw = 4'd4 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[4];
				enable_register_write = 1'b1;
			end
			WAIT_RES5: begin
				addr_register_raw = 4'd4 + (iteration_counter*4'd5);
				data_register_raw = data_out_nodes[4];
				enable_register_write = 1'b0;
			end
			DONE_IT: begin
				iteration_done <= 1'b1;
			end
		endcase
	end

	/***************************************************
		Instanciamento do acumuladores
	****************************************************/
	
	mac_second_layer node0(
		.data_register(data_to_a),
		.data_beta(data_to_b[0]),
		.clk(clk),
		.rst(rst),
		.clear_acc(clear_acc),
		.enable(enable_nodes),
		.out_q4_12(data_out_nodes[0])
	);
	mac_second_layer node1(
		.data_register(data_to_a),
		.data_beta(data_to_b[1]),
		.clk(clk),
		.rst(rst),
		.clear_acc(clear_acc),
		.enable(enable_nodes),
		.out_q4_12(data_out_nodes[1])
	);
	mac_second_layer node2(
		.data_register(data_to_a),
		.data_beta(data_to_b[2]),
		.clk(clk),
		.rst(rst),
		.clear_acc(clear_acc),
		.enable(enable_nodes),
		.out_q4_12(data_out_nodes[2])
	);
	mac_second_layer node3(
		.data_register(data_to_a),
		.data_beta(data_to_b[3]),
		.clk(clk),
		.rst(rst),
		.clear_acc(clear_acc),
		.enable(enable_nodes),
		.out_q4_12(data_out_nodes[3])
	);
	mac_second_layer node4(
		.data_register(data_to_a),
		.data_beta(data_to_b[4]),
		.clk(clk),
		.rst(rst),
		.clear_acc(clear_acc),
		.enable(enable_nodes),
		.out_q4_12(data_out_nodes[4])
	);
	
endmodule