`include "constants.vh"

module elm_accel(
    input wire        clk, rst,
    input wire [31:0] instruction,
    input wire        enable,
    
    output reg [31:0] result,
    output reg        busy, done, error,

    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output wire [9:0] LEDR
);

    localparam [2:0] // Estados
        ST_IDLE     = 3'b000,
        ST_FETCH    = 3'b001,
        ST_DECODE   = 3'b010,
        ST_EXECUTE  = 3'b011,
        ST_DONE     = 3'b100,
        ST_WAIT_W   = 3'b101,
        ST_WAIT_PES = 3'b110,  // aguarda `OP_PES_DATA após `OP_PES_ADDR
        ST_INFER    = 3'b111;  // aguarda inferência terminar

    // Registradores
    reg [2:0]  estado;
    reg [31:0] inst_reg;

    reg wait_w_reg;

    reg [3:0]  opcode_reg;
    reg [11:0] addr_reg;
    reg [15:0] data_reg;
    reg [16:0] w_addr_reg;

    reg img_we;
    reg pesos_we;
    reg beta_we;
    reg bias_we;
    reg infer_start;

    reg [9:0]  img_waddr;
    reg [6:0]  bias_waddr;
    reg [16:0] pesos_waddr;
    reg [10:0] beta_waddr;

    wire       done_w, busy_w;
    wire [3:0] pred_w;

    reg enable_d;

    always @(posedge clk) begin
        enable_d <= enable;
    end

    wire enable_pulse = enable & ~enable_d;

    assign LEDR[3:0] = estado;
    assign LEDR[4]   = busy;
    assign LEDR[5]   = done;
    assign LEDR[6]   = error;
    assign LEDR[9]   = busy_w;
	assign LEDR[8]   = done_w;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado      <= ST_IDLE;
            busy        <= 1'b0;
            done        <= 1'b0;
            error       <= 1'b0;
            infer_start <= 1'b0;
            wait_w_reg  <= 1'b0;
            img_we      <= 1'b0;
            pesos_we    <= 1'b0;
            beta_we     <= 1'b0;
            bias_we     <= 1'b0;
            result      <= 32'b0;

        end else begin
            infer_start <= 1'b0;
            busy <= (estado != ST_IDLE && estado != ST_DONE);

            case (estado)
                ST_IDLE: begin
                    done  <= 1'b0;
                    error <= 1'b0;

                    if (enable_pulse) begin
                        inst_reg <= instruction;
                        estado   <= ST_FETCH;
                    end
                end

                ST_FETCH: begin
                    opcode_reg <= inst_reg[31:28];
                    addr_reg   <= inst_reg[27:16];
                    w_addr_reg <= inst_reg[16:0];
                    data_reg   <= inst_reg[15:0];
                    estado     <= ST_DECODE;
                end

                ST_DECODE: begin
                    case (opcode_reg)
                        `OP_IMG,
                        `OP_PES_ADDR,
                        `OP_PES_DATA,
                        `OP_BIAS,
                        `OP_BETA,
                        `OP_START:
									estado <= ST_EXECUTE;

                        OP_STATUS: begin
                            result <= {
                                26'b0,
                                wait_w_reg,
                                done_w,
                                busy_w,
                                pred_w
                            };
                            estado <= ST_DONE;
                        end

                        default: begin
                            result <= 32'hFFFFFFFF;
                            error  <= 1'b1;
                            estado <= ST_DONE;
                        end
                    endcase
                end

                ST_EXECUTE: begin
                    case (opcode_reg)
                        `OP_IMG: begin
                            img_waddr <= addr_reg;
                            img_we    <= 1'b1;
                            estado    <= ST_WAIT_W;
                        end

                        // Só salva o endereço e vai para ST_WAIT_PES
                        // aguardando o próximo `OP_PES_DATA a
                        `OP_PES_ADDR: begin
                            pesos_waddr <= w_addr_reg;
                            wait_w_reg  <= 1'b1;
                            estado      <= ST_WAIT_PES;
                        end

                        // Só aceito se viemos de ST_WAIT_PES (wait_w_reg = 1)
                        // Caso contrário, erro: endereço não foi definido
                        `OP_PES_DATA: begin
                            if (wait_w_reg) begin
                                pesos_we   <= 1'b1;
                                wait_w_reg <= 1'b0;
                                estado     <= ST_WAIT_W;
                            end else begin
                                result <= 32'hFFFFFFFF; // erro: addr não definido
                                error  <= 1'b1;
                                estado <= ST_DONE;
                            end
                        end

                        `OP_BIAS: begin
                            bias_waddr <= addr_reg;
                            bias_we    <= 1'b1;
                            estado     <= ST_WAIT_W;
                        end

                        `OP_BETA: begin
                            beta_waddr <= addr_reg;
                            beta_we    <= 1'b1;
                            estado     <= ST_WAIT_W;
                        end

                        // Dispara inferência e vai para ST_INFER esperar
                        `OP_START: begin
                            if (!busy_w) begin
                                infer_start <= 1'b1;
                                estado      <= ST_INFER;
                            end else begin
                                // Acelerador ocupado: erro
                                result <= 32'hFFFFFFFE;
                                error  <= 1'b1;
                                estado <= ST_DONE;
                            end
                        end

                        default: begin
                            result <= 32'hFFFFFFFF;
                            error  <= 1'b1;
                            estado <= ST_DONE;
                        end
                    endcase
                end

                // Aguarda `OP_PES_DATA: fica em idle parcial
                // aceitando apenas a próxima instrução PES_DATA
                ST_WAIT_PES: begin
                    if (enable_pulse) begin
                        if (instruction[31:28] == `OP_PES_DATA) begin
                            inst_reg <= instruction;
                            estado   <= ST_FETCH;
                        end else begin
                            error  <= 1'b1;
                            result <= 32'hFFFFFFFD;
                            estado <= ST_DONE;
                        end
                    end
                end

                // Polling da inferência: espera busy_w cair e done_w subir
                ST_INFER: begin
                    if (done_w) begin
                        result <= {28'b0, pred_w};
                        estado <= ST_DONE;
                    end
                    // Se ainda busy_w=1 ou done_w=0, fica aqui
                end

                ST_WAIT_W: begin
                    img_we   <= 1'b0;
                    pesos_we <= 1'b0;
                    beta_we  <= 1'b0;
                    bias_we  <= 1'b0;
                    estado   <= ST_DONE;
                end

                ST_DONE: begin
                    done        <= 1'b1;
                    error       <= 1'b0;
                    infer_start <= 1'b0;

                    img_we      <= 1'b0;
                    pesos_we    <= 1'b0;
                    beta_we     <= 1'b0;
                    bias_we     <= 1'b0;
                    wait_w_reg  <= 1'b0;

                     if (!enable)
								estado <= ST_IDLE;
                end
            endcase
        end
    end

    fsm u_fsm (
        .clk         (clk),
        .rst_n       (~rst),
        .start       (infer_start),

        .img_we      (img_we),
        .img_waddr   (img_waddr),
        .img_wdata   (data_reg),

        .pesos_we    (pesos_we),
        .pesos_waddr (pesos_waddr),
        .pesos_wdata (data_reg),

        .beta_we     (beta_we),
        .beta_waddr  (beta_waddr),
        .beta_wdata  (data_reg),

        .bias_we     (bias_we),
        .bias_waddr  (bias_waddr),
        .bias_wdata  (data_reg),

        .done        (done_w),
        .pred        (pred_w),
        .busy        (busy_w)
    );

    display u_disp (
        .clk    (clk),
        .rst    (rst),
        .busy   (busy_w),
        .done   (done_w),
        .pred   (pred_w),
        .opcode (opcode_reg),
        .HEX0   (HEX0),
        .HEX1   (HEX1),
        .HEX2   (HEX2),
        .HEX3   (HEX3),
        .HEX4   (HEX4),
        .HEX5   (HEX5)
    );

endmodule