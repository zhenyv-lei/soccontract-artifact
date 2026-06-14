# =============================================================================
# Experiment B: Cache-S Contract Compliance Verification
# =============================================================================
# Verify Cache-S satisfies C1 contract (timing independent of address).
# Expected result: PASS
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2 -sva ./src/simpleooo/cache_miter_verify.v

elaborate -top cache_miter_top
clock clk
reset rst -non_resettable_regs 0

# Abstract internal storage (different secrets between instances)
abstract -init_value {cache_1.mem}
abstract -init_value {cache_2.mem}

# C1 assertion: timing never depends on address
assert {c1_timing_safe}
assert {c1_timing_equal}

# Prove
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 1h

prove -all
save -jdb results/my_jdb_cache_s_compliance -capture_setup -capture_session_data -force
exit
