`ifndef VECTOR_WRITEBACK_V
`define VECTOR_WRITEBACK_V

`include "defines.v"

module vector_writeback(
    // 全局接口
    input            clk,
    input            rst_n,
    
    // 指令接口
    input      [31:0] vsi_op,
    input             vsi_lmul,
    input             vsi_sew,
    input             vsi_op_valid,
    
    // 控制接口
    input             wb_enable,     // 写回使能
    
    // 数据接口
    input      [511:0] vd_bus,
    output    [3:0][4:0] vsi_rf_waddr,
    output    [3:0][15:0] vsi_rf_wstrb,
    output    [3:0][127:0] vsi_rf_wdata
);

    // 内部信号
    parameter VLEN_BITS = 128;
    reg [4:0] vd_idx_reg;            // 寄存器存储目标寄存器索引
    reg [31:0] vsi_op_last;          // 存储上一次指令，用于检测变化
    
    // 目标寄存器索引在op变化时更新
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            vd_idx_reg <= 5'b0;
            vsi_op_last <= 32'b0;
        end else if(vsi_op != vsi_op_last) begin
            // op变化时，更新vd_idx_reg
            vd_idx_reg <= vsi_op[11:7];
            vsi_op_last <= vsi_op;
        end
    end


    // 写回逻辑 - 使用wire数组替代reg
    integer i;
    
    // 内部连线用于地址和数据计算
    reg [4:0] waddr_temp[3:0];
    reg [15:0] wstrb_temp[3:0];
    reg [127:0] wdata_temp[3:0];
    
    // 判断是否为VREDSUM指令
    reg is_vredsum;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            is_vredsum <= 1'b0;
        end else if(vsi_op_valid) begin
            is_vredsum <= (vsi_op[31:26] == `OPC_VREDSUM);
        end
    end
    
    always @* begin
        // 初始化临时变量 - 所有值默认置零
        waddr_temp[0] = 5'd0;
        waddr_temp[1] = 5'd0;
        waddr_temp[2] = 5'd0;
        waddr_temp[3] = 5'd0;
        
        wstrb_temp[0] = 16'h0;
        wstrb_temp[1] = 16'h0;
        wstrb_temp[2] = 16'h0;
        wstrb_temp[3] = 16'h0;
        
        wdata_temp[0] = 128'd0;
        wdata_temp[1] = 128'd0;
        wdata_temp[2] = 128'd0;
        wdata_temp[3] = 128'd0;
        

        // 在启用写回时计算地址和数据
        if(wb_enable) begin
            if(is_vredsum) begin
                // VREDSUM指令特殊处理
                // 只设置第一个寄存器地址
                waddr_temp[0] = vd_idx_reg;
                
                // 根据vsi_lmul设置写使能
                if(vsi_sew) begin
                    wstrb_temp[0] = 16'h000F;  // lmul=1，写入32位
                end else begin
                    wstrb_temp[0] = 16'h0001;  // lmul=0，写入8位
                end
                
                // 其他写使能都置为0
                wstrb_temp[1] = 16'h0000;
                wstrb_temp[2] = 16'h0000;
                wstrb_temp[3] = 16'h0000;
                
                // 写入数据
                wdata_temp[0] = vd_bus[127:0];
            end else if(vsi_lmul) begin  // lmul = 1，使用4个寄存器组
                // 写地址：连续4个寄存器，使用寄存器中存储的vd_idx
                waddr_temp[0] = vd_idx_reg;
                waddr_temp[1] = vd_idx_reg + 1;
                waddr_temp[2] = vd_idx_reg + 2;
                waddr_temp[3] = vd_idx_reg + 3;

                // 所有写使能都置位
                wstrb_temp[0] = 16'hFFFF;
                wstrb_temp[1] = 16'hFFFF;
                wstrb_temp[2] = 16'hFFFF;
                wstrb_temp[3] = 16'hFFFF;

                // 写入全部4组数据
                wdata_temp[0] = vd_bus[127:0];
                wdata_temp[1] = vd_bus[255:128];
                wdata_temp[2] = vd_bus[383:256];
                wdata_temp[3] = vd_bus[511:384];
            end else begin      // lmul = 0，仅使用1个寄存器组
                // 只设置第一个寄存器地址，使用寄存器中存储的vd_idx
                waddr_temp[0] = vd_idx_reg;

                // 只设置第一个写使能
                wstrb_temp[0] = 16'hFFFF;
                wstrb_temp[1] = 16'h0000;
                wstrb_temp[2] = 16'h0000;
                wstrb_temp[3] = 16'h0000;

                // 只写入第一组数据
                wdata_temp[0] = vd_bus[127:0];
                // 其他组保持为0
            end
        end
    end
    
    // 使用assign语句将内部数组连接到输出端口
    assign vsi_rf_waddr[0] = waddr_temp[0];
    assign vsi_rf_waddr[1] = waddr_temp[1];
    assign vsi_rf_waddr[2] = waddr_temp[2];
    assign vsi_rf_waddr[3] = waddr_temp[3];
    assign vsi_rf_wstrb[0] = wstrb_temp[0];
    assign vsi_rf_wstrb[1] = wstrb_temp[1];
    assign vsi_rf_wstrb[2] = wstrb_temp[2];
    assign vsi_rf_wstrb[3] = wstrb_temp[3];
    assign vsi_rf_wdata[0] = wdata_temp[0];
    assign vsi_rf_wdata[1] = wdata_temp[1];
    assign vsi_rf_wdata[2] = wdata_temp[2];
    assign vsi_rf_wdata[3] = wdata_temp[3];

endmodule
`endif 