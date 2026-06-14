`include "src/simpleooo/param.v"

`include "src/simpleooo/decode.v"
`include "src/simpleooo/execute.v"
`include "src/simpleooo/param.v"
`include "src/simpleooo/rf.v"
`include "src/simpleooo/memi.v"

`include "src/simpleooo/cpu_ooo_ext_mem.v"

// =============================================================================
// SimpleOoO CPU_TCI(C3): Core Verification under C3 Platform Timing Contract
// =============================================================================
// C3 contract (cache + interrupt platform):
//   req   → diamond{gnt, rdata}
//   addr  → diamond{gnt, rdata}
//   wdata → diamond{gnt, rdata, int}   ← C3: wdata can affect timing AND interrupt
//
// Uses independent memd for each copy (different secrets), same as ptci.v.
// PTCI controls timing AND interrupt based on address/wdata differences.
//
// Expected: FAIL (secret-dependent store data triggers different interrupts)
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

// Each copy reads from its own memd
wire [`REG_LEN-1:0] dmem_data_1 = memd_1[copy1.dmem_req_addr];
wire [`REG_LEN-1:0] dmem_data_2 = memd_2[copy2.dmem_req_addr];

// =========================================================================
// PTCI: C3 Contract - Sticky-one logic
// =========================================================================

// --- Load interface: detect address differences ---
wire diff_dmem_addr = (copy1.dmem_req_valid & copy2.dmem_req_valid) &
                      (copy1.dmem_req_addr != copy2.dmem_req_addr);

// --- Store interface: detect write data differences ---
// All addresses: for timing (C3 allows wdata to affect gnt)
wire diff_wr_data = (copy1.dmem_wr_valid & copy2.dmem_wr_valid) &
                    (copy1.dmem_wr_data != copy2.dmem_wr_data);

// Peripheral address only (addr == MEMD_SIZE-1): for interrupt
// Only stores to the peripheral address range can affect interrupt behavior
wire in_periph_range = (copy1.dmem_wr_addr == (`MEMD_SIZE - 1));
wire diff_wr_data_periph = diff_wr_data & in_periph_range;

reg sticky_dmem_addr;
reg sticky_wr_data;
reg sticky_wr_data_periph;
always @(posedge clk) begin
    if (rst) begin
        sticky_dmem_addr      <= 0;
        sticky_wr_data        <= 0;
        sticky_wr_data_periph <= 0;
    end else begin
        sticky_dmem_addr      <= sticky_dmem_addr      | diff_dmem_addr;
        sticky_wr_data        <= sticky_wr_data        | diff_wr_data;
        sticky_wr_data_periph <= sticky_wr_data_periph | diff_wr_data_periph;
    end
end

// C3 contract mapping:
//   addr  → {gnt}:  address difference allows timing difference
//   wdata → {gnt, int} IF addr ∈ periph_range:
//     only periph store data can affect timing AND interrupt
wire allow_timing_diff = sticky_dmem_addr | sticky_wr_data_periph;
wire allow_int_diff    = sticky_wr_data_periph;  // C3: only periph wdata affects interrupt

// Unconstrained signals (formal tool explores all possibilities)
wire ptci_delay;  // unconstrained delay for copy2
wire int_shared;  // unconstrained shared interrupt (baseline)
wire int_unc;     // unconstrained independent interrupt for copy2

// PTCI controls
wire dmem_delayed_1 = 1'b0;                               // copy1: always immediate
wire dmem_delayed_2 = allow_timing_diff & ptci_delay;      // copy2: delayed when allowed
wire int_1 = int_shared;                                   // copy1: shared interrupt
wire int_2 = allow_int_diff ? int_unc : int_shared;        // copy2: PTCI-controlled

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
    .interrupt(int_1),
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
    .interrupt(int_2),
    .interrupt_taken()
);

// =========================================================================
// Shadow Logic (C3 version: distinguish interrupt vs branch squash)
// =========================================================================

// C3: Distinguish interrupt-caused squash from branch-caused squash
wire either_is_interrupt = copy1.interrupt_taken || copy2.interrupt_taken;

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
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken && !either_is_interrupt)
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
            if (C_is_br_r && copy2.C_is_br && C_taken_r != copy2.C_taken && !either_is_interrupt)
                invalid_program <= 1;
            stall_1 <= 0;
        end
        else if (!stall_1 && stall_2 && copy1.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && C_mem_valid_r && C_mem_rdwt_r && copy1.C_mem_addr != C_mem_addr_r)
                invalid_program <= 1;
            if (copy1.C_is_br && C_is_br_r && copy1.C_taken != C_taken_r && !either_is_interrupt)
                invalid_program <= 1;
            stall_2 <= 0;
        end
        `else
        if (!stall_1 && !stall_2 && copy1.C_valid && copy2.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && copy2.C_mem_valid && copy2.C_mem_rdwt && copy1.C_mem_addr != copy2.C_mem_addr)
                invalid_program = 1;
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken && !either_is_interrupt)
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
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken && !either_is_interrupt)
                invalid_program = 1;
            stall_1 = 0;
        end
        else if (!stall_1 && stall_2 && copy1.C_valid) begin
            if (copy1.C_mem_valid && copy1.C_mem_rdwt && copy2.C_mem_valid && copy2.C_mem_rdwt && copy1.C_mem_addr != copy2.C_mem_addr)
                invalid_program = 1;
            if (copy1.C_is_br && copy2.C_is_br && copy1.C_taken != copy2.C_taken && !either_is_interrupt)
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
