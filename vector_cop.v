// -----------------------------------------------------------------------------
// Module: vector_cop (Top Level)
// Competition: 2025 Circuit Design Competition
// Function: A RISC-V Vector Coprocessor
// -----------------------------------------------------------------------------
module vector_cop (
    // Global interface
    input  wire        vsi_clk,
    input  wire        vsi_rst_n,

    // Operation interface
    input  wire [31:0] vsi_op,
    input  wire        vsi_lmul,
    input  wire        vsi_sew,
    input  wire        vsi_op_valid,
    output wire        vsi_op_ready,
    output wire        vsi_cop_idle,

    // Rd/Wr interface
    output wire [7:0][4:0]   vsi_rf_raddr,
    input  wire [7:0][127:0] vsi_rf_rdata,
    output wire [3:0][4:0]   vsi_rf_waddr,
    output wire [3:0][15:0]  vsi_rf_wstrb,
    output wire [3:0][127:0] vsi_rf_wdata
);

    // --- Internal Wires for Inter-module Communication ---

    // Decoder outputs
    wire [4:0]  vd_addr;
    wire [4:0]  vs1_addr;
    wire [4:0]  vs2_addr;
    wire [4:0]  uimm;
    wire        is_vxor;
    wire        is_vmacc;
    wire        is_vredsum;
    wire        is_vslideup;
    wire        is_vrgather;

    // Control Unit outputs
    wire        exec_en;

    // --- 1. Instantiate Instruction Decoder ---
    instruction_decoder i_decoder (
        .vsi_op      (vsi_op),
        .vd          (vd_addr),
        .vs1         (vs1_addr),
        .vs2         (vs2_addr),
        .uimm        (uimm),
        .is_vxor     (is_vxor),
        .is_vmacc    (is_vmacc),
        .is_vredsum  (is_vredsum),
        .is_vslideup (is_vslideup),
        .is_vrgather (is_vrgather)
    );

    // --- 2. Instantiate Control Unit ---
    control_unit i_control_unit (
        .vsi_clk      (vsi_clk),
        .vsi_rst_n    (vsi_rst_n),
        .vsi_op_valid (vsi_op_valid),
        .vsi_op_ready (vsi_op_ready),
        .vsi_cop_idle (vsi_cop_idle),
        .is_vxor      (is_vxor),
        .is_vmacc     (is_vmacc),
        .is_vredsum   (is_vredsum),
        .is_vslideup  (is_vslideup),
        .is_vrgather  (is_vrgather),
        .exec_en      (exec_en)
    );

    // --- 3. Instantiate Datapath ---
    datapath i_datapath (
        .vsi_clk      (vsi_clk),
        .vsi_rst_n    (vsi_rst_n),
        .exec_en      (exec_en),
        .is_vxor      (is_vxor),
        .is_vmacc     (is_vmacc),
        .is_vredsum   (is_vredsum),
        .is_vslideup  (is_vslideup),
        .is_vrgather  (is_vrgather),
        .vsi_lmul     (vsi_lmul),
        .vsi_sew      (vsi_sew),
        .vd_addr      (vd_addr),
        .vs1_addr     (vs1_addr),
        .vs2_addr     (vs2_addr),
        .uimm         (uimm),
        .vsi_rf_raddr (vsi_rf_raddr),
        .vsi_rf_rdata (vsi_rf_rdata),
        .vsi_rf_waddr (vsi_rf_waddr),
        .vsi_rf_wstrb (vsi_rf_wstrb),
        .vsi_rf_wdata (vsi_rf_wdata)
    );

endmodule