`ifndef VECTOR_DECODE_EXECUTE_V
`define VECTOR_DECODE_EXECUTE_V

`include "defines.v"

module vector_decode_execute(
    // 全局接口
    input            clk,
    input            rst_n,
    
    // 指令接口
    input      [31:0] vsi_op,
    input             vsi_sew,
    input             vsi_lmul,
    
    
    // 指令类型输出
    output reg [2:0]  cur_inst,
    
    // 数据接口
    input  [7:0][127:0] vsi_rf_rdata,
    input  reg [7:0][127:0] vs1_vs2_reg,
    output [512-1:0]    vd_bus
);

    // 译码计数器
    reg [1:0] dec_cnt;
    
    // 内部信号
    parameter VLEN_BITS = 128;
    parameter BUS_BITS  = 512;      // 4×128
    
    // -------- 指令类型本地参数 --------
    localparam [2:0] INST_VXOR     = 3'b000,
                     INST_VMACC    = 3'b001,
                     INST_VREDSUM  = 3'b010,
                     INST_VSLIDEUP = 3'b011,
                     INST_VRGATHER = 3'b100,
                     INST_INVALID  = 3'b111;

    // 译码逻辑
    always @* begin
        case(vsi_op[31:26])
            `OPC_VXOR    : cur_inst = INST_VXOR;
            `OPC_VMACC   : cur_inst = INST_VMACC;
            `OPC_VREDSUM : cur_inst = INST_VREDSUM;
            `OPC_VSLIDEUP: cur_inst = INST_VSLIDEUP;
            `OPC_VRGATHER: cur_inst = INST_VRGATHER;
            default      : cur_inst = INST_INVALID;
        endcase
    end



    // ----------- 将 RF 数据映射到总线 ---------------
    reg [BUS_BITS-1:0] vs2_bus, vs1_bus, vd_prev_bus;
    
    // 根据时序图和接口定义正确映射数据
    always @* begin
        if (vsi_op[31:26] != `OPC_VMACC) begin
            vs2_bus = vsi_lmul ? {vsi_rf_rdata[3], vsi_rf_rdata[2], vsi_rf_rdata[1], vsi_rf_rdata[0]} : 
                                    {384'b0, vsi_rf_rdata[0]};
            vs1_bus = vsi_lmul ? {vsi_rf_rdata[7], vsi_rf_rdata[6], vsi_rf_rdata[5], vsi_rf_rdata[4]} : 
                                    {384'b0, vsi_rf_rdata[4]};
            
            // vd_prev 用于需要读取旧目标寄存器的指令
            vd_prev_bus = (vsi_lmul && (cur_inst == INST_VSLIDEUP)) ? {vsi_rf_rdata[7], vsi_rf_rdata[6], vsi_rf_rdata[5], vsi_rf_rdata[4]} : {384'b0, vsi_rf_rdata[7]};
        end
        else begin
            vs2_bus = vsi_lmul ? {vs1_vs2_reg[3], vs1_vs2_reg[2], vs1_vs2_reg[1], vs1_vs2_reg[0]} : 
                                    {384'b0, vs1_vs2_reg[0]};
            vs1_bus = vsi_lmul ? {vs1_vs2_reg[7], vs1_vs2_reg[6], vs1_vs2_reg[5], vs1_vs2_reg[4]} : 
                                    {384'b0, vs1_vs2_reg[4]};
            vd_prev_bus = vsi_lmul ? {vsi_rf_rdata[7], vsi_rf_rdata[6], vsi_rf_rdata[5], vsi_rf_rdata[4]} : {384'b0, vsi_rf_rdata[7]};
        end
    end
    // ----------- 子模块实例化 ----------------------
    wire [BUS_BITS-1:0] xor_out, mac_out, slide_out, gather_out;
    wire [127:0]        red_out128;

    vxor_unit   #(.VLEN_BITS(VLEN_BITS)) u_xor  (vsi_sew, vs2_bus, vs1_bus, xor_out);
    vmacc_unit  #(.VLEN_BITS(VLEN_BITS)) u_mac  (vsi_sew, vsi_lmul, vs2_bus, vs1_bus, vd_prev_bus, mac_out);
    vredsum_unit#(.VLEN_BITS(VLEN_BITS)) u_red  (vsi_sew, vsi_lmul, vs2_bus, vs1_bus, red_out128);
    vslideup_unit#(.VLEN_BITS(VLEN_BITS)) u_sld (vsi_sew, vsi_lmul, vsi_op[19:15], vs2_bus, vd_prev_bus, slide_out);
    vrgather_unit#(.VLEN_BITS(VLEN_BITS)) u_gat (vsi_sew, vs2_bus, vs1_bus, gather_out);
    reg  [BUS_BITS-1:0] vd_bus_reg;
    // 统一 512bit 总线形式
    wire [BUS_BITS-1:0] red_out = vsi_lmul ? { vd_bus_reg[BUS_BITS-1:32], red_out128 } : { vd_bus_reg[VLEN_BITS-1:8], red_out128 };


    always @* begin
        case(cur_inst)
            INST_VXOR    : vd_bus_reg = xor_out;
            INST_VMACC   : vd_bus_reg = mac_out;
            INST_VREDSUM : vd_bus_reg = red_out;
            INST_VSLIDEUP: vd_bus_reg = slide_out;
            INST_VRGATHER: vd_bus_reg = gather_out;
            default      : vd_bus_reg = vd_bus_reg;
        endcase
    end

    // 输出结果
    assign vd_bus = vd_bus_reg;

endmodule
`endif 