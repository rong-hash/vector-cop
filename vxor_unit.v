`ifndef VXOR_UNIT_V
`define VXOR_UNIT_V
module vxor_unit #(parameter VLEN_BITS = 128)(
    input  wire                      sew,        // 0:8bit  1:32bit (未用, 但保留接口)
    input  wire [VLEN_BITS*4-1:0]    vs2_bus,    // 最多 4×128 = 512 bits
    input  wire [VLEN_BITS*4-1:0]    vs1_bus,
    output wire [VLEN_BITS*4-1:0]    vd_bus
);
    // XOR 对元素宽度不敏感，直接逐位异或
    assign vd_bus = vs2_bus ^ vs1_bus;
endmodule
`endif