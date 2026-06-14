# =============================================================================
# Experiment C: SimpleOoO-SS (Delay_spectre) + Cache-S Combined Verification
# =============================================================================
# CPU with Delay defense + fixed-latency secure cache.
# Expected result: PASS
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_DOM=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_cache_s.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

# Same program for both copies
abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

# CT contract constraint
assume {invalid_program==0}

# Abstract cache memory: public entries same, secret (mem[1]) can differ
abstract -init_value {cache_1.mem}
abstract -init_value {cache_2.mem}
assume {init -> cache_1.mem[0] == cache_2.mem[0]}
assume {init -> cache_1.mem[2] == cache_2.mem[2]}
assume {init -> cache_1.mem[3] == cache_2.mem[3]}

# Security property
assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

# Prove configuration (AM for unbounded proof)
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 7d

prove -all
save -jdb results/my_jdb_delay_ct_obsv0_cache_s -capture_setup -capture_session_data -force
get_design_info
exit
