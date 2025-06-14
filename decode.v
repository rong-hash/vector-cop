// -----------------------------------------------------------------------------
// Module: instruction_decoder
// Function: Decodes the RISC-V vector instruction fields.
// -----------------------------------------------------------------------------
module instruction_decoder (
    input  wire [31:0] vsi_op,

    output wire [4:0]  vd,
    output wire [4:0]  vs1,
    output wire [4:0]  vs2,
    output wire [4:0]  uimm,

    output wire        is_vxor,
    output wire        is_vmacc,
    output wire        is_vredsum,
    output wire        is_vslideup,
    output wire        is_vrgather
);

    // Operand fields from the instruction
    assign vd  = vsi_op[11:7];
    assign vs1 = vsi_op[19:15];
    assign vs2 = vsi_op[24:20];
    assign uimm = vsi_op[19:15]; // uimm shares the same field as vs1

    // Instruction opcode fields for matching
    wire [6:0] opcode    = vsi_op[6:0];
    wire [2:0] funct3    = vsi_op[14:12];
    wire [6:0] funct6    = vsi_op[31:26];
    wire       vm        = vsi_op[25];

    localparam OPCODE_OPV = 7'b1010111;

    // Decoding logic based on the specification document
    assign is_vxor     = (opcode == OPCODE_OPV) && (funct3 == 3'b000) && (funct6 == 6'b001011) && (vm == 1'b1);
    assign is_vmacc    = (opcode == OPCODE_OPV) && (funct3 == 3'b010) && (funct6 == 6'b101101) && (vm == 1'b1);
    assign is_vredsum  = (opcode == OPCODE_OPV) && (funct3 == 3'b010) && (funct6 == 6'b000000) && (vm == 1'b1);
    assign is_vslideup = (opcode == OPCODE_OPV) && (funct3 == 3'b011) && (funct6 == 6'b001110) && (vm == 1'b1);
    assign is_vrgather = (opcode == OPCODE_OPV) && (funct3 == 3'b000) && (funct6 == 6'b001100) && (vm == 1'b1);

endmodule