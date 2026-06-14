# =============================================================================
# NoFwd_spectre + CT + OBSV=0 + C1 PTCI
# =============================================================================
# C1: addr does NOT affect gnt (ideal memory, no cache timing).
# Expected result: PASS (NoFwd is safe for C1-compliant platforms)
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_STT=+PARTIAL_STT_USE_SPEC=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_ptci_c1.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

# Same program
abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

# CT contract
assume {invalid_program==0}

# Abstract shared memd
abstract -init_value {memd}

# Security property
assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

# PTCI covers
cover {sticky_req}
cover {sticky_addr}
cover {allow_gnt_diff}
cover {allow_rdata_diff}
cover {commit_deviation}

# AM for unbounded proof
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 7d

prove -all
save -jdb results/my_jdb_nofwd_ct_obsv0_ptci_c1 -capture_setup -capture_session_data -force
get_design_info
exit
