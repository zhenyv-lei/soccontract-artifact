# =============================================================================
# Experiment II: Cache Contract Compliance Verification
# =============================================================================
# II-a: Regular Cache C2 compliance → expected PASS
# II-b: Regular Cache C1 compliance → expected FAIL
# II-c: Cache-S C1 compliance       → expected PASS
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2 -sva ./src/simpleooo/cache_miter_c2.v

elaborate -top cache_compliance_top
clock clk
reset rst -non_resettable_regs 0

# Abstract all cache internal storage
abstract -init_value {reg_cache_c2_1.mem}
abstract -init_value {reg_cache_c2_2.mem}
abstract -init_value {reg_cache_c1_1.mem}
abstract -init_value {reg_cache_c1_2.mem}
abstract -init_value {sec_cache_c1_1.mem}
abstract -init_value {sec_cache_c1_2.mem}

# Abstract cache tags (initial cached_addr)
abstract -init_value {reg_cache_c2_1.cached_addr}
abstract -init_value {reg_cache_c2_2.cached_addr}
abstract -init_value {reg_cache_c1_1.cached_addr}
abstract -init_value {reg_cache_c1_2.cached_addr}

# C2 caches must have same initial cache state
assume {reg_cache_c2_1.cached_addr == reg_cache_c2_2.cached_addr}

# C1 caches must have same initial cache state
assume {reg_cache_c1_1.cached_addr == reg_cache_c1_2.cached_addr}

# II-a: Regular Cache satisfies C2 (wdata doesn't affect gnt)
assert -name c2_regular {c2_regular_pass}

# II-b: Regular Cache satisfies C1 (addr doesn't affect gnt) — expect FAIL
assert -name c1_regular {c1_regular_pass}

# II-c: Cache-S satisfies C1 (addr doesn't affect gnt) — expect PASS
assert -name c1_secure {c1_secure_pass}

# Prove
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 1h

prove -all
save -jdb results/my_jdb_cache_compliance -capture_setup -capture_session_data -force
exit
