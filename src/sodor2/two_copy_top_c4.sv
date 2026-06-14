`include "src/sodor2/param.vh"
`include "src/sodor2/sodor_2_stage.sv"

// =============================================================================
// Sodor CPU_C4: Core Verification under C4 Platform Timing Contract
// =============================================================================
// C4 contract (cache + conditional interrupt):
//   (1) req   -> diamond{gnt, rdata}
//   (2) addr  -> diamond{gnt, rdata}
//   (3) we    -> diamond{gnt, rdata}
//   (4) wdata -> diamond{gnt, rdata, int}  ONLY WHEN addr in periph_range
//
// C4 is between C2 and C3: wdata affects gnt/int only for peripheral addresses.
// For normal memory addresses, wdata only affects rdata (same as C2).
//
// With PMP software constraint (no secret writes to periph_range):
// Expected: PASS
// Without PMP constraint:
// Expected: FAIL
// =============================================================================

// Peripheral address range (e.g., first entry in data memory)
`define PERIPH_START 0
`define PERIPH_END   1

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
reg sticky_dmem_wdata;        // wdata diff for normal memory
reg sticky_dmem_wdata_periph; // wdata diff for periph_range only (C4)

wire diff_dmem_req;
wire diff_dmem_addr;
wire diff_dmem_we;
wire diff_dmem_wdata;

// C4: detect wdata difference ONLY when store to periph_range
wire in_periph_range = (copy1.io_dmem_req_bits_addr[31:2] >= `PERIPH_START) &
                       (copy1.io_dmem_req_bits_addr[31:2] < `PERIPH_END);
wire diff_dmem_wdata_periph = diff_dmem_wdata & in_periph_range &
                              copy1.io_dmem_req_bits_fcn & copy2.io_dmem_req_bits_fcn;

always @(posedge clk) begin
    if (rst) begin
        sticky_imem_req          <= 0;
        sticky_imem_addr         <= 0;
        sticky_dmem_req          <= 0;
        sticky_dmem_addr         <= 0;
        sticky_dmem_we           <= 0;
        sticky_dmem_wdata        <= 0;
        sticky_dmem_wdata_periph <= 0;
    end else begin
        sticky_imem_req          <= sticky_imem_req          | diff_imem_req;
        sticky_imem_addr         <= sticky_imem_addr         | diff_imem_addr;
        sticky_dmem_req          <= sticky_dmem_req          | diff_dmem_req;
        sticky_dmem_addr         <= sticky_dmem_addr         | diff_dmem_addr;
        sticky_dmem_we           <= sticky_dmem_we           | diff_dmem_we;
        sticky_dmem_wdata        <= sticky_dmem_wdata        | diff_dmem_wdata;
        sticky_dmem_wdata_periph <= sticky_dmem_wdata_periph | diff_dmem_wdata_periph;
    end
end

// C4 contract clause mapping (imem channel):
//   imem_req  -> {imem_gnt, imem_rdata}
//   imem_addr -> {imem_rdata}
wire allow_imem_gnt_diff   = sticky_imem_req | sticky_imem_addr;
wire allow_imem_rdata_diff = sticky_imem_req | sticky_imem_addr;

// C4 contract clause mapping (dmem channel):
//   dmem_req   -> {dmem_gnt, dmem_rdata}
//   dmem_addr  -> {dmem_gnt, dmem_rdata}
//   dmem_we    -> {dmem_gnt, dmem_rdata}
//   dmem_wdata -> {dmem_rdata}                                 (always)
//   dmem_wdata -> {dmem_gnt, dmem_rdata, int}  ONLY IF periph  (C4 conditional!)
wire allow_dmem_gnt_diff   = sticky_dmem_req | sticky_dmem_addr | sticky_dmem_we | sticky_dmem_wdata_periph;
wire allow_dmem_rdata_diff = sticky_dmem_req | sticky_dmem_addr | sticky_dmem_we | sticky_dmem_wdata;
wire allow_int_diff        = sticky_dmem_wdata_periph;  // C4: only periph wdata affects int

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
// Core instantiation: copy1 (shared inputs)
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
    .io_interrupt_meip(int_shared),    // shared interrupt
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// Core instantiation: copy2 (PTCI-controlled inputs)
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
    .io_interrupt_meip(int_copy2),     // PTCI-controlled interrupt
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

// C4: Use standard shadow logic (same as C2)
// With PMP constraint, secret data never reaches periph_range,
// so interrupt signals are always the same → standard pc_sel check is fine

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
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
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
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
            stall_1 = 0;
        end
        else if (!stall_1 && stall_2 && copy1.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
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
