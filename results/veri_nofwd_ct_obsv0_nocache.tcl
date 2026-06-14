# =============================================================================
# Experiment Step 1: NoFwd_spectre + CT + OBSV_COMMITTED_ADDR + NO cache
# =============================================================================
# Expected result: PASS
# Reason: speculative load addresses are NOT observed (OBSV=0),
#         and internal memory has fixed 1-cycle latency → no timing difference.
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_STT=+PARTIAL_STT_USE_SPEC=+OBSV=0+INIT_VALUE=0 -sva ./src/simpleooo/two_copy_top_ct.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

assume {invalid_program==0}

abstract -init_value {copy1.memd}
abstract -init_value {copy2.memd}
assume {init -> copy1.memd[0] == copy2.memd[0]}
assume {init -> copy1.memd[2] == copy2.memd[2]}
assume {init -> copy1.memd[3] == copy2.memd[3]}

assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

set_prove_orchestration off
set_engine_mode {AM}

set_prove_time_limit 7d

prove -all
save -jdb results/my_jdb_nofwd_ct_obsv0_nocache -capture_setup -capture_session_data -force
get_design_info
exit
