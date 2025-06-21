`ifndef VSLIDEUP_UNIT_V
`define VSLIDEUP_UNIT_V
module vslideup_unit #(parameter VLEN_BITS = 128)(
    input  wire                      sew,
    input  wire                      lmul,       // 0: 1 register, 1: 4 registers
    input  wire [4:0]                uimm,
    input  wire [VLEN_BITS*4-1:0]    vs2_bus,
    input  wire [VLEN_BITS*4-1:0]    vd_prev_bus,
    output reg  [VLEN_BITS*4-1:0]    vd_bus
);
    integer i;
    // 根据lmul和sew确定元素数量
    reg [31:0] element_count;
    
    always @* begin
        // 计算元素数量
        case({lmul, sew})
            2'b00: element_count = 16;  // lmul=0, sew=0: 16个int8 (128/8=16)
            2'b01: element_count = 4;   // lmul=0, sew=1: 4个int32 (128/32=4)
            2'b10: element_count = 64;  // lmul=1, sew=0: 64个int8 (128*4/8=64)
            2'b11: element_count = 16;  // lmul=1, sew=1: 16个int32 (128*4/32=16)
        endcase
        
        // 默认将vd_bus设为vd_prev_bus，保留原值
        vd_bus = vd_prev_bus;
        
        if(sew == 1'b0) begin            // int8
            for(i=0; i < element_count; i=i+1) begin
                if(i < uimm) begin
                    // 保留原值，已经在默认赋值中处理
                    vd_bus[i*8 +: 8] = vd_prev_bus[i*8 +: 8];
                end else begin
                    vd_bus[i*8 +: 8] = vs2_bus[(i-uimm)*8 +: 8];
                end
            end
        end else begin                   // int32
            for(i=0; i < element_count; i=i+1) begin
                if(i < uimm) begin
                    // 保留原值，已经在默认赋值中处理
                    vd_bus[i*32 +: 32] = vd_prev_bus[i*32 +: 32];
                end else begin
                    vd_bus[i*32 +: 32] = vs2_bus[(i-uimm)*32 +: 32];
                end
            end
        end
    end
endmodule
`endif