`timescale 1ns / 1ps

module tb_vector_cop;

    // --- Testbench Parameters ---
    localparam CLK_PERIOD = 1.25; // 800 MHz clock period in ns

    // --- Signal Declarations ---
    reg         vsi_clk;
    reg         vsi_rst_n;
    reg  [31:0] vsi_op;
    reg         vsi_lmul;
    reg         vsi_sew;
    reg         vsi_op_valid;
    wire        vsi_op_ready;
    wire        vsi_cop_idle;

    // DUT Interface wires
    wire [7:0][4:0]   vsi_rf_raddr;
    reg  [7:0][127:0] vsi_rf_rdata; // Driven by this testbench's RF model
    wire [3:0][4:0]   vsi_rf_waddr;
    wire [3:0][15:0]  vsi_rf_wstrb;
    wire [3:0][127:0] vsi_rf_wdata;

    // --- Instantiate the Device Under Test (DUT) ---
    vector_cop dut (
        .vsi_clk      (vsi_clk),
        .vsi_rst_n    (vsi_rst_n),
        .vsi_op       (vsi_op),
        .vsi_lmul     (vsi_lmul),
        .vsi_sew      (vsi_sew),
        .vsi_op_valid (vsi_op_valid),
        .vsi_op_ready (vsi_op_ready),
        .vsi_cop_idle (vsi_cop_idle),
        .vsi_rf_raddr (vsi_rf_raddr),
        .vsi_rf_rdata (vsi_rf_rdata),
        .vsi_rf_waddr (vsi_rf_waddr),
        .vsi_rf_wstrb (vsi_rf_wstrb),
        .vsi_rf_wdata (vsi_rf_wdata)
    );

    // --- Clock and Reset Generation ---
    initial begin
        vsi_clk = 0;
        forever #(CLK_PERIOD / 2) vsi_clk = ~vsi_clk;
    end

    initial begin
        vsi_rst_n = 1'b0;
        # (CLK_PERIOD * 5);
        vsi_rst_n = 1'b1;
    end

    // --- Register File (RF) Model ---
    // 32 vector registers, each 128 bits wide 
    reg [127:0] vrf [0:31];

    // Asynchronous (combinational) Read Logic 
    // Supports up to 8 parallel reads
    always @(*) begin
        vsi_rf_rdata[0] = vrf[vsi_rf_raddr[0]];
        vsi_rf_rdata[1] = vrf[vsi_rf_raddr[1]];
        vsi_rf_rdata[2] = vrf[vsi_rf_raddr[2]];
        vsi_rf_rdata[3] = vrf[vsi_rf_raddr[3]];
        vsi_rf_rdata[4] = vrf[vsi_rf_raddr[4]];
        vsi_rf_rdata[5] = vrf[vsi_rf_raddr[5]];
        vsi_rf_rdata[6] = vrf[vsi_rf_raddr[6]];
        vsi_rf_rdata[7] = vrf[vsi_rf_raddr[7]];
    end

    // Synchronous Write Logic 
    // Supports up to 4 parallel writes with byte strobes
    wire [127:0] vrf_wdata_masked [0:3];
    wire [127:0] vrf_prev_data_masked [0:3];
    
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : write_mask_gen
            assign vrf_wdata_masked[i] = {
                vsi_rf_wstrb[i][15] ? vsi_rf_wdata[i][127:120] : 8'h00,
                vsi_rf_wstrb[i][14] ? vsi_rf_wdata[i][119:112] : 8'h00,
                vsi_rf_wstrb[i][13] ? vsi_rf_wdata[i][111:104] : 8'h00,
                vsi_rf_wstrb[i][12] ? vsi_rf_wdata[i][103:96]  : 8'h00,
                vsi_rf_wstrb[i][11] ? vsi_rf_wdata[i][95:88]   : 8'h00,
                vsi_rf_wstrb[i][10] ? vsi_rf_wdata[i][87:80]   : 8'h00,
                vsi_rf_wstrb[i][9]  ? vsi_rf_wdata[i][79:72]   : 8'h00,
                vsi_rf_wstrb[i][8]  ? vsi_rf_wdata[i][71:64]   : 8'h00,
                vsi_rf_wstrb[i][7]  ? vsi_rf_wdata[i][63:56]   : 8'h00,
                vsi_rf_wstrb[i][6]  ? vsi_rf_wdata[i][55:48]   : 8'h00,
                vsi_rf_wstrb[i][5]  ? vsi_rf_wdata[i][47:40]   : 8'h00,
                vsi_rf_wstrb[i][4]  ? vsi_rf_wdata[i][39:32]   : 8'h00,
                vsi_rf_wstrb[i][3]  ? vsi_rf_wdata[i][31:24]   : 8'h00,
                vsi_rf_wstrb[i][2]  ? vsi_rf_wdata[i][23:16]   : 8'h00,
                vsi_rf_wstrb[i][1]  ? vsi_rf_wdata[i][15:8]    : 8'h00,
                vsi_rf_wstrb[i][0]  ? vsi_rf_wdata[i][7:0]     : 8'h00
            };
            
            assign vrf_prev_data_masked[i] = {
                ~vsi_rf_wstrb[i][15] ? vrf[vsi_rf_waddr[i]][127:120] : 8'h00,
                ~vsi_rf_wstrb[i][14] ? vrf[vsi_rf_waddr[i]][119:112] : 8'h00,
                ~vsi_rf_wstrb[i][13] ? vrf[vsi_rf_waddr[i]][111:104] : 8'h00,
                ~vsi_rf_wstrb[i][12] ? vrf[vsi_rf_waddr[i]][103:96]  : 8'h00,
                ~vsi_rf_wstrb[i][11] ? vrf[vsi_rf_waddr[i]][95:88]   : 8'h00,
                ~vsi_rf_wstrb[i][10] ? vrf[vsi_rf_waddr[i]][87:80]   : 8'h00,
                ~vsi_rf_wstrb[i][9]  ? vrf[vsi_rf_waddr[i]][79:72]   : 8'h00,
                ~vsi_rf_wstrb[i][8]  ? vrf[vsi_rf_waddr[i]][71:64]   : 8'h00,
                ~vsi_rf_wstrb[i][7]  ? vrf[vsi_rf_waddr[i]][63:56]   : 8'h00,
                ~vsi_rf_wstrb[i][6]  ? vrf[vsi_rf_waddr[i]][55:48]   : 8'h00,
                ~vsi_rf_wstrb[i][5]  ? vrf[vsi_rf_waddr[i]][47:40]   : 8'h00,
                ~vsi_rf_wstrb[i][4]  ? vrf[vsi_rf_waddr[i]][39:32]   : 8'h00,
                ~vsi_rf_wstrb[i][3]  ? vrf[vsi_rf_waddr[i]][31:24]   : 8'h00,
                ~vsi_rf_wstrb[i][2]  ? vrf[vsi_rf_waddr[i]][23:16]   : 8'h00,
                ~vsi_rf_wstrb[i][1]  ? vrf[vsi_rf_waddr[i]][15:8]    : 8'h00,
                ~vsi_rf_wstrb[i][0]  ? vrf[vsi_rf_waddr[i]][7:0]     : 8'h00
            };
        end
    endgenerate
    
    always @(posedge vsi_clk) begin
        if (vsi_rst_n) begin
            // Port 0
            if (vsi_rf_waddr[0] != 0) 
                vrf[vsi_rf_waddr[0]] <= vrf_wdata_masked[0] | vrf_prev_data_masked[0];
            // Port 1
            if (vsi_rf_waddr[1] != 0) 
                vrf[vsi_rf_waddr[1]] <= vrf_wdata_masked[1] | vrf_prev_data_masked[1];
            // Port 2
            if (vsi_rf_waddr[2] != 0) 
                vrf[vsi_rf_waddr[2]] <= vrf_wdata_masked[2] | vrf_prev_data_masked[2];
            // Port 3
            if (vsi_rf_waddr[3] != 0) 
                vrf[vsi_rf_waddr[3]] <= vrf_wdata_masked[3] | vrf_prev_data_masked[3];
        end
    end

    // --- Driver Task ---
    // This task emulates the driver, applying an instruction and waiting for completion.
    task drive_instruction(input [31:0] op, input lmul, input sew);
        begin
            @(posedge vsi_clk);
            vsi_op = op;
            vsi_lmul = lmul;
            vsi_sew = sew;
            vsi_op_valid = 1'b1;
            $display("INFO: Driving instruction %h (lmul=%b, sew=%b) at time %t", op, lmul, sew, $time);

            // Wait for the DUT to be ready
            wait (vsi_op_ready);
            @(posedge vsi_clk);
            vsi_op_valid = 1'b0;
            
            // Wait for the coprocessor to become idle again
            wait (vsi_cop_idle);
            $display("INFO: Instruction execution finished. Coprocessor is idle at time %t.", $time);
            @(posedge vsi_clk);
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Initialize signals
        vsi_op = 32'h0;
        vsi_lmul = 1'b0;
        vsi_sew = 1'b0;
        vsi_op_valid = 1'b0;

        // Wait for reset to complete
        wait (vsi_rst_n);
        $display("INFO: Reset complete. Starting test sequence at time %t.", $time);

        // --- TEST 1: vxor.vv v4, v2, v1 ---
        // Based on example 
        $display("\n--- TEST 1: vxor.vv v4, v2, v1 ---");
        // Setup: Initialize v1 and v2
        vrf[1] = 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
        vrf[2] = 128'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0;
        $display("  Pre-load: v1 = %h", vrf[1]);
        $display("  Pre-load: v2 = %h", vrf[2]);
        // Instruction: vxor.vv vd=4, vs2=2, vs1=1 --> inst fields from spec 
        drive_instruction({6'b001011, 1'b1, 5'd2, 5'd1, 3'b000, 5'd4, 7'b1010111}, 0, 0);
        $display("  Result:   v4 = %h", vrf[4]);
        $display("  Expected: v4 = %h", 128'h5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A);
        
        // --- TEST 2: vmacc.vv v8, v6, v5 ---
        // Based on example  with sew=1 (int32) 
        $display("\n--- TEST 2: vmacc.vv v8, v6, v5 ---");
        // Setup: Initialize v5, v6, v8
        vrf[5] = {32'd4, 32'd3, 32'd2, 32'd1}; // vs1
        vrf[6] = {32'd10, 32'd10, 32'd10, 32'd10}; // vs2
        vrf[8] = {32'd5, 32'd5, 32'd5, 32'd5}; // vd (initial accumulator)
        $display("  Pre-load: v5 = {4,3,2,1}");
        $display("  Pre-load: v6 = {10,10,10,10}");
        $display("  Pre-load: v8 = {5,5,5,5}");
        // Instruction: vmacc.vv vd=8, vs2=6, vs1=5 --> inst fields from spec 
        drive_instruction({6'b101101, 1'b1, 5'd6, 5'd5, 3'b010, 5'd8, 7'b1010111}, 0, 1);
        $display("  Result:   v8 = {%d, %d, %d, %d}", vrf[8][127:96], vrf[8][95:64], vrf[8][63:32], vrf[8][31:0]);
        $display("  Expected: v8 = {45, 35, 25, 15}");

        $display("\nAll tests completed.");
        $finish;
    end

    // --- Monitor for debugging ---
    initial begin
        $monitor("T=%t, idle=%b, op_valid=%b, op_ready=%b, op=%h, waddr[0]=%d, wdata[0]=%h",
                 $time, vsi_cop_idle, vsi_op_valid, vsi_op_ready, vsi_op, vsi_rf_waddr[0], vsi_rf_wdata[0]);
    end

endmodule