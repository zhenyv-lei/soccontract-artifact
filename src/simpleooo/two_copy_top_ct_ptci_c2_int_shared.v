`include "src/simpleooo/param.v"

`include "src/simpleooo/decode.v"
`include "src/simpleooo/execute.v"
`include "src/simpleooo/param.v"
`include "src/simpleooo/rf.v"
`include "src/simpleooo/memi.v"

`include "src/simpleooo/cpu_ooo_ext_mem.v"

// =============================================================================
// Experiment 3: NoFwd_spectre + CT + OBSV_COMMITTED_ADDR + PTCI (C2)
// =============================================================================
// PTCI models C2 platform timing contract:
//   - If two copies' dmem addresses ever differ → allow different load timing
//   - This models cache hit/miss: different addresses → different latency
// Expected result: FAIL (speculative loads with secret-dependent addresses
//   cause PTCI to allow timing differences → commit_deviation)
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
// Independent memd for each copy (different secrets)
// =========================================================================
reg [`REG_LEN-1:0] memd_1 [`MEMD_SIZE-1:0];
reg [`REG_LEN-1:0] memd_2 [`MEMD_SIZE-1:0];

// Initial values are abstracted by TCL script
// Store writes update memd at commit time
integer mi;
always @(posedge clk) begin
    if (rst) begin
        for (mi=0; mi<`MEMD_SIZE; mi=mi+1) begin
            memd_1[mi] <= 0;
            memd_2[mi] <= 0;
        end
    end else begin
        if (wr_valid_1)
            memd_1[wr_addr_1] <= wr_data_1;
        if (wr_valid_2)
            memd_2[wr_addr_2] <= wr_data_2;
    end
end

// =========================================================================
// Unconstrained shared interrupt (same for both copies)
wire int_shared;

// PTCI: C2 Contract - Sticky-one logic
// =========================================================================
// Detect if two copies' dmem request addresses ever differ
wire diff_dmem_addr = (copy1.dmem_req_valid & copy2.dmem_req_valid) &
                      (copy1.dmem_req_addr != copy2.dmem_req_addr);

reg sticky_dmem_addr;
always @(posedge clk) begin
    if (rst) sticky_dmem_addr <= 0;
    else     sticky_dmem_addr <= sticky_dmem_addr | diff_dmem_addr;
end

// C2 contract: address difference → allow timing difference
wire allow_timing_diff = sticky_dmem_addr;

// Unconstrained delay signal (formal tool explores all possibilities)
wire ptci_delay;  // unconstrained

// PTCI controls: copy1 always gets immediate response;
// copy2 may get delayed response when PTCI allows
wire dmem_delayed_1 = 1'b0;  // copy1: always immediate
wire dmem_delayed_2 = allow_timing_diff & ptci_delay;  // copy2: delayed when PTCI allows

// =========================================================================
// Data memory read: each copy reads from its own memd
// =========================================================================
wire [`REG_LEN-1:0] dmem_data_1 = memd_1[copy1.dmem_req_addr];
wire [`REG_LEN-1:0] dmem_data_2 = memd_2[copy2.dmem_req_addr];

// =========================================================================
// Core instantiation
// =========================================================================
reg [`ROB_SIZE_LOG-1:0] ROB_tail_1, ROB_tail_2;
reg stall_1, stall_2, finish_1, finish_2, commit_deviation, addr_deviation, invalid_program;
reg C_mem_valid_r, C_mem_rdwt_r, C_is_br_r, C_taken_r;
reg [`MEMD_SIZE_LOG-1:0] C_mem_addr_r;

wire wr_valid_1, wr_valid_2;
wire [`MEMD_SIZE_LOG-1:0] wr_addr_1, wr_addr_2;
wire [`REG_LEN-1:0] wr_data_1, wr_data_2;

cpu_ooo_ext_mem copy1(
    .clk(stall_1 ? 0 : clk),
    .rst(rst),
    .dmem_resp_data(dmem_data_1),
    .dmem_resp_delayed(dmem_delayed_1),
    .dmem_wr_valid(wr_valid_1),
    .dmem_wr_addr(wr_addr_1),
    .dmem_wr_data(wr_data_1),
    .interrupt(int_shared),
    .interrupt_taken()
);

cpu_ooo_ext_mem copy2(
    .clk(stall_2 ? 0 : clk),
    .rst(rst),
    .dmem_resp_data(dmem_data_2),
    .dmem_resp_delayed(dmem_delayed_2),
    .dmem_wr_valid(wr_valid_2),
    .dmem_wr_addr(wr_addr_2),
    .dmem_wr_data(wr_data_2),
    .interrupt(int_shared),
    .interrupt_taken()
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

        // Detect deviation in address (only with OBSV_EVERY_ADDR)
        if ((`OBSV==`OBSV_EVERY_ADDR) && !commit_deviation && copy1.ld_addr!=copy2.ld_addr) begin
            addr_deviation <= 1;
            ROB_tail_1 <= copy1.ROB_tail;
            ROB_tail_2 <= copy2.ROB_tail;
        end

        // Drain the ROB
        if ((commit_deviation || ((`OBSV==`OBSV_EVERY_ADDR) ? addr_deviation : 0)) && ((copy1.C_valid && copy1.ROB_head == ROB_tail_1-1 ) || (copy1.C_valid && copy1.C_squash)))
            finish_1 <= 1;
        if ((commit_deviation || ((`OBSV==`OBSV_EVERY_ADDR) ? addr_deviation : 0)) && ((copy2.C_valid && copy2.ROB_head == ROB_tail_1-1 ) || (copy2.C_valid && copy2.C_squash)))
            finish_2 <= 1;
    end
end

endmodule
