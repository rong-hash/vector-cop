// -----------------------------------------------------------------------------
// Module: control_unit
// Function: FSM to control the instruction execution flow.
// -----------------------------------------------------------------------------
module control_unit (
    // Global Interface
    input  wire        vsi_clk,
    input  wire        vsi_rst_n,

    // Operation Interface with Driver
    input  wire        vsi_op_valid,
    output reg         vsi_op_ready,
    output wire        vsi_cop_idle,

    // Decoded Instruction signals
    input  wire        is_vxor,
    input  wire        is_vmacc,
    input  wire        is_vredsum,
    input  wire        is_vslideup,
    input  wire        is_vrgather,

    // Datapath Control Outputs
    output reg         exec_en
    // Add other control signals like fetch_en, wb_en as needed
);

    // FSM State Definition
    localparam [1:0] IDLE    = 2'b00;
    localparam [1:0] EXECUTE = 2'b01;
    localparam [1:0] WB      = 2'b10;

    reg [1:0] current_state, next_state;

    // FSM State Register
    always @(posedge vsi_clk or negedge vsi_rst_n) begin
        if (!vsi_rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Next State Logic & Outputs
    always @(*) begin
        // Default values
        next_state   = current_state;
        vsi_op_ready = 1'b0;
        exec_en      = 1'b0;

        case (current_state)
            IDLE: begin
                vsi_op_ready = 1'b1;
                if (vsi_op_valid) begin
                    next_state = EXECUTE; // Simple transition, assumes fetch happens in 1 cycle
                end
            end
            
            EXECUTE: begin
                // For simple instructions, this state takes one cycle.
                // For complex/multi-cycle instructions like vredsum, this state
                // would persist for multiple cycles using a counter.
                exec_en = 1'b1;
                next_state = WB;
            end
            
            WB: begin
                // The datapath is already presenting the data to the write ports.
                // The write to RF happens on the next clock edge.
                // This state ensures we stay off the bus for one cycle while the write completes.
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    assign vsi_cop_idle = (current_state == IDLE);

endmodule