# =============================================================================
# Experiment A: Delay (with interrupt hardware) + interrupt=0 + C2 PTCI
# =============================================================================
# Tests whether the hardware change (adding interrupt port) alone breaks C2.
# interrupt tied to 0 → no interrupt ever fires.
# Expected: PASS (same as original Delay C2, interrupt hardware is dormant)
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_DOM=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_ptci_c2_int0.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

assume {invalid_program==0}

abstract -init_value {memd_1}
abstract -init_value {memd_2}
assume {init -> memd_1[0] == memd_2[0]}
assume {init -> memd_1[2] == memd_2[2]}
assume {init -> memd_1[3] == memd_2[3]}

assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

cover {sticky_dmem_addr}
cover {commit_deviation}

set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 7d

prove -all
save -jdb results/my_jdb_delay_c2_int0 -capture_setup -capture_session_data -force
get_design_info
exit
