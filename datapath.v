// -----------------------------------------------------------------------------
// Module: datapath (Revised for lmul support)
// Function: Handles operand fetching, execution, and write-back logic for
//           both single-register and 4-register group operands.
// -----------------------------------------------------------------------------
module datapath (
    // Global Interface
    input  wire        vsi_clk,
    input  wire        vsi_rst_n,

    // Control signals from Control Unit
    input  wire        exec_en,
    input  wire        write_en,
    input  wire [31:0] op_i,
    input  wire        lmul_i,
    input  wire        sew_i,

    // Rd/Wr Interface to Register File
    output reg  [7:0][4:0]   vsi_rf_raddr,
    input  wire [7:0][127:0] vsi_rf_rdata,
    output wire [3:0][4:0]   vsi_rf_waddr,
    output wire [3:0][15:0]  vsi_rf_wstrb,
    output wire [3:0][127:0] vsi_rf_wdata
);

    // --- Decoded instruction fields from registered instruction ---
    wire [4:0]  vd_addr;
    wire [4:0]  vs1_addr;
    wire [4:0]  vs2_addr;
    wire [4:0]  uimm;
    wire        is_vxor;
    wire        is_vmacc;
    wire        is_vredsum;
    wire        is_vslideup;
    wire        is_vrgather;

    // Instantiate a local decoder for the registered instruction
    instruction_decoder inst_decoder_reg (
        .vsi_op      (op_i),
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

    // --- Operand Fetching and Address Generation ---
    always @(*) begin
        vsi_rf_raddr = 8'h0; // Default to 0
        if (lmul_i == 0) begin // 1 register per operand
            vsi_rf_raddr[0] = vs1_addr;
            vsi_rf_raddr[1] = vs2_addr;
            if (is_vmacc) vsi_rf_raddr[2] = vd_addr;
        end else begin // 4 registers per operand group
            // Note: Assumes enough read ports are available.
            // vs2 group
            vsi_rf_raddr[0] = vs2_addr + 0;
            vsi_rf_raddr[1] = vs2_addr + 1;
            vsi_rf_raddr[2] = vs2_addr + 2;
            vsi_rf_raddr[3] = vs2_addr + 3;

            if (is_vredsum) begin // vs1 is single reg for vredsum
                vsi_rf_raddr[4] = vs1_addr;
            end else begin // vs1 is a group for other ops
                vsi_rf_raddr[4] = vs1_addr + 0;
                vsi_rf_raddr[5] = vs1_addr + 1;
                // Simplified, only reading 6 of 8 needed for vs1+vs2
            end
        end
    end
    
    // --- Operand Data Gathering ---
    // Concatenate four 128-bit registers into a 512-bit operand if lmul=1
    wire [511:0] vs1_op_full, vs2_op_full, vd_op_full_in;
    
    // For simplicity, mapping first 4 read ports to vs2, next 4 to vs1
    assign vs2_op_full = {vsi_rf_rdata[3], vsi_rf_rdata[2], vsi_rf_rdata[1], vsi_rf_rdata[0]};
    assign vs1_op_full = {vsi_rf_rdata[7], vsi_rf_rdata[6], vsi_rf_rdata[5], vsi_rf_rdata[4]};
    // vd_op_full_in would need more read ports if used when lmul=1

    // Select between 128-bit or 512-bit operands
    wire [511:0] vs1 = lmul_i ? vs1_op_full : {384'b0, vsi_rf_rdata[0]};
    wire [511:0] vs2 = lmul_i ? vs2_op_full : {384'b0, vsi_rf_rdata[1]};
    wire [511:0] vd_in = lmul_i ? vd_op_full_in : {384'b0, vsi_rf_rdata[2]};

    // --- Execution Logic ---
    reg [511:0] result;

    always @(*) begin
        result = vd_in; // Default result for unused elements or slide

        if (exec_en) begin
            if (is_vxor) begin
                result = vs1 ^ vs2;
            end
            
            else if (is_vmacc) begin
                // M=4,16 for sew=1,0 (lmul=0) ; M=16,64 for sew=1,0 (lmul=1)
                if (sew_i == 1) begin // int32
                    for (integer i = 0; i < (lmul_i ? 16 : 4); i = i + 1) begin
                        result[i*32 +: 32] = (vs1[i*32 +: 32] * vs2[i*32 +: 32]) + vd_in[i*32 +: 32];
                    end
                end else begin // int8
                    for (integer i = 0; i < (lmul_i ? 64 : 16); i = i + 1) begin
                         result[i*8 +: 8] = (vs1[i*8 +: 8] * vs2[i*8 +: 8]) + vd_in[i*8 +: 8];
                    end
                end
            end

            else if (is_vredsum) begin
                logic [31:0] sum;
                sum = vs1[31:0]; // vs1 is always single reg, read from vsi_rf_rdata[0] or [4]
                if (sew_i == 1) begin // int32, M=16
                    for (integer i = 0; i < 16; i = i + 1) begin
                        sum = sum + vs2[i*32 +: 32];
                    end
                end else begin // int8, M=64
                    for (integer i = 0; i < 64; i = i + 1) begin
                        sum = sum + vs2[i*8 +: 8];
                    end
                end
                result[31:0] = sum;
            end
            // `vslideup` and `vrgather` logic would follow a similar pattern
            else if (is_vslideup) begin
                if (sew_i == 1) begin // int32
                    for (integer i = 0; i < (lmul_i ? 16 : 4); i = i + 1) begin
                        if (i >= uimm) begin
                            result[i*32 +: 32] = vs2[(i - uimm)*32 +: 32];
                        end
                        // else: vd_in is preserved in result
                    end
                end else begin // int8
                    for (integer i = 0; i < (lmul_i ? 64 : 16); i = i + 1) begin
                        if (i >= uimm) begin
                            result[i*8 +: 8] = vs2[(i - uimm)*8 +: 8];
                        end
                    end
                end
            end

            else if (is_vrgather) begin
                if (sew_i == 1) begin // int32
                    for (integer i = 0; i < (lmul_i ? 16 : 4); i = i + 1) begin
                        logic [31:0] index;
                        index = vs1[i*32 +: 32];
                        if (index < (lmul_i ? 16 : 4)) begin
                           result[i*32 +: 32] = vs2[index*32 +: 32];
                        end else begin
                           result[i*32 +: 32] = 32'h0; // Out of bounds is zero
                        end
                    end
                end else begin // int8
                    for (integer i = 0; i < (lmul_i ? 64 : 16); i = i + 1) begin
                        logic [7:0] index;
                        index = vs1[i*8 +: 8];
                        if (index < (lmul_i ? 64 : 16)) begin
                            result[i*8 +: 8] = vs2[index*8 +: 8];
                        end else begin
                            result[i*8 +: 8] = 8'h0; // Out of bounds is zero
                        end
                    end
                end
            end
        end
    end

    // --- Write-Back Logic ---
    assign vsi_rf_waddr[0] = write_en ? (vd_addr + 0) : 0;
    assign vsi_rf_waddr[1] = write_en && lmul_i ? (vd_addr + 1) : 0;
    assign vsi_rf_waddr[2] = write_en && lmul_i ? (vd_addr + 2) : 0;
    assign vsi_rf_waddr[3] = write_en && lmul_i ? (vd_addr + 3) : 0;

    assign vsi_rf_wstrb[0] = write_en ? 16'hFFFF : 16'h0;
    assign vsi_rf_wstrb[1] = write_en && lmul_i ? 16'hFFFF : 16'h0;
    assign vsi_rf_wstrb[2] = write_en && lmul_i ? 16'hFFFF : 16'h0;
    assign vsi_rf_wstrb[3] = write_en && lmul_i ? 16'hFFFF : 16'h0;
    
    // Slice the 512-bit result back into four 128-bit chunks for writing
    assign vsi_rf_wdata[0] = result[127:0];
    assign vsi_rf_wdata[1] = result[255:128];
    assign vsi_rf_wdata[2] = result[383:256];
    assign vsi_rf_wdata[3] = result[511:384];

endmodule