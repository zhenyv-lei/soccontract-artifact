`include "src/simpleooo/param.v"

`include "src/simpleooo/decode.v"
`include "src/simpleooo/execute.v"
`include "src/simpleooo/param.v"
`include "src/simpleooo/rf.v"
`include "src/simpleooo/memi.v"

`include "src/simpleooo/cpu_ooo_ext_mem.v"

// =============================================================================
// Experiment: NoFwd_spectre + CT + OBSV=0 + C1 PTCI
// =============================================================================
// C1 contract (ideal memory, address-independent timing):
//   req   → diamond{gnt, rdata}
//   addr  → diamond{rdata}         ← NOT gnt! (address does NOT affect timing)
//   wdata → diamond{rdata}
//
// Key difference from C2: addr does NOT affect gnt.
// Expected: PASS (C1 guarantees no address-dependent timing)
// =============================================================================

module top(
    input clk,
    input rst
);

reg init;
always @(posedge clk) begin
    if (rst) init <= 1;
    else     init <= 0;
end

// =========================================================================
// Shared memd (one copy, same data for both CPUs by default)
// =========================================================================
reg [`REG_LEN-1:0] memd [`MEMD_SIZE-1:0];

integer mi;
always @(posedge clk) begin
    if (rst) begin
        for (mi = 0; mi < `MEMD_SIZE; mi = mi + 1)
            memd[mi] <= 0;
    end
end

// Shared rdata
wire [`REG_LEN-1:0] rdata_shared = memd[copy1.dmem_req_addr];

// Unconstrained alternatives
wire [`REG_LEN-1:0] rdata_unc;
wire                 delay_unc;

// =========================================================================
// PTCI: C1 Contract - Sticky-one logic
// =========================================================================
wire diff_req  = copy1.dmem_req_valid ^ copy2.dmem_req_valid;
wire diff_addr = (copy1.dmem_req_valid & copy2.dmem_req_valid) &
                 (copy1.dmem_req_addr != copy2.dmem_req_addr);

reg sticky_req, sticky_addr;
always @(posedge clk) begin
    if (rst) begin
        sticky_req  <= 0;
        sticky_addr <= 0;
    end else begin
        sticky_req  <= sticky_req  | diff_req;
        sticky_addr <= sticky_addr | diff_addr;
    end
end

// C1 contract mapping:
//   req  → {gnt, rdata}:  sticky_req affects both
//   addr → {rdata} ONLY:  sticky_addr affects rdata but NOT gnt
wire allow_gnt_diff   = sticky_req;                    // addr NOT included!
wire allow_rdata_diff = sticky_req | sticky_addr;      // addr included here

// =========================================================================
// PTCI MUX
// =========================================================================
wire [`REG_LEN-1:0] rdata_1   = rdata_shared;
wire                 delayed_1 = 1'b0;

wire [`REG_LEN-1:0] rdata_2   = allow_rdata_diff ? rdata_unc : rdata_shared;
wire                 delayed_2 = allow_gnt_diff   ? delay_unc : 1'b0;

// =========================================================================
// Core instantiation
// =========================================================================
reg [`ROB_SIZE_LOG-1:0] ROB_tail_1, ROB_tail_2;
reg stall_1, stall_2, finish_1, finish_2, commit_deviation, addr_deviation, invalid_program;
reg C_mem_valid_r, C_mem_rdwt_r, C_is_br_r, C_taken_r;
reg [`MEMD_SIZE_LOG-1:0] C_mem_addr_r;

cpu_ooo_ext_mem copy1(
    .clk(stall_1 ? 0 : clk),
    .rst(rst),
    .dmem_resp_data(rdata_1),
    .dmem_resp_delayed(delayed_1),
    .dmem_wr_valid(),
    .dmem_wr_addr(),
    .dmem_wr_data()
);

cpu_ooo_ext_mem copy2(
    .clk(stall_2 ? 0 : clk),
    .rst(rst),
    .dmem_resp_data(rdata_2),
    .dmem_resp_delayed(delayed_2),
    .dmem_wr_valid(),
    .dmem_wr_addr(),
    .dmem_wr_data()
);

