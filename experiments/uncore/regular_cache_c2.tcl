# =============================================================================
# Regular Cache: C2 Contract Compliance Verification
# =============================================================================
# C2 permits address-dependent timing but not wdata-dependent timing.
# Expected result: PASS
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2 -sva src/verification/uncore/miter_regular_cache_c2.v

elaborate -top miter_regular_cache_c2
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {cache_1.mem}
abstract -init_value {cache_2.mem}
abstract -init_value {cache_1.cached_addr}
abstract -init_value {cache_2.cached_addr}
assume {cache_1.cached_addr == cache_2.cached_addr}

assert -name c2_regular {c2_regular_pass}

set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 1h

prove -all
save -jdb my_jdb_regular_cache_c2 -capture_setup -capture_session_data -force
exit
