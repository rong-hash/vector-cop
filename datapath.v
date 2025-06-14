// -----------------------------------------------------------------------------
// Module: datapath
// Function: Handles operand fetching, execution, and write-back logic.
// -----------------------------------------------------------------------------
module datapath (
    // Global Interface
    input  wire        vsi_clk,
    input  wire        vsi_rst_n,

    // Control signals from Control Unit
    input  wire        exec_en,
    input  wire        is_vxor,
    input  wire        is_vmacc,
    input  wire        is_vredsum,
    input  wire        is_vslideup,
    input  wire        is_vrgather,
    
    // Config and Operand IDs
    input  wire        vsi_lmul,
    input  wire        vsi_sew,
    input  wire [4:0]  vd_addr,
    input  wire [4:0]  vs1_addr,
    input  wire [4:0]  vs2_addr,
    input  wire [4:0]  uimm,

    // Rd/Wr Interface to Register File
    output reg  [7:0][4:0]   vsi_rf_raddr,
    input  wire [7:0][127:0] vsi_rf_rdata,
    output wire [3:0][4:0]   vsi_rf_waddr,
    output wire [3:0][15:0]  vsi_rf_wstrb,
    output wire [3:0][127:0] vsi_rf_wdata
);

    // Internal wires for unpacked operands
    wire [127:0] vs1_data [0:3];
    wire [127:0] vs2_data [0:3];
    wire [127:0] vd_data  [0:3];
    reg  [127:0] result   [0:3];

    // --- 1. Operand Fetching and Address Generation ---
    // Generate read addresses based on operand IDs and lmul
    // For simplicity, we assume lmul=0 (1 reg per operand) and lmul=1 (4 regs per operand)
    // A more complex design would sequence reads if more than 8 are needed.
    always @(*) begin
        vsi_rf_raddr = 8'h0; // Default to 0
        if (vsi_lmul == 0) begin
            // 1 register per operand
            vsi_rf_raddr[0] = vs1_addr;
            vsi_rf_raddr[1] = vs2_addr;
            if (is_vmacc) vsi_rf_raddr[2] = vd_addr; // vmacc also reads vd
            if (is_vredsum) vsi_rf_raddr[2] = vd_addr;
        end else begin
            // 4 registers per operand for vs2 (and vs1/vd for some instructions)
            vsi_rf_raddr[0] = vs2_addr + 0;
            vsi_rf_raddr[1] = vs2_addr + 1;
            vsi_rf_raddr[2] = vs2_addr + 2;
            vsi_rf_raddr[3] = vs2_addr + 3;
            // vredsum uses single registers for vs1 and vd
            if(is_vredsum) begin
                vsi_rf_raddr[4] = vs1_addr;
            end else begin // For vxor, vmacc, etc. when lmul=1
                vsi_rf_raddr[4] = vs1_addr + 0;
                vsi_rf_raddr[5] = vs1_addr + 1;
                // Simplified: assuming enough read ports.
            end
        end
    end

    // Assign read data to internal wires based on address matching
    // This is a simplified routing; a real design would use the FSM to map data
    // from the read cycle to these operand busses.
    assign vs1_data[0] = vsi_rf_rdata[0];
    assign vs2_data[0] = vsi_rf_rdata[1];
    assign vd_data[0]  = vsi_rf_rdata[2];
    // Add logic for lmul=1 to gather the 4 registers for each operand here.

    // --- 2. Execution Logic ---
    // This block is combinational but will be controlled by the FSM's `exec_en`.
    // Synthesis will unroll these loops into parallel hardware.
    always @(*) begin
        // Default assignment to avoid latches
        result[0] = vd_data[0];
        result[1] = vd_data[1];
        result[2] = vd_data[2];
        result[3] = vd_data[3];

        if (exec_en) begin
            if (is_vxor) begin
                // Example for lmul=0
                result[0] = vs2_data[0] ^ vs1_data[0];
            end
            
            else if (is_vmacc) begin
                for (integer i = 0; i < 4; i = i + 1) begin // SEW=1 -> 4 elements
                    if(vsi_sew == 1) begin // int32
                        result[0][i*32 +: 32] = (vs2_data[0][i*32 +: 32] * vs1_data[0][i*32 +: 32]) + vd_data[0][i*32 +: 32];
                    end
                end
                 for (integer i = 0; i < 16; i = i + 1) begin // SEW=0 -> 16 elements
                    if(vsi_sew == 0) begin // int8
                        result[0][i*8 +: 8] = (vs2_data[0][i*8 +: 8] * vs1_data[0][i*8 +: 8]) + vd_data[0][i*8 +: 8];
                    end
                end
            end
            
            else if (is_vredsum) begin
                logic [31:0] sum;
                sum = vs1_data[0][31:0]; // Start with vs1[0]
                if (vsi_sew == 0) begin // int8
                    for (integer i = 0; i < 64; i = i + 1) begin // M=64 (lmul=1, sew=0)
                         // Simplified sum logic for demonstration
                         // This needs proper routing for the 4 vs2 registers.
                         sum = sum + vs2_data[i/16][(i%16)*8 +: 8];
                    end
                    result[0][7:0] = sum[7:0];
                end
            end
            
            // ... Add logic for vslideup and vrgather here
            else if (is_vslideup) begin
                // vslideup.vx vd, vs2, rs1(uimm)
                // vd[i] = vs2[i - uimm] for i >= uimm
                // vd[i] = vs2[0] for i < uimm (This is simplified, should be tail/agnostic)
                if (vsi_sew == 1) begin // int32 elements
                    for (integer i = 0; i < 4; i = i + 1) begin
                        if (i >= uimm) begin
                            result[0][i*32 +: 32] = vs2_data[0][(i-uimm)*32 +: 32];
                        end else begin
                            result[0][i*32 +: 32] = vs2_data[0][0*32 +: 32]; // Simplified tail
                        end
                    end
                end
            end
            
            else if (is_vrgather) begin
                // vrgather.vv vd, vs2, vs1
                // vd[i] = vs2[vs1[i]]
                if (vsi_sew == 1) begin // int32 elements
                    for (integer i = 0; i < 4; i = i + 1) begin
                        logic [4:0] index;
                        index = vs1_data[0][i*32 +: 5]; // Get index from vs1
                        if (index < 4) begin // Bounds check
                           result[0][i*32 +: 32] = vs2_data[0][index*32 +: 32];
                        end else begin
                           result[0][i*32 +: 32] = 32'h0; // Out of bounds is zero
                        end
                    end
                end
            end
            
        end
    end

    // --- 3. Write-Back Logic ---
    assign vsi_rf_waddr[0] = vd_addr;
    assign vsi_rf_waddr[1] = (vsi_lmul) ? vd_addr + 1 : 0; // Simplified
    assign vsi_rf_waddr[2] = (vsi_lmul) ? vd_addr + 2 : 0;
    assign vsi_rf_waddr[3] = (vsi_lmul) ? vd_addr + 3 : 0;

    // For simplicity, we assume the FSM controls the write via a single signal
    // and we always write the full 128 bits.
    assign vsi_rf_wstrb[0] = 16'hFFFF;
    assign vsi_rf_wstrb[1] = (vsi_lmul) ? 16'hFFFF : 0;
    assign vsi_rf_wstrb[2] = (vsi_lmul) ? 16'hFFFF : 0;
    assign vsi_rf_wstrb[3] = (vsi_lmul) ? 16'hFFFF : 0;
    
    assign vsi_rf_wdata[0] = result[0];
    assign vsi_rf_wdata[1] = result[1];
    assign vsi_rf_wdata[2] = result[2];
    assign vsi_rf_wdata[3] = result[3];

endmodule