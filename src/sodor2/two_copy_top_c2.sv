`include "src/sodor2/param.vh"
`include "src/sodor2/sodor_2_stage.sv"

// =============================================================================
// Phase 1a: Core Verification under C2 Platform Timing Contract
// =============================================================================
// C2 contract (ideal memory, address-independent timing):
//   (1) req   -> diamond{gnt, rdata}
//   (2) addr  -> diamond{gnt, rdata}
//   (3) we    -> diamond{gnt, rdata}
//   (4) wdata -> diamond{rdata}
//
// Key property: timing (gnt/resp_valid) depends ONLY on req.
//               data (rdata) depends on req, addr, we, wdata.
//
// PTCI for miter: both copies receive identical platform inputs UNLESS a
// contract-allowed output has ever differed, in which case the corresponding
// input becomes unconstrained (can differ between copies).
// =============================================================================

module top(
    input clk,
    input rst
);

// =========================================================================
// Unconstrained platform inputs (provided by formal tool)
// =========================================================================

// shared gnt
wire         io_imem_resp_valid_shared;
wire         io_dmem_resp_valid_shared;

// shared rdata
wire  [31:0] io_imem_resp_bits_data_shared;
wire  [31:0] io_dmem_resp_bits_data_shared;

// independent gnt (if diverged)
wire        io_imem_resp_valid_unc;
wire        io_dmem_resp_valid_unc;

// independent rdata (if diverged)
wire [31:0] io_imem_resp_bits_data_unc;
wire [31:0] io_dmem_resp_bits_data_unc;



// =========================================================================
// PTCI: C2 Contract - Sticky-one logic for diamond operator
// =========================================================================

// --- imem channel (read-only: req, addr) ---
reg sticky_imem_req;
reg sticky_imem_addr;

wire diff_imem_req;
wire diff_imem_addr;

// --- dmem channel (read/write: req, addr, we, wdata) ---
reg sticky_dmem_req;
reg sticky_dmem_addr;
reg sticky_dmem_we;
reg sticky_dmem_wdata;

wire diff_dmem_req;
wire diff_dmem_addr;
wire diff_dmem_we;
wire diff_dmem_wdata;

always @(posedge clk) begin
    if (rst) begin
        sticky_imem_req   <= 0;
        sticky_imem_addr  <= 0;
        sticky_dmem_req   <= 0;
        sticky_dmem_addr  <= 0;
        sticky_dmem_we    <= 0;
        sticky_dmem_wdata <= 0;
    end else begin
        sticky_imem_req   <= sticky_imem_req   | diff_imem_req;
        sticky_imem_addr  <= sticky_imem_addr  | diff_imem_addr;
        sticky_dmem_req   <= sticky_dmem_req   | diff_dmem_req;
        sticky_dmem_addr  <= sticky_dmem_addr  | diff_dmem_addr;
        sticky_dmem_we    <= sticky_dmem_we    | diff_dmem_we;
        sticky_dmem_wdata <= sticky_dmem_wdata | diff_dmem_wdata;
    end
end

// C2 contract clause mapping (imem channel):
//   imem_req  -> {imem_gnt, imem_rdata}
//   imem_addr -> {imem_rdata}
wire allow_imem_gnt_diff   = sticky_imem_req | sticky_imem_addr;
wire allow_imem_rdata_diff = sticky_imem_req | sticky_imem_addr;

// C2 contract clause mapping (dmem channel):
//   dmem_req   -> {dmem_gnt, dmem_rdata}
//   dmem_addr  -> {dmem_rdata}
//   dmem_we    -> {dmem_rdata}
//   dmem_wdata -> {dmem_rdata}
wire allow_dmem_gnt_diff   = sticky_dmem_req | sticky_dmem_addr | sticky_dmem_we;
wire allow_dmem_rdata_diff = sticky_dmem_req | sticky_dmem_addr | sticky_dmem_we | sticky_dmem_wdata;

// Platform inputs for copy2, controlled by PTCI
wire        io_imem_resp_valid_copy2     = allow_imem_gnt_diff   ? io_imem_resp_valid_unc
                                                               : io_imem_resp_valid_shared;
wire [31:0] io_imem_resp_bits_data_copy2 = allow_imem_rdata_diff ? io_imem_resp_bits_data_unc
                                                               : io_imem_resp_bits_data_shared;
wire        io_dmem_resp_valid_copy2     = allow_dmem_gnt_diff   ? io_dmem_resp_valid_unc
                                                               : io_dmem_resp_valid_shared;
wire [31:0] io_dmem_resp_bits_data_copy2 = allow_dmem_rdata_diff ? io_dmem_resp_bits_data_unc
                                                               : io_dmem_resp_bits_data_shared;

// =========================================================================
// Core instantiation: copy1
// =========================================================================
Core copy1(
    .clock(stall_1 ? 1'b0 : clk),
    .reset(rst),
    // imem interface -- shared (same program)
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    // dmem interface -- shared platform inputs
    .io_dmem_resp_valid(io_dmem_resp_valid_shared),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_shared),
    // interrupts -- tied to 0 (no interrupts in C2)
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
    // imem interface -- PTCI-controlled
    .io_imem_resp_valid(io_imem_resp_valid_copy2),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_copy2),
    // dmem interface -- PTCI-controlled
    .io_dmem_resp_valid(io_dmem_resp_valid_copy2),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_copy2),
    // interrupts -- tied to 0
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(1'b0),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// PTCI: XOR of CPU outputs (imem channel)
// =========================================================================
assign diff_imem_req   = copy1.io_imem_req_valid      ^ copy2.io_imem_req_valid;
assign diff_imem_addr  = |(copy1.io_imem_req_bits_addr ^ copy2.io_imem_req_bits_addr);

// =========================================================================
// PTCI: XOR of CPU outputs (dmem channel)
// =========================================================================
assign diff_dmem_req   = copy1.io_dmem_req_valid      ^ copy2.io_dmem_req_valid;
assign diff_dmem_addr  = |(copy1.io_dmem_req_bits_addr ^ copy2.io_dmem_req_bits_addr);
assign diff_dmem_we    = copy1.io_dmem_req_bits_fcn   ^ copy2.io_dmem_req_bits_fcn;
assign diff_dmem_wdata = |(copy1.io_dmem_req_bits_data ^ copy2.io_dmem_req_bits_data);

// =========================================================================
// Shadow Logic: commit deviation / address deviation detection
// (Adapted from two_copy_top_ct.sv, using Core instead of SodorInternalTile)
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
