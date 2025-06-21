`ifndef VECTOR_COP_V
`define VECTOR_COP_V

`include "defines.v"
`include "vector_fetch.v"
`include "vector_decode_execute.v"
`include "vector_writeback.v"

module vector_cop(
  // Global interface
  input            vsi_clk,
  input            vsi_rst_n,
 
  // Operation interface
  input      [31:0] vsi_op,
  input             vsi_lmul,
  input             vsi_sew,
  input             vsi_op_valid,
  output            vsi_op_ready,
  
  output            vsi_cop_idle,
 
  // Rd/Wr interface
  output [7:0][4:0] vsi_rf_raddr,
  input  [7:0][127:0] vsi_rf_rdata,
  output [3:0][4:0] vsi_rf_waddr,
  output [3:0][15:0] vsi_rf_wstrb,
  output [3:0][127:0] vsi_rf_wdata
);
// Design content

    // ------------------------------------------------------------------
    parameter VLEN_BITS   = 128;
    parameter BUS_BITS    = 512;      // 4×128
    parameter VSI_RD_NUM  = 8;        // 读端口数量
    parameter VSI_WR_NUM  = 4;        // 写端口数量

    // -------- 指令类型本地参数 (与 PDF 对应) --------
    localparam [2:0] INST_VXOR     = 3'b000,
                     INST_VMACC    = 3'b001,
                     INST_VREDSUM  = 3'b010,
                     INST_VSLIDEUP = 3'b011,
                     INST_VRGATHER = 3'b100,
                     INST_INVALID  = 3'b111;

    // ---------------- FSM --------------------------
    localparam [2:0] S_IDLE  = 3'd0,
                     S_ADDR  = 3'd1,  // 地址取值阶段
                     S_DEC   = 3'd2,  // 译码阶段
                     S_WB    = 3'd3;  // 写回阶段

    reg [2:0] state, nstate;
    
    // 子模块控制信号
    wire wb_enable;
    wire wb_done;
    
    // 子模块数据信号
    wire [2:0] cur_inst;
    wire [BUS_BITS-1:0] vd_bus;
    
    // 阶段使能控制
    assign wb_enable = (state == S_WB);
    // 定义8个128位寄存器用于存储vs1和vs2数据
    reg [7:0][127:0] vs1_vs2_reg;
    integer i;
    
    always @(posedge vsi_clk or negedge vsi_rst_n) begin
        if(!vsi_rst_n) begin
            vs1_vs2_reg <= 'h0;  // 使用'h0可以初始化整个数组
        end else if (state == S_IDLE) begin
            vs1_vs2_reg <= vsi_rf_rdata;  // 直接赋值整个数组
        end else begin
            vs1_vs2_reg <= vs1_vs2_reg;
        end
    end
    
    // FSM 状态转换
    always @(posedge vsi_clk or negedge vsi_rst_n) begin
        if(!vsi_rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= nstate;
        end
    end

    always @* begin
        nstate = state;
        case(state)
            S_IDLE: if(vsi_op_valid) begin 
                if (vsi_op[31:26] == `OPC_VMACC && vsi_lmul == 1'b1) begin
                    nstate = S_ADDR; 
                end else begin
                    nstate = S_DEC; 
                end
            end  // 开始取地址
            S_ADDR:                   nstate = S_DEC;   // 地址取值完成，转到译码
            S_DEC:                    nstate = S_WB;    // 译码完成，转到写回
            S_WB:                     nstate = S_IDLE;  // 写回完成，返回空闲状态
            default: nstate = S_IDLE;
        endcase
    end

    assign vsi_op_ready = ((state == S_IDLE) && (vsi_op_valid == 0)) || (state == S_WB);
    assign vsi_cop_idle = (state == S_IDLE) && (vsi_op_valid == 0);

    // 子模块实例化
    // 1. 取址模块
    vector_fetch u_fetch(
        .clk(vsi_clk),
        .rst_n(vsi_rst_n),
        .vsi_op(vsi_op),
        .vsi_lmul(vsi_lmul),
        .vsi_state(state),
        .cur_inst(cur_inst),
        .vsi_rf_raddr(vsi_rf_raddr)
    );
    
    // 2. 译码执行模块
    vector_decode_execute u_decode_execute(
        .clk(vsi_clk),
        .rst_n(vsi_rst_n),
        .vsi_op(vsi_op),
        .vsi_sew(vsi_sew),
        .vsi_lmul(vsi_lmul),
        .cur_inst(cur_inst),
        .vsi_rf_rdata(vsi_rf_rdata),
        .vs1_vs2_reg(vs1_vs2_reg),
        .vd_bus(vd_bus)
    );
    
    // 3. 写回模块
    vector_writeback u_writeback(
        .clk(vsi_clk),
        .rst_n(vsi_rst_n),
        .vsi_op(vsi_op),
        .vsi_op_valid(vsi_op_valid),
        .vsi_lmul(vsi_lmul),
        .vsi_sew(vsi_sew),
        .wb_enable(wb_enable),
        .vd_bus(vd_bus),
        .vsi_rf_waddr(vsi_rf_waddr),
        .vsi_rf_wstrb(vsi_rf_wstrb),
        .vsi_rf_wdata(vsi_rf_wdata)
    );

endmodule
`endif

