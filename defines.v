`ifndef VECTOR_DEFINES_V
`define VECTOR_DEFINES_V

`define OPC_VXOR      6'b001011
`define OPC_VMACC     6'b101101
`define OPC_VREDSUM   6'b000000
`define OPC_VSLIDEUP  6'b001110
`define OPC_VRGATHER  6'b001100

`define FUNCT3_VXOR   3'b000
`define FUNCT3_VMACC  3'b010
`define FUNCT3_VREDS  3'b010
`define FUNCT3_VSLIDE 3'b011
`define FUNCT3_VRGATH 3'b000

`define VLEN          128          // \u5355\u5bc4\u5b58\u5668\u4f4d\u5bbd(bit)

`endif