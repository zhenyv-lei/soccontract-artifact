`include "src/sodor2/param.vh"
`include "src/sodor2/sodor_2_stage.sv"

// =============================================================================
// Sodor-S CPU_C3: Secure Sodor under C3 Platform Timing Contract
// =============================================================================
// C3 contract (cache + interrupt platform):
//   (1) req   -> diamond{gnt, rdata}
//   (2) addr  -> diamond{gnt, rdata}
//   (3) we    -> diamond{gnt, rdata}
//   (4) wdata -> diamond{gnt, rdata, int}
//
// Defense: Mask interrupts during store execution.
// When CPU is performing a store, interrupt signal is gated to 0.
// This prevents wdata from affecting timing through the interrupt path.
//
// Expected: PASS (interrupt masking blocks the wdata→int→timing leak)
// =============================================================================

module top(
    input clk,
    input rst
);

// =========================================================================
// Unconstrained platform inputs
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

// shared interrupt
wire         int_shared;

// independent interrupt (if diverged)
wire         int_unc;

// =========================================================================
// PTCI: C3 Contract - Sticky-one logic
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

// C3 contract clause mapping (imem channel):
//   imem_req  -> {imem_gnt, imem_rdata}
//   imem_addr -> {imem_rdata}
wire allow_imem_gnt_diff   = sticky_imem_req | sticky_imem_addr;
wire allow_imem_rdata_diff = sticky_imem_req | sticky_imem_addr;

// C3 contract clause mapping (dmem channel):
//   dmem_req   -> {dmem_gnt, dmem_rdata}
//   dmem_addr  -> {dmem_gnt, dmem_rdata}
//   dmem_we    -> {dmem_gnt, dmem_rdata}
//   dmem_wdata -> {dmem_gnt, dmem_rdata, int}   ← C3: wdata affects gnt AND int!
wire allow_dmem_gnt_diff   = sticky_dmem_req | sticky_dmem_addr | sticky_dmem_we | sticky_dmem_wdata;
wire allow_dmem_rdata_diff = sticky_dmem_req | sticky_dmem_addr | sticky_dmem_we | sticky_dmem_wdata;
wire allow_int_diff        = sticky_dmem_wdata;  // C3: wdata can affect interrupt

// Platform inputs for copy2, controlled by PTCI
wire        io_imem_resp_valid_copy2     = allow_imem_gnt_diff   ? io_imem_resp_valid_unc
                                                               : io_imem_resp_valid_shared;
wire [31:0] io_imem_resp_bits_data_copy2 = allow_imem_rdata_diff ? io_imem_resp_bits_data_unc
                                                               : io_imem_resp_bits_data_shared;
wire        io_dmem_resp_valid_copy2     = allow_dmem_gnt_diff   ? io_dmem_resp_valid_unc
                                                               : io_dmem_resp_valid_shared;
wire [31:0] io_dmem_resp_bits_data_copy2 = allow_dmem_rdata_diff ? io_dmem_resp_bits_data_unc
                                                               : io_dmem_resp_bits_data_shared;

// Interrupt for copy2: PTCI-controlled
wire        int_copy2 = allow_int_diff ? int_unc : int_shared;

// =========================================================================
// Sodor-S Defense: Sticky interrupt mask after store execution
// =========================================================================
// Once a store has been executed, permanently mask interrupts.
// Rationale: after a store, the interrupt controller's state may depend on
// secret data (wdata). Any future interrupt could leak timing information.
// This is conservative but guarantees no wdata→int→timing leak.
//
// Before any store: both copies see the same interrupt → safe
// After a store: interrupts permanently masked → no timing leak → safe

wire store_active_1 = copy1.io_dmem_req_valid & copy1.io_dmem_req_bits_fcn;
wire store_active_2 = copy2.io_dmem_req_valid & copy2.io_dmem_req_bits_fcn;

reg int_mask_1, int_mask_2;
always @(posedge clk) begin
    if (rst) begin
        int_mask_1 <= 0;
        int_mask_2 <= 0;
    end else begin
        if (store_active_1) int_mask_1 <= 1;
        if (store_active_2) int_mask_2 <= 1;
    end
end

// Gate interrupt: permanently masked after first store
wire int_gated_1 = int_shared & ~int_mask_1;
wire int_gated_2 = int_copy2  & ~int_mask_2;

// =========================================================================
// Core instantiation: copy1 (shared inputs, gated interrupt)
// =========================================================================
Core copy1(
    .clock(stall_1 ? 1'b0 : clk),
    .reset(rst),
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    .io_dmem_resp_valid(io_dmem_resp_valid_shared),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_shared),
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(int_gated_1),   // gated interrupt (masked during store)
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// Core instantiation: copy2 (PTCI-controlled inputs, gated interrupt)
// =========================================================================
Core copy2(
    .clock(stall_2 ? 1'b0 : clk),
    .reset(rst),
    .io_imem_resp_valid(io_imem_resp_valid_copy2),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_copy2),
    .io_dmem_resp_valid(io_dmem_resp_valid_copy2),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_copy2),
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(int_gated_2),   // gated interrupt (masked during store)
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
// Only detect wdata difference during STORE (fcn=1), not during LOAD
assign diff_dmem_wdata = (copy1.io_dmem_req_bits_fcn & copy2.io_dmem_req_bits_fcn) &
                         |(copy1.io_dmem_req_bits_data ^ copy2.io_dmem_req_bits_data);

// =========================================================================
// Shadow Logic (C3 version: distinguish program vs interrupt PC changes)
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

// C3: Distinguish program-initiated PC changes from interrupt-initiated ones
// io_ctl_pc_sel == 3'h4 means exception/interrupt handler (platform-driven)
// Only filter program-driven PC divergences as invalid_program
wire pc_sel_diff = (copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel);
wire either_is_interrupt = (copy1.c.io_ctl_pc_sel == 3'h4) || (copy2.c.io_ctl_pc_sel == 3'h4);
wire pc_sel_diff_by_program = pc_sel_diff && !either_is_interrupt;

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
        if (!stall_1 && !stall_2 && copy1.d.exe_reg_valid && copy2.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || pc_sel_diff_by_program)
                invalid_program = 1;
        end
        else if (!stall_1 && !stall_2 && copy1.d.exe_reg_valid && !copy2.d.exe_reg_valid) begin
            stall_1 = 1;
            commit_deviation <= 1;
        end
        else if (!stall_1 && !stall_2 && !copy1.d.exe_reg_valid && copy2.d.exe_reg_valid) begin
            stall_2 = 1;
            commit_deviation <= 1;
        end
        else if (stall_1 && !stall_2 && copy2.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || pc_sel_diff_by_program)
                invalid_program = 1;
            stall_1 = 0;
        end
        else if (!stall_1 && stall_2 && copy1.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || pc_sel_diff_by_program)
                invalid_program = 1;
            stall_2 = 0;
        end

        if (!commit_deviation && mem_addr_1 != mem_addr_2) begin
            addr_deviation <= 1;
        end

        if ((commit_deviation || addr_deviation) && copy1.d.exe_reg_valid)
            finish_1 <= 1;
        if ((commit_deviation || addr_deviation) && copy2.d.exe_reg_valid)
            finish_2 <= 1;
    end
end

endmodule
