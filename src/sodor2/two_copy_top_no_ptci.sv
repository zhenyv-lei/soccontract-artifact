`include "src/sodor2/param.vh"
`include "src/sodor2/sodor_2_stage.sv"

// =============================================================================
// Step 1: Core Verification with NO Platform Timing Contract (Baseline)
// =============================================================================
// No platform contract: dmem responses are fully independent per copy.
// imem responses are shared (both copies execute the same program).
//
// Expected result: FAIL
// Reason: model checker can inject different dmem timing for the two copies,
//         causing commit time divergence even for CT-compliant programs.
// This demonstrates that platform timing constraints are necessary.
// =============================================================================

module top(
    input clk,
    input rst
);

// =========================================================================
// Shared imem inputs (same program for both copies)
// =========================================================================
wire         io_imem_resp_valid_shared;
wire  [31:0] io_imem_resp_bits_data_shared;

// =========================================================================
// Independent dmem inputs (fully unconstrained, no platform contract)
// =========================================================================

// copy1 dmem responses
wire         io_dmem_resp_valid_1;
wire  [31:0] io_dmem_resp_bits_data_1;

// copy2 dmem responses (independent from copy1)
wire         io_dmem_resp_valid_2;
wire  [31:0] io_dmem_resp_bits_data_2;

// =========================================================================
// Core instantiation: copy1
// =========================================================================
Core copy1(
    .clock(stall_1 ? 1'b0 : clk),
    .reset(rst),
    // imem interface -- shared (same program)
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    // dmem interface -- independent (unconstrained)
    .io_dmem_resp_valid(io_dmem_resp_valid_1),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_1),
    // interrupts -- tied to 0
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(1'b0),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// Core instantiation: copy2
// =========================================================================
Core copy2(
    .clock(stall_2 ? 1'b0 : clk),
    .reset(rst),
    // imem interface -- shared (same program)
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    // dmem interface -- independent (unconstrained, different from copy1)
    .io_dmem_resp_valid(io_dmem_resp_valid_2),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_2),
    // interrupts -- tied to 0
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(1'b0),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// Shadow Logic: commit deviation / address deviation detection
// (Same as two_copy_top_c1.sv, no PTCI)
// =========================================================================
reg stall_1, stall_2, finish_1, finish_2, commit_deviation, addr_deviation, invalid_program;

wire mem_valid_1 = copy1.io_dmem_req_valid;
wire mem_valid_2 = copy2.io_dmem_req_valid;
wire [31:0] mem_addr_1 = copy1.io_dmem_req_valid ? copy1.io_dmem_req_bits_addr : 32'b0;
wire [31:0] mem_addr_2 = copy2.io_dmem_req_valid ? copy2.io_dmem_req_bits_addr : 32'b0;

wire [31:0] if_pc_next_1 = copy1.d._if_pc_next_T   ? copy1.d.if_pc_plus4   :
                            copy1.d._if_pc_next_T_1 ? copy1.d.exe_br_target :
                                                      copy1.d._if_pc_next_T_7;
wire [31:0] if_pc_next_2 = copy2.d._if_pc_next_T   ? copy2.d.if_pc_plus4   :
                            copy2.d._if_pc_next_T_1 ? copy2.d.exe_br_target :
                                                      copy2.d._if_pc_next_T_7;

always @(posedge clk) begin
    if (rst) begin
        stall_1          <= 0;
        stall_2          <= 0;
        finish_1         <= 0;
        finish_2         <= 0;
        commit_deviation <= 0;
        addr_deviation   <= 0;
        invalid_program  <= 0;
    end
    else begin
        // Both copies commit simultaneously
        if (!stall_1 && !stall_2 && copy1.d.exe_reg_valid && copy2.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
        end
        // copy1 commits, copy2 does not -> stall copy1
        else if (!stall_1 && !stall_2 && copy1.d.exe_reg_valid && !copy2.d.exe_reg_valid) begin
            stall_1 = 1;
            commit_deviation <= 1;
        end
        // copy2 commits, copy1 does not -> stall copy2
        else if (!stall_1 && !stall_2 && !copy1.d.exe_reg_valid && copy2.d.exe_reg_valid) begin
            stall_2 = 1;
            commit_deviation <= 1;
        end
        // copy1 was stalled, copy2 catches up
        else if (stall_1 && !stall_2 && copy2.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
            stall_1 = 0;
        end
        // copy2 was stalled, copy1 catches up
        else if (!stall_1 && stall_2 && copy1.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
            stall_2 = 0;
        end

        // Detect address deviation (only when no commit deviation yet)
        if (!commit_deviation && mem_addr_1 != mem_addr_2) begin
            addr_deviation <= 1;
        end

        // Drain inflight instructions after deviation detected
        if ((commit_deviation || addr_deviation) && copy1.d.exe_reg_valid)
            finish_1 <= 1;
        if ((commit_deviation || addr_deviation) && copy2.d.exe_reg_valid)
            finish_2 <= 1;
    end
end

endmodule
