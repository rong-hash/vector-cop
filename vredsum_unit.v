`ifndef VREDSUM_UNIT_V
`define VREDSUM_UNIT_V
module vredsum_unit #(parameter VLEN_BITS = 128)(
    input  wire                      sew,        // 0: int8, 1: int32
    input  wire                      lmul,       // 0: 1 register, 1: 4 registers
    input  wire [VLEN_BITS*4-1:0]    vs2_bus,
    input  wire [VLEN_BITS-1:0]      vs1_bus,    // 只用单寄存器 (128 bit)
    output reg  [VLEN_BITS-1:0]      vd_bus
);
    integer i;
    reg [31:0]  sum8;   // 为int8求和使用32位，避免溢出
    reg [63:0]  sum32;  // 为int32求和使用64位，避免溢出
    
    // 确定根据sew和lmul的元素数量
    reg [31:0] element_count;
    
    always @* begin
        // 组合计算元素数量
        case({lmul, sew})
            2'b00: element_count = 16;  // lmul=0, sew=0: 16个int8 (128/8=16)
            2'b01: element_count = 4;   // lmul=0, sew=1: 4个int32 (128/32=4)
            2'b10: element_count = 64;  // lmul=1, sew=0: 64个int8 (128*4/8=64)
            2'b11: element_count = 16;  // lmul=1, sew=1: 16个int32 (128*4/32=16)
        endcase
        
        // 初始化vd_bus为vs1_bus

        
        // 根据sew选择不同的处理方式
        if(sew == 1'b0) begin         // int8元素
            sum8 = 0;
            // 累加vs2_bus中的所有有效int8元素
            for(i = 0; i < element_count; i = i + 1) begin
                sum8 = sum8 + {{24{vs2_bus[i*8+7]}}, vs2_bus[i*8 +: 8]}; // 符号扩展
            end
            // 将结果写入vd_bus[0]
            vd_bus = {vd_bus[VLEN_BITS-1:8], sum8[7:0] + vs1_bus[7:0]}; 
        end else begin                // int32元素
            sum32 = 0;
            // 累加vs2_bus中的所有有效int32元素
            for(i = 0; i < element_count; i = i + 1) begin
                sum32 = sum32 + {{32{vs2_bus[i*32+31]}}, vs2_bus[i*32 +: 32]}; // 符号扩展
            end
            // 将结果写入vd_bus[0]
            vd_bus = {vd_bus[VLEN_BITS-1:32], sum32[31:0] + vs1_bus[31:0]};
        end
    end
endmodule
`endif