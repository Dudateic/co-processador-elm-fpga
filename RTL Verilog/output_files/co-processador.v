module co_processador (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cmd_valid,
    input  wire [31:0] cmd_data,

    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5
);


    localparam OP_IMG   = 3'b000;
    localparam OP_PESO  = 3'b001;
    localparam OP_BIAS  = 3'b010;
    localparam OP_START = 3'b011;


    reg [1:0]  dec_state;
    reg [2:0]  ctx_opcode;
    reg [16:0] ctx_addr;

    localparam DEC_IDLE      = 2'd0;
    localparam DEC_WAIT_DATA = 2'd1;

   
    reg        img_we;
    reg [9:0]  img_waddr;
    reg [15:0] img_wdata;

    reg        peso_we;
    reg [16:0] peso_waddr;
    reg [15:0] peso_wdata;

    reg        beta_we;
    reg [10:0] beta_waddr;
    reg [15:0] beta_wdata;

    reg        bias_we;
    reg [6:0]  bias_waddr;
    reg [15:0] bias_wdata;


    reg busy;
    reg done;
    reg [3:0] pred;

    reg start_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            done <= 0;
            pred <= 0;
        end else begin
            done <= 0;

            if (start_pulse && !busy)
                busy <= 1;

            if (busy) begin
                busy <= 0;
                done <= 1;
                pred <= pred + 1; // processamento
            end
        end
    end


    reg [2:0] last_op;
    reg       last_is_beta;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_state   <= DEC_IDLE;
            ctx_opcode  <= 0;
            ctx_addr    <= 0;

            img_we  <= 0;
            peso_we <= 0;
            beta_we <= 0;
            bias_we <= 0;
            start_pulse <= 0;

            last_op <= 0;
            last_is_beta <= 0;

        end else begin
            // defaults
            img_we  <= 0;
            peso_we <= 0;
            beta_we <= 0;
            bias_we <= 0;
            start_pulse <= 0;

            case (dec_state)


                DEC_IDLE: begin
                    if (cmd_valid) begin
                        case (cmd_data[31:29])

                            OP_IMG: begin
                                ctx_opcode <= OP_IMG;
                                ctx_addr   <= {7'b0, cmd_data[9:0]};
                                dec_state  <= DEC_WAIT_DATA;
                            end

                            OP_PESO: begin
                                ctx_opcode <= OP_PESO;
                                ctx_addr   <= cmd_data[16:0];
                                dec_state  <= DEC_WAIT_DATA;
                            end

                            OP_BIAS: begin
                                ctx_opcode <= OP_BIAS;
                                ctx_addr   <= cmd_data[10:0];
                                dec_state  <= DEC_WAIT_DATA;
                            end

                            OP_START: begin
                                start_pulse <= 1'b1;
                            end

                        endcase
                    end
                end

 
                DEC_WAIT_DATA: begin
                    if (cmd_valid) begin
                        case (ctx_opcode)

                            OP_IMG: begin
                                img_we    <= 1;
                                img_waddr <= ctx_addr[9:0];
                                img_wdata <= cmd_data[15:0];
                                last_op   <= OP_IMG;
                            end

                            OP_PESO: begin
                                peso_we    <= 1;
                                peso_waddr <= ctx_addr[16:0];
                                peso_wdata <= cmd_data[15:0];
                                last_op    <= OP_PESO;
                            end

                            OP_BIAS: begin
                                if (ctx_addr[10]) begin
                                    // BETA
                                    beta_we    <= 1;
                                    beta_waddr <= ctx_addr[10:0];
                                    beta_wdata <= cmd_data[15:0];
                                    last_op    <= OP_BIAS;
                                    last_is_beta <= 1'b1;
                                end else begin
                                    // BIAS
                                    bias_we    <= 1;
                                    bias_waddr <= ctx_addr[6:0];
                                    bias_wdata <= cmd_data[15:0];
                                    last_op    <= OP_BIAS;
                                    last_is_beta <= 1'b0;
                                end
                            end

                        endcase

                        dec_state <= DEC_IDLE;
                    end
                end

            endcase
        end
    end

  
    localparam [6:0]
        S_OFF = 7'h7F,
        S_0   = 7'h40,
        S_1   = 7'h79,
        S_2   = 7'h24,
        S_3   = 7'h30,
        S_4   = 7'h19,
        S_5   = 7'h12,
        S_6   = 7'h02,
        S_7   = 7'h78,
        S_I   = 7'h79,
        S_M   = 7'h2A,
        S_G   = 7'h42,
        S_P   = 7'h0C,
        S_E   = 7'h06,
        S_S   = 7'h12,
        S_b   = 7'h03,
        S_A   = 7'h08,
        S_t   = 7'h07;

    function [6:0] seg;
        input [3:0] v;
        case (v)
            4'd0: seg = S_0;
            4'd1: seg = S_1;
            4'd2: seg = S_2;
            4'd3: seg = S_3;
            4'd4: seg = S_4;
            4'd5: seg = S_5;
            4'd6: seg = S_6;
            4'd7: seg = S_7;
            default: seg = S_OFF;
        endcase
    endfunction

    reg [6:0] h5, h4, h3;

    always @(*) begin
        case (last_op)
            OP_IMG:  begin h5=S_I; h4=S_M; h3=S_G; end
            OP_PESO: begin h5=S_P; h4=S_E; h3=S_S; end
            OP_BIAS: begin
                if (last_is_beta) begin
                    h5=S_b; h4=S_E; h3=S_t; // bEt
                end else begin
                    h5=S_b; h4=S_I; h3=S_A; // bIA
                end
            end
            default: begin h5=S_OFF; h4=S_OFF; h3=S_OFF; end
        endcase
    end

    assign HEX5 = h5;
    assign HEX4 = h4;
    assign HEX3 = h3;

    assign HEX2 = busy ? S_P : S_OFF;  // P = processing
    assign HEX1 = done ? S_E : S_OFF;  // E = end
    assign HEX0 = seg(pred);

endmodule