`ifndef VRGATHER_UNIT_V
`define VRGATHER_UNIT_V
module vrgather_unit #(parameter VLEN_BITS = 128)(
    input  wire                      sew,
    input  wire [VLEN_BITS*4-1:0]    vs2_bus,
    input  wire [VLEN_BITS*4-1:0]    vs1_bus,
    output reg  [VLEN_BITS*4-1:0]    vd_bus
);
    integer i;
    integer idx;

    always @* begin
        vd_bus = 0;
        if(sew == 1'b0) begin           // int8, M=64
            for(i=0;i<64;i=i+1) begin
                idx = vs1_bus[i*8 +: 8];
                if(idx < 64) vd_bus[i*8 +: 8] = vs2_bus[idx*8 +: 8];
            end
        end else begin                  // int32, M=16
            for(i=0;i<16;i=i+1) begin
                idx = vs1_bus[i*32 +: 32];
                if(idx < 16) vd_bus[i*32 +: 32] = vs2_bus[idx*32 +: 32];
            end
        end
    end
endmodule
`endif