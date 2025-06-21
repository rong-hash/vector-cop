`ifndef VECTOR_FETCH_V
`define VECTOR_FETCH_V

`include "defines.v"

module vector_fetch(
    // 全局接口
    input            clk,
    input            rst_n,
    
    // 指令接口
    input      [31:0] vsi_op,
    input             vsi_lmul,
    input      [2:0]  cur_inst,   // 当前指令类型
    input reg  [2:0]  vsi_state,
    
    // 寄存器堆读地址接口
    output [7:0][4:0] vsi_rf_raddr    // 修改为wire类型输出
);
// ---------------- FSM --------------------------
    localparam [2:0] S_IDLE  = 3'd0,
                     S_ADDR  = 3'd1,  // 地址取值阶段
                     S_DEC   = 3'd2,  // 译码阶段
                     S_WB    = 3'd3;  // 写回阶段
    // 指令类型本地参数
    localparam [2:0] INST_VXOR     = 3'b000,
                     INST_VMACC    = 3'b001,
                     INST_VREDSUM  = 3'b010,
                     INST_VSLIDEUP = 3'b011,
                     INST_VRGATHER = 3'b100,
                     INST_INVALID  = 3'b111;

    // 指令字段解码
    wire [4:0] vd_idx  = vsi_op[11:7];
    wire [4:0] vs1_idx = vsi_op[19:15];
    wire [4:0] vs2_idx = vsi_op[24:20];

    // 内部寄存器
    reg [4:0] vsi_rf_raddr_temp[7:0];  // 存储中间地址值



    // 读地址生成
    always @* begin
        if ((vsi_op[31:26] == `OPC_VXOR || vsi_op[31:26] == `OPC_VREDSUM || vsi_op[31:26] == `OPC_VSLIDEUP || vsi_op[31:26] == `OPC_VRGATHER) || (vsi_op[31:26] == `OPC_VMACC && vsi_state == S_IDLE)) begin
            integer j;
            for (j = 0; j < 8; j = j + 1) begin
                vsi_rf_raddr_temp[j] = 5'd0;  // 初始化
            end
            
            // 计算 vs2、vs1、vd 地址
            for(integer i = 0; i < (vsi_lmul ? 4 : 1); i = i + 1) begin
                vsi_rf_raddr_temp[i] = vs2_idx + i[4:0];     // vs2 group 地址
                vsi_rf_raddr_temp[i+4] = vs1_idx + i[4:0];   // vs1 group 地址
            end
            
            if ((cur_inst == 3'b001) || (cur_inst == 3'b010 ) || (cur_inst == 3'b011)) begin  //VMACC或VREDSUM或slide
                if((vsi_op[31:26] == `OPC_VSLIDEUP) && vsi_lmul == 1'b1) begin
                    vsi_rf_raddr_temp[4] = vd_idx;
                    vsi_rf_raddr_temp[5] = vd_idx + 1;
                    vsi_rf_raddr_temp[6] = vd_idx + 2;
                    vsi_rf_raddr_temp[7] = vd_idx + 3;
                end else if (vsi_op[31:26] == `OPC_VREDSUM || (vsi_op[31:26] == `OPC_VSLIDEUP && vsi_lmul == 1'b0) || (vsi_op[31:26] == `OPC_VMACC && vsi_lmul == 1'b0)) begin
                    vsi_rf_raddr_temp[7] = vd_idx;
                end
            end
        end else if (vsi_op[31:26] == `OPC_VMACC && vsi_lmul == 1'b1) begin
            vsi_rf_raddr_temp[4] = vd_idx;
            vsi_rf_raddr_temp[5] = vd_idx + 1;
            vsi_rf_raddr_temp[6] = vd_idx + 2;
            vsi_rf_raddr_temp[7] = vd_idx + 3;
        end
    end

    // 寄存器地址输出 - 使用assign替代always块
    assign vsi_rf_raddr = {vsi_rf_raddr_temp[7], vsi_rf_raddr_temp[6], vsi_rf_raddr_temp[5], vsi_rf_raddr_temp[4], 
                      vsi_rf_raddr_temp[3], vsi_rf_raddr_temp[2], vsi_rf_raddr_temp[1], vsi_rf_raddr_temp[0]};

endmodule
`endif 