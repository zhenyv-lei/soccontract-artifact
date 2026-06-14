# =============================================================================
# Sodor-S CPU_C4 WITH PMP constraint
# =============================================================================
# C4 contract: wdata affects gnt/int only in periph_range
# PMP: secret data CANNOT be stored to periph_range (same wdata for both copies)
# Expected: PASS
# =============================================================================

analyze -sva src/sodor2/sodor_2_stage.sv src/sodor2/two_copy_top_c4.sv src/sodor2/param.vh

elaborate -top top -bbox_mul 256 -bbox_a 1024 -bbox_m plusarg_reader -bbox_m GenericDigitalInIOCell -bbox_m GenericDigitalOutIOCell -bbox_m ClockDividerN -bbox_m EICG_wrapper
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.d.regfile}
abstract -init_value {copy2.d.regfile}

get_design_info -list undriven

assume {(copy1.io_imem_req_bits_addr >> 2) < `IMEM_SIZE}
assume {(copy2.io_imem_req_bits_addr >> 2) < `IMEM_SIZE}
assume {(mem_addr_1>>2 < `MEM_SIZE && mem_addr_1>>2 >= `DMEM_SIZE) || mem_addr_1 == 0}
assume {(mem_addr_2>>2 < `MEM_SIZE && mem_addr_2>>2 >= `DMEM_SIZE) || mem_addr_2 == 0}

assume {copy1.d.regfile_exe_rs1_data_MPORT_addr < `RF_SIZE && copy1.d.regfile_exe_rs2_data_MPORT_addr < `RF_SIZE}
assume {copy2.d.regfile_exe_rs1_data_MPORT_addr < `RF_SIZE && copy2.d.regfile_exe_rs2_data_MPORT_addr < `RF_SIZE}
assume {copy1.d.regfile_MPORT_1_addr < `RF_SIZE}
assume {copy2.d.regfile_MPORT_1_addr < `RF_SIZE}
assume {!copy1.c.illegal && !copy2.c.illegal}
assume {!copy1.c.io_dat_inst_misaligned && !copy2.c.io_dat_inst_misaligned}
assume {!copy1.c.io_dat_data_misaligned && !copy2.c.io_dat_data_misaligned}

assume {!invalid_program}

# PMP constraint: stores to periph_range must have same wdata (no secret writes to I/O)
assume {(copy1.io_dmem_req_bits_fcn && copy1.io_dmem_req_bits_addr[31:2] < 1) -> (copy1.io_dmem_req_bits_data == copy2.io_dmem_req_bits_data)}

assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

cover {sticky_dmem_wdata_periph}
cover {allow_int_diff}
cover {commit_deviation}

set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 7d
prove -all

save -jdb results/my_jdb_sodor_cpu_c4_pmp -capture_setup -capture_session_data -force
exit
