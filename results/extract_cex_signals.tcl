# =============================================================================
# 一键运行：验证 + 提取 CEX 信号值
# 用法：jg -batch results/extract_cex_signals.tcl
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_STT=+PARTIAL_STT_USE_SPEC=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_cache_r.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

assume {invalid_program==0}

abstract -init_value {cache_1.mem}
abstract -init_value {cache_2.mem}
assume {init -> cache_1.mem[0] == cache_2.mem[0]}
assume {init -> cache_1.mem[2] == cache_2.mem[2]}
assume {init -> cache_1.mem[3] == cache_2.mem[3]}

abstract -init_value {cache_1.cached_addr}
abstract -init_value {cache_2.cached_addr}
assume {init -> cache_1.cached_addr == cache_2.cached_addr}

assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

set_prove_orchestration off
set_engine_mode {Ht}
set_prove_time_limit 7d

prove -all

# 打开 CEX 波形
visualize -violation -property {property:0}

# 提取关键信号值（cycle 从 1 开始，到 9）
puts "=== CEX Signal Trace ==="
puts "Cycle | req_v1/v2 | addr1/addr2 | delayed1/d2 | C_valid1/v2 | commit_dev | stall1/s2 | finish1/f2"
puts "------+-----------+-------------+-------------+-------------+------------+-----------+-----------"
for {set i 1} {$i <= 9} {incr i} {
    set a1 [visualize -get_value copy1.dmem_req_addr $i]
    set a2 [visualize -get_value copy2.dmem_req_addr $i]
    set rv1 [visualize -get_value copy1.dmem_req_valid $i]
    set rv2 [visualize -get_value copy2.dmem_req_valid $i]
    set d1 [visualize -get_value cache_1.resp_delayed $i]
    set d2 [visualize -get_value cache_2.resp_delayed $i]
    set cv1 [visualize -get_value copy1.C_valid $i]
    set cv2 [visualize -get_value copy2.C_valid $i]
    set cd [visualize -get_value commit_deviation $i]
    set s1 [visualize -get_value stall_1 $i]
    set s2 [visualize -get_value stall_2 $i]
    set f1 [visualize -get_value finish_1 $i]
    set f2 [visualize -get_value finish_2 $i]
    puts "T[format %2d $i]   | $rv1/$rv2 | $a1/$a2 | $d1/$d2 | $cv1/$cv2 | $cd | $s1/$s2 | $f1/$f2"
}
puts "=== END ==="

exit
