// -----------------------------------------------------------------------------
// Module: control_unit (Revised for confirmed Single-Cycle Execution)
// Function: FSM that enforces a single-cycle execution for all operations.
// -----------------------------------------------------------------------------
module control_unit (
    // Global Interface
    input  wire        vsi_clk,
    input  wire        vsi_rst_n,

    // Operation Interface with Driver
    input  wire        vsi_op_valid,
    output reg         vsi_op_ready,
    output wire        vsi_cop_idle,

    // Decoded Instruction signals from Decoder
    input  wire [31:0] vsi_op,
    input  wire        vsi_lmul,
    input  wire        vsi_sew,
    
    // Control Outputs to Datapath
    output reg         exec_en,
    output reg         write_en,
    output reg [31:0]  op_reg,    // Registered instruction for the datapath
    output reg         lmul_reg,  // Registered lmul
    output reg         sew_reg    // Registered sew
);

    // FSM State Definition
    localparam [1:0] S_IDLE       = 2'b00;
    localparam [1:0] S_EXECUTE    = 2'b01;
    localparam [1:0] S_WRITE_BACK = 2'b10;

    reg [1:0] current_state, next_state;

    // FSM State Register
    always @(posedge vsi_clk or negedge vsi_rst_n) begin
        if (!vsi_rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Instruction Register Logic
    // Latch the instruction details when moving from IDLE to EXECUTE
    always @(posedge vsi_clk or negedge vsi_rst_n) begin
        if (!vsi_rst_n) begin
            op_reg <= 32'b0;
            lmul_reg <= 1'b0;
            sew_reg <= 1'b0;
        end else if (current_state == S_IDLE && vsi_op_valid) begin
            op_reg <= vsi_op;
            lmul_reg <= vsi_lmul;
            sew_reg <= vsi_sew;
        end
    end

    // FSM Next State Logic & Control Signal Outputs
    always @(*) begin
        // Default values for control signals
        next_state   = current_state;
        vsi_op_ready = 1'b0;
        exec_en      = 1'b0;
        write_en     = 1'b0;

        case (current_state)
            S_IDLE: begin
                vsi_op_ready = 1'b1;
                if (vsi_op_valid) begin
                    next_state = S_EXECUTE;
                end
            end
            
            S_EXECUTE: begin
                // ** This state lasts for EXACTLY ONE clock cycle. **
                // Enable the datapath's execution logic.
                exec_en = 1'b1;
                
                // Unconditionally move to WRITE_BACK on the next clock edge,
                // enforcing the single-cycle execution rule for all operations.
                next_state = S_WRITE_BACK;
            end
            
            S_WRITE_BACK: begin
                // Enable the datapath to write the result. This state also
                // lasts for EXACTLY ONE clock cycle.
                write_en = 1'b1;
                
                // After writing, return to IDLE to wait for the next instruction.
                next_state = S_IDLE;
            end
            
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end
    
    assign vsi_cop_idle = (current_state == S_IDLE);

endmodule