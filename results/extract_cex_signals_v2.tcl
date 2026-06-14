# =============================================================================
# CEX 信号提取 v2：修复 addr_deviation 未初始化问题
# 用法：jg -batch results/extract_cex_signals_v2.tcl
# =============================================================================

analyze +define+RF_SIZE=4+RF_SIZE_LOG=2+MEMI_SIZE=16+MEMI_SIZE_LOG=4+MEMD_SIZE=4+MEMD_SIZE_LOG=2+ROB_SIZE=4+ROB_SIZE_LOG=2+BR_PREDICT=0+USE_DEFENSE_PARTIAL_STT=+PARTIAL_STT_USE_SPEC=+OBSV=0+INIT_VALUE=0+IMM_STALL= -sva ./src/simpleooo/two_copy_top_ct_cache_r.v

elaborate -top top -bbox_mul 256
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.memi_instance.array}
abstract -init_value {copy2.memi_instance.array}
assume {copy1.memi_instance.array == copy2.memi_instance.array}

assume {invalid_program==0}

# 修复：OBSV=0 下 addr_deviation 未被赋值，强制为 0 以避免自由变量产生假反例
assume {addr_deviation==0}

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

visualize -violation -property {property:0}

# 动态获取 CEX 长度
set max_cycle 20

puts ""
puts "=== Interface Signals ==="
puts "Cycle | req_v1/v2 | addr1/addr2 | delayed1/d2 | cached1/c2"
for {set i 1} {$i <= $max_cycle} {incr i} {
    if {[catch {
        set rv1 [visualize -get_value copy1.dmem_req_valid $i]
        set rv2 [visualize -get_value copy2.dmem_req_valid $i]
        set a1 [visualize -get_value copy1.dmem_req_addr $i]
        set a2 [visualize -get_value copy2.dmem_req_addr $i]
        set d1 [visualize -get_value cache_1.resp_delayed $i]
        set d2 [visualize -get_value cache_2.resp_delayed $i]
        set ca1 [visualize -get_value cache_1.cached_addr $i]
        set ca2 [visualize -get_value cache_2.cached_addr $i]
        puts "T[format %2d $i] | $rv1/$rv2 | $a1/$a2 | $d1/$d2 | $ca1/$ca2"
    } err]} {
        break
    }
}

puts ""
puts "=== Pipeline Internals ==="
puts "Cycle | PC1/PC2 | C_valid1/2 | C_squash1/2 | ROB_head1/2 | ROB_tail1/2"
for {set i 1} {$i <= $max_cycle} {incr i} {
    if {[catch {
        set pc1 [visualize -get_value copy1.F_pc $i]
        set pc2 [visualize -get_value copy2.F_pc $i]
        set cv1 [visualize -get_value copy1.C_valid $i]
        set cv2 [visualize -get_value copy2.C_valid $i]
        set cs1 [visualize -get_value copy1.C_squash $i]
        set cs2 [visualize -get_value copy2.C_squash $i]
        set rh1 [visualize -get_value copy1.ROB_head $i]
        set rh2 [visualize -get_value copy2.ROB_head $i]
        set rt1 [visualize -get_value copy1.ROB_tail $i]
        set rt2 [visualize -get_value copy2.ROB_tail $i]
        puts "T[format %2d $i] | $pc1/$pc2 | $cv1/$cv2 | $cs1/$cs2 | $rh1/$rh2 | $rt1/$rt2"
    } err]} {
        break
    }
}

puts ""
puts "=== Execute Stage ==="
puts "Cycle | ld_addr1/2 | C_mem_valid1/2 | C_mem_addr1/2 | C_is_br1/2 | C_taken1/2"
for {set i 1} {$i <= $max_cycle} {incr i} {
    if {[catch {
        set la1 [visualize -get_value copy1.ld_addr $i]
        set la2 [visualize -get_value copy2.ld_addr $i]
        set mv1 [visualize -get_value copy1.C_mem_valid $i]
        set mv2 [visualize -get_value copy2.C_mem_valid $i]
        set ma1 [visualize -get_value copy1.C_mem_addr $i]
        set ma2 [visualize -get_value copy2.C_mem_addr $i]
        set br1 [visualize -get_value copy1.C_is_br $i]
        set br2 [visualize -get_value copy2.C_is_br $i]
        set tk1 [visualize -get_value copy1.C_taken $i]
        set tk2 [visualize -get_value copy2.C_taken $i]
        puts "T[format %2d $i] | $la1/$la2 | $mv1/$mv2 | $ma1/$ma2 | $br1/$br2 | $tk1/$tk2"
    } err]} {
        break
    }
}

puts ""
puts "=== Shadow Logic ==="
puts "Cycle | commit_dev | stall1/2 | finish1/2 | invalid_prog | addr_dev"
for {set i 1} {$i <= $max_cycle} {incr i} {
    if {[catch {
        set cd [visualize -get_value commit_deviation $i]
        set s1 [visualize -get_value stall_1 $i]
        set s2 [visualize -get_value stall_2 $i]
        set f1 [visualize -get_value finish_1 $i]
        set f2 [visualize -get_value finish_2 $i]
        set ip [visualize -get_value invalid_program $i]
        set ad [visualize -get_value addr_deviation $i]
        puts "T[format %2d $i] | $cd | $s1/$s2 | $f1/$f2 | $ip | $ad"
    } err]} {
        break
    }
}

puts ""
puts "=== DONE ==="

exit
