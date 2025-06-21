`ifndef VMACC_UNIT_V
`define VMACC_UNIT_V
module vmacc_unit #(parameter VLEN_BITS = 128)(
    input  wire                      sew,        // 0: int8, 1: int32
    input  wire                      lmul,       // 0: 1 register, 1: 4 registers
    input  wire [VLEN_BITS*4-1:0]    vs2_bus,
    input  wire [VLEN_BITS*4-1:0]    vs1_bus,
    input  wire [VLEN_BITS*4-1:0]    acc_bus,    // 原 vd 数值
    output reg  [VLEN_BITS*4-1:0]    vd_bus
);
    integer i;
    reg [15:0] mul8;
    reg [63:0] mul32;
    reg [31:0] element_count;

    always @* begin
        vd_bus = acc_bus; // 默认传递
        
        // 计算元素数量
        case({lmul, sew})
            2'b00: element_count = 16;  // lmul=0, sew=0: 16个int8 (128/8=16)
            2'b01: element_count = 4;   // lmul=0, sew=1: 4个int32 (128/32=4)
            2'b10: element_count = 64;  // lmul=1, sew=0: 64个int8 (128*4/8=64)
            2'b11: element_count = 16;  // lmul=1, sew=1: 16个int32 (128*4/32=16)
        endcase
        
        if(sew == 1'b0) begin // int8 元素
            for(i=0; i<element_count; i=i+1) begin
                mul8  = vs2_bus[i*8 +: 8] * vs1_bus[i*8 +: 8];
                vd_bus[i*8 +: 8] = mul8[7:0] + acc_bus[i*8 +: 8];
            end
        end else begin          // int32 元素
            for(i=0; i<element_count; i=i+1) begin
                mul32 = vs2_bus[i*32 +: 32] * vs1_bus[i*32 +: 32];
                vd_bus[i*32 +: 32] = mul32[31:0] + acc_bus[i*32 +: 32];
            end
        end
    end
endmodule
`endif