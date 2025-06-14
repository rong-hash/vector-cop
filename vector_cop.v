// -----------------------------------------------------------------------------
// Module: vector_cop (Top Level)
// Competition: 2025 Circuit Design Competition
// Function: A RISC-V Vector Coprocessor
// -----------------------------------------------------------------------------
module vector_cop #(
    parameter VSI_RD_NUM = 8,
    parameter VSI_WR_NUM = 4
) (
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
    output wire [VSI_RD_NUM-1:0][4:0]   vsi_rf_raddr,
    input  wire [VSI_RD_NUM-1:0][127:0] vsi_rf_rdata,
    output wire [VSI_WR_NUM-1:0][4:0]   vsi_rf_waddr,
    output wire [VSI_WR_NUM-1:0][15:0]  vsi_rf_wstrb,
    output wire [VSI_WR_NUM-1:0][127:0] vsi_rf_wdata
);

    // --- Internal Wires for Inter-module Communication ---

    // Control Unit outputs to Datapath
    wire        exec_en;
    wire        write_en;
    wire [31:0] op_reg;
    wire        lmul_reg;
    wire        sew_reg;

    // --- 1. Instantiate Control Unit ---
    control_unit i_control_unit (
        .vsi_clk      (vsi_clk),
        .vsi_rst_n    (vsi_rst_n),
        .vsi_op_valid (vsi_op_valid),
        .vsi_op_ready (vsi_op_ready),
        .vsi_cop_idle (vsi_cop_idle),
        .vsi_op       (vsi_op),
        .vsi_lmul     (vsi_lmul),
        .vsi_sew      (vsi_sew),
        .exec_en      (exec_en),
        .write_en     (write_en),
        .op_reg       (op_reg),
        .lmul_reg     (lmul_reg),
        .sew_reg      (sew_reg)
    );

    // --- 2. Instantiate Datapath ---
    datapath i_datapath (
        .vsi_clk      (vsi_clk),
        .vsi_rst_n    (vsi_rst_n),
        .exec_en      (exec_en),
        .write_en     (write_en),
        .op_i         (op_reg),
        .lmul_i       (lmul_reg),
        .sew_i        (sew_reg),
        .vsi_rf_raddr (vsi_rf_raddr),
        .vsi_rf_rdata (vsi_rf_rdata),
        .vsi_rf_waddr (vsi_rf_waddr),
        .vsi_rf_wstrb (vsi_rf_wstrb),
        .vsi_rf_wdata (vsi_rf_wdata)
    );

endmodule