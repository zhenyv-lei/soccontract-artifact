analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_STT=+PARTIAL_STT_USE_SPEC=+USE_CACHE=+OBSV=1+INIT_VALUE=0 -sva ./src/simpleooo/two_copy_top_ct.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

assume {invalid_program==0}

abstract -init_value {copy1.memd[1]}
abstract -init_value {copy2.memd[1]}

abstract -init_value {copy1.cached_addr}
abstract -init_value {copy2.cached_addr}
assume {init -> copy1.cached_addr == copy2.cached_addr}
assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

set_prove_orchestration off
set_engine_mode {Ht}

set_prove_time_limit 1h

prove -all
save -jdb results/my_jdb_ct_2copy_RF4_MEMI16_MEMD4_ROB4_CACHE1_PSTT_USESPEC -capture_setup -capture_session_data
get_design_info
exit

