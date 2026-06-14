# =============================================================================
# Experiment: NoFwd_spectre + CT + OBSV=0 + Regular Cache
# =============================================================================
# 运行完毕后不退出，保留 GUI 供查看 CEX 波形
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_STT=+PARTIAL_STT_USE_SPEC=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_cache_r.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

# Same program
abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

# CT contract
assume {invalid_program==0}

# Abstract cache memory: public same, secret (mem[1]) can differ
abstract -init_value {cache_1.mem}
abstract -init_value {cache_2.mem}
assume {init -> cache_1.mem[0] == cache_2.mem[0]}
assume {init -> cache_1.mem[2] == cache_2.mem[2]}
assume {init -> cache_1.mem[3] == cache_2.mem[3]}

# Abstract cache tag (same initial state)
abstract -init_value {cache_1.cached_addr}
abstract -init_value {cache_2.cached_addr}
assume {init -> cache_1.cached_addr == cache_2.cached_addr}

# Security property
assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

# Prove
set_prove_orchestration off
set_engine_mode {Ht}
set_prove_time_limit 7d

prove -all

# 保存新的 JDB 数据库
save -task <embedded> -jdb results/my_jdb_nofwd_ct_obsv0_cache_r_new -capture_setup -capture_session_data -force

# 自动打开 CEX 波形
visualize -violation -property {property:0}
