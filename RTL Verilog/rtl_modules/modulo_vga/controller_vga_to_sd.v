/*Modulo VGA desenvolvido para a materia de sistemas digitais
* por Maike de Oliveira Nascimento*/


module controller_vga_to_sd(
posx, /*Posição no eixo x do pixel*/
posy, /*Posição no eixo y do pixel*/
enable, /*Habilitação da escrita de um novo pixel*/
red, /*Cor vermelha a ser escrita*/
green, /*Cor verde a ser escrita*/
blue, /*Cor azul a ser escrita*/
clk, /*Clock de 50 MHz vindo da placa*/
rst, /*Sinal de reset para o modulo*/
hs, /*Sinconização horizontal da saida VGA*/
vs, /*Sinconização Vertical da saida VGA*/
sync, /*Sinal de sync da saida VGA*/
blank, /*Sinal de Blank da saida VGA*/
vga_clk, /*Sinal de CLK do VGA*/
vga_red, /*Canal vermelho do VGA*/
vga_green, /*Canal verde do VGA*/
vga_blue, /*Canal azul do VGA*/
done /*Sinal de done emitido pelo modulo apos escrever uma cor na memoria*/

);
	input [8:0] posx;
	input [7:0] posy;
	input [2:0] red, green, blue;
	input clk, rst, enable;
	output hs, vs, sync, blank, vga_clk;
	output [7:0] vga_red, vga_blue, vga_green;
	output reg done;


	localparam IDLE=2'b00, WRITE=2'b01, DONE=2'b10;

	wire [9:0] next_x, next_y; /*Endereço do proximo pixel a ser lido pelo modulo VGA*/
	wire clk100, clk25; /*clks internos utilizados pelo modulo VGA e pelas memorias*/
    reg [16:0] mem_addr_wr; /*Endereço de escrita */

	reg [1:0] state;
	wire [1:0] lsu_done;

	reg [1:0] lsu_enable;
	reg enable_write;
	reg [8:0] color_in;

	always @(posedge clk) begin
		if (rst) begin
			state <= IDLE;
			lsu_enable <= 2'b0;
			done <= 1'b0;
		end else begin
			case(state)
				IDLE: begin
					 if (enable) begin
						  done <= 1'b0;
						  state <= WRITE;
						  lsu_enable <= 2'b11;
					 end
				end
				WRITE: begin
					if(lsu_done[1]) begin
						state <= DONE;
						lsu_enable <= 2'b00;
					end
				end

				DONE: begin
					state <= IDLE;
					done <= 1'b1;
				end
				default: begin
					state <= IDLE;
				end
			endcase
		end
	end


	always @(*) begin
		enable_write = 1'b0;
		color_in = 9'b0;
		case(state)
			WRITE: begin
				color_in = {red, green, blue};
                mem_addr_wr = posx + (320*posy); /*Calculo do endereço a qual o pixel será escrito*/
				enable_write = 1'b1; /*Sinal de habilitação escrita*/

			end
			DONE: begin
				enable_write = 1'b0;
			end
		endcase
	end

	reg [16:0] addr_vga_rd;


	always @(posedge clk25) begin
		addr_vga_rd <= (next_x>>1) + ((next_y>>1)*320);

	end

	/*Pll para geração dos clocks de 100 e 25 MHz*/
	pll01 (
		 .refclk(clk),   //  refclk.clk
		 .rst(rst),      //   reset.reset
		 .outclk_0(clk100), // outclk0.clk
		 .outclk_1(clk25), // outclk1.clk
		 .locked()    //  locked.export
	);

    /*Controlador de memoria para dados vindos do usuario*/
	lsu_controller #( .DATA_WIDTH(9),
		  .MEM_SIZE(76800),
		  .CYCLES_PER_OP(3),
		  .DEVICE_FAMILY("Cyclone V"),
		  .RAM_TYPE("AUTO"),
		  .INIT_FILE("")) usermemory(
		 .addr_write(mem_addr_wr),
		 .addr_read(),
		 .clk(clk100),
		 .write_en(enable_write),
		 .data_in(color_in),
		 .data_out(),
		 .done(lsu_done[0]),
		 .enable(lsu_enable[0]),
		 .rst(rst)
	);

	wire [8:0] color_to_vga;

    /*Controlador de memoria para dados que vão ser lidos pelo modulo VGA*/
	lsu_controller #( .DATA_WIDTH(9),
		  .MEM_SIZE(76800),
		  .CYCLES_PER_OP(3),
		  .DEVICE_FAMILY("Cyclone V"),
		  .RAM_TYPE("AUTO"),
		  .INIT_FILE("")) vgamemory (
		 .addr_write(mem_addr_wr),
		 .addr_read(addr_vga_rd),
		 .clk(clk100),
		 .write_en(enable_write),
		 .data_in(color_in),
		 .data_out(color_to_vga),
		 .done(lsu_done[1]),
		 .enable(lsu_enable[1]),
		 .rst(rst)
	);

    /*Driver VGA*/
	vga_driver (
     .clock(clk25),     // 25 MHz
     .reset(rst),     // Active high
     .color_in(color_to_vga), // Pixel color data (RRRGGGBBB)
     .next_x(next_x),  // x-coordinate of NEXT pixel that will be drawn
     .next_y(next_y),  // y-coordinate of NEXT pixel that will be drawn
     .hsync(hs),    // HSYNC (to VGA connector)
     .vsync(vs),    // VSYNC (to VGA connctor)
     .red(vga_red),     // RED (to resistor DAC VGA connector)
     .green(vga_green),   // GREEN (to resistor DAC to VGA connector)
     .blue(vga_blue),    // BLUE (to resistor DAC to VGA connector)
     .sync(sync),          // SYNC to VGA connector
     .clk(vga_clk),           // CLK to VGA connector
     .blank(blank)          // BLANK to VGA connector
    );


endmodule
