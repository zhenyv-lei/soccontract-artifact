# =============================================================================
# SimpleOoO-S CPU_TCI(C3): Delay + PMP + CT + OBSV=0 + C3 PTCI (interrupt)
# =============================================================================
# Delay defense handles C2 (blocks speculative address leakage).
# PMP constraint handles C3 (blocks secret store data to peripheral range).
# Combined: expected PASS.
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_DOM=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_ptci_c3.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

# Same program for both copies
abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

# CT contract constraint
assume {invalid_program==0}

# Abstract independent memd (different secrets for each copy)
abstract -init_value {memd_1}
abstract -init_value {memd_2}

# PMP constraint: stores to peripheral address (addr 3) must have same wdata
# This prevents secret data from reaching the interrupt controller
assume {(copy1.dmem_wr_valid && copy1.dmem_wr_addr == 2'd3) -> (copy1.dmem_wr_data == copy2.dmem_wr_data)}

# Security property
assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

# ---------------------------------------------------------------------------
# PTCI reachability covers
# ---------------------------------------------------------------------------
cover {sticky_dmem_addr}
cover {sticky_wr_data}
cover {sticky_wr_data_periph}
cover {allow_timing_diff}
cover {allow_int_diff}
cover {commit_deviation}

# ---------------------------------------------------------------------------
# Prove configuration (AM engine to prove safety)
# ---------------------------------------------------------------------------
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 7d

prove -all
save -jdb results/my_jdb_delay_ct_obsv0_ptci_c3_pmp -capture_setup -capture_session_data -force
get_design_info
exit
