
module lsu_controller
    #(parameter DATA_WIDTH=16,
    parameter MEM_SIZE=32,
    parameter CYCLES_PER_OP=3,
    parameter DEVICE_FAMILY = "Cyclone IV",
    parameter RAM_TYPE = "AUTO",
    parameter INIT_FILE = "") (
    addr_write,
    addr_read,
    clk,
    write_en,
    data_in,
    data_out,
    done,
    enable,
    rst
);
    input [$clog2(MEM_SIZE)-1:0] addr_read, addr_write;
    input clk, write_en, enable, rst;
    input [DATA_WIDTH-1:0] data_in;
    output [DATA_WIDTH-1:0] data_out;
    output reg done;
    
    localparam IDLE = 2'b00, IN_OPERATION = 2'b01, DONE=2'b10;
    
    reg [1:0] state;
    reg [$clog2(CYCLES_PER_OP)-1:0] counter;
    
    // Seguramos os comandos no momento do pulso
    reg wr_en_reg;
    reg [$clog2(MEM_SIZE)-1:0] addr_wr_mem_module;
    reg [DATA_WIDTH-1:0] data_in_reg;
    
    // A porta de leitura sempre enxerga o endereço requisitado
    wire [$clog2(MEM_SIZE)-1:0] addr_rd_mem_module = addr_read;

    always @(posedge clk) begin 
        if (rst) begin
            state <= IDLE;
            counter <= 0;
            done <= 1'b0;
            wr_en_reg <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 1'b0;
                    if (enable) begin
                        state <= IN_OPERATION;
                        counter <= 0;
                        wr_en_reg <= write_en;
                        addr_wr_mem_module <= addr_write;
                        data_in_reg <= data_in;
                    end
                end
                IN_OPERATION: begin
                    if (counter == CYCLES_PER_OP - 1) begin
                        state <= DONE;
                        wr_en_reg <= 1'b0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase 
        end 
    end
    
    altsyncram #(
        .operation_mode("DUAL_PORT"),            
        .width_a(DATA_WIDTH),
        .widthad_a($clog2(MEM_SIZE)),
        .numwords_a(MEM_SIZE),
        .width_b(DATA_WIDTH),
        .widthad_b($clog2(MEM_SIZE)),
        .numwords_b(MEM_SIZE),
        .outdata_reg_b("UNREGISTERED"),          
        .address_reg_b("CLOCK0"),
        .read_during_write_mode_mixed_ports("OLD_DATA"), 
        .ram_block_type(RAM_TYPE),
        .intended_device_family(DEVICE_FAMILY),
        .init_file(INIT_FILE)       
    ) internal_ram_inst(
        .clock0(clk),                            
        .wren_a(wr_en_reg),
        .address_a(addr_wr_mem_module),
        .data_a(data_in_reg),
        .address_b(addr_rd_mem_module),
        .q_b(data_out)
    );
endmodule