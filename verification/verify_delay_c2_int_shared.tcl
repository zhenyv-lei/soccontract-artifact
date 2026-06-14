# =============================================================================
# Experiment B: Delay (with interrupt hardware) + int_shared + C2 PTCI
# =============================================================================
# Tests whether unconstrained shared interrupt signal amplifies timing diffs.
# Both copies receive the SAME unconstrained interrupt → no interrupt difference.
# But interrupt can fire at worst-case moments.
# Expected: FAIL (interrupt amplifies C2 timing differences)
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_DOM=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_ptci_c2_int_shared.v

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
cover {copy1.interrupt_taken}

set_prove_orchestration off
set_engine_mode {Ht}
set_prove_time_limit 7d

prove -all
save -jdb results/my_jdb_delay_c2_int_shared -capture_setup -capture_session_data -force
get_design_info
exit