// =========================================================================
// Shadow Logic (same as two_copy_top_ct.v)
// =========================================================================
always @(posedge clk) begin
    if (rst) begin
        stall_1 <= 0;
        stall_2 <= 0;
        finish_1 <= 0;
        finish_2 <= 0;
        commit_deviation <= 0;
        invalid_program <= 0;
    end
    else begin
        `ifndef IMM_STALL
        if (!stall_1 && !stall_2 && copy1.C_valid && copy2.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && copy2.C_mem_valid && copy2.C_mem_rdwt && copy1.C_mem_addr != copy2.C_mem_addr)
                invalid_program <= 1;
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken)
                invalid_program <= 1;
        end
        else if (!stall_1 && !stall_2 && copy1.C_valid && !copy2.C_valid) begin
            stall_1 <= 1;
            commit_deviation <= 1;
            if (!(commit_deviation || ((`OBSV==`OBSV_EVERY_ADDR) ? addr_deviation : 0))) begin
                ROB_tail_1 <= copy1.ROB_tail;
                ROB_tail_2 <= copy2.ROB_tail;
            end
            C_mem_valid_r <= copy1.C_mem_valid;
            C_mem_rdwt_r <= copy1.C_mem_rdwt;
            C_mem_addr_r <= copy1.C_mem_addr;
            C_is_br_r <= copy1.C_is_br;
            C_taken_r <= copy1.C_taken;
        end
        else if (!stall_1 && !stall_2 && !copy1.C_valid && copy2.C_valid) begin
            stall_2 <= 1;
            commit_deviation <= 1;
            if (!commit_deviation) begin
                ROB_tail_1 <= copy1.ROB_tail;
                ROB_tail_2 <= copy2.ROB_tail;
            end
            C_mem_valid_r <= copy2.C_mem_valid;
            C_mem_rdwt_r <= copy2.C_mem_rdwt;
            C_mem_addr_r <= copy2.C_mem_addr;
            C_is_br_r <= copy2.C_is_br;
            C_taken_r <= copy2.C_taken;
        end
        else if (stall_1 && !stall_2 && copy2.C_valid) begin
            if (C_mem_valid_r && C_mem_rdwt_r && copy2.C_mem_valid && copy2.C_mem_rdwt && C_mem_addr_r != copy2.C_mem_addr)
                invalid_program <= 1;
            if (C_is_br_r && copy2.C_is_br && C_taken_r != copy2.C_taken)
                invalid_program <= 1;
            stall_1 <= 0;
        end
        else if (!stall_1 && stall_2 && copy1.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && C_mem_valid_r && C_mem_rdwt_r && copy1.C_mem_addr != C_mem_addr_r)
                invalid_program <= 1;
            if (copy1.C_is_br && C_is_br_r && copy1.C_taken != C_taken_r)
                invalid_program <= 1;
            stall_2 <= 0;
        end
        `else
        if (!stall_1 && !stall_2 && copy1.C_valid && copy2.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && copy2.C_mem_valid && copy2.C_mem_rdwt && copy1.C_mem_addr != copy2.C_mem_addr)
                invalid_program = 1;
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken)
                invalid_program = 1;
        end
        else if (!stall_1 && !stall_2 && copy1.C_valid && !copy2.C_valid) begin
            stall_1 = 1;
            commit_deviation <= 1;
            if (!(commit_deviation || ((`OBSV==`OBSV_EVERY_ADDR) ? addr_deviation : 0))) begin
                ROB_tail_1 <= copy1.ROB_tail;
                ROB_tail_2 <= copy2.ROB_tail;
            end
        end
        else if (!stall_1 && !stall_2 && !copy1.C_valid && copy2.C_valid) begin
            stall_2 = 1;
            commit_deviation <= 1;
            if (!commit_deviation) begin
                ROB_tail_1 <= copy1.ROB_tail;
                ROB_tail_2 <= copy2.ROB_tail;
            end
        end
        else if (stall_1 && !stall_2 && copy2.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && copy2.C_mem_valid && copy2.C_mem_rdwt && copy1.C_mem_addr != copy2.C_mem_addr)
                invalid_program = 1;
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken)
                invalid_program = 1;
            stall_1 = 0;
        end
        else if (!stall_1 && stall_2 && copy1.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && copy2.C_mem_valid && copy2.C_mem_rdwt && copy1.C_mem_addr != copy2.C_mem_addr)
                invalid_program = 1;
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken)
                invalid_program = 1;
            stall_2 = 0;
        end
        `endif

        if ((`OBSV==`OBSV_EVERY_ADDR) && !commit_deviation && copy1.ld_addr!=copy2.ld_addr) begin
            addr_deviation <= 1;
            ROB_tail_1 <= copy1.ROB_tail;
            ROB_tail_2 <= copy2.ROB_tail;
        end

        if ((commit_deviation || ((`OBSV==`OBSV_EVERY_ADDR) ? addr_deviation : 0)) && ((copy1.C_valid && copy1.ROB_head == ROB_tail_1-1 ) || (copy1.C_valid && copy1.C_squash)))
            finish_1 <= 1;
        if ((commit_deviation || ((`OBSV==`OBSV_EVERY_ADDR) ? addr_deviation : 0)) && ((copy2.C_valid && copy2.ROB_head == ROB_tail_1-1 ) || (copy2.C_valid && copy2.C_squash)))
            finish_2 <= 1;
    end
end

endmodule
