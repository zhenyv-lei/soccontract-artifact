# =============================================================================
# Sodor CPU_C3: C3 Platform Timing Contract Verification
# =============================================================================
# C3: wdata can affect gnt AND int (memory-mapped interrupt controller)
# Expected result: FAIL (store with secret data triggers different interrupts)
# =============================================================================

analyze -sva src/sodor2/sodor_2_stage.sv src/sodor2/two_copy_top_c3.sv src/sodor2/param.vh

elaborate -top top -bbox_mul 256 -bbox_a 1024 -bbox_m plusarg_reader -bbox_m GenericDigitalInIOCell -bbox_m GenericDigitalOutIOCell -bbox_m ClockDividerN -bbox_m EICG_wrapper
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.d.regfile}
abstract -init_value {copy2.d.regfile}

get_design_info -list undriven

# ---------------------------------------------------------------------------
# Address range constraints
# ---------------------------------------------------------------------------
assume {(copy1.io_imem_req_bits_addr >> 2) < `IMEM_SIZE}
assume {(copy2.io_imem_req_bits_addr >> 2) < `IMEM_SIZE}
assume {(mem_addr_1>>2 < `MEM_SIZE && mem_addr_1>>2 >= `DMEM_SIZE) || mem_addr_1 == 0}
assume {(mem_addr_2>>2 < `MEM_SIZE && mem_addr_2>>2 >= `DMEM_SIZE) || mem_addr_2 == 0}

# ---------------------------------------------------------------------------
# Legal instructions
# ---------------------------------------------------------------------------
assume {copy1.d.regfile_exe_rs1_data_MPORT_addr < `RF_SIZE && copy1.d.regfile_exe_rs2_data_MPORT_addr < `RF_SIZE}
assume {copy2.d.regfile_exe_rs1_data_MPORT_addr < `RF_SIZE && copy2.d.regfile_exe_rs2_data_MPORT_addr < `RF_SIZE}
assume {copy1.d.regfile_MPORT_1_addr < `RF_SIZE}
assume {copy2.d.regfile_MPORT_1_addr < `RF_SIZE}
assume {!copy1.c.illegal && !copy2.c.illegal}
assume {!copy1.c.io_dat_inst_misaligned && !copy2.c.io_dat_inst_misaligned}
assume {!copy1.c.io_dat_data_misaligned && !copy2.c.io_dat_data_misaligned}

# ---------------------------------------------------------------------------
# Same program assumption (constant-time contract)
# ---------------------------------------------------------------------------
assume {!invalid_program}

# ---------------------------------------------------------------------------
# Security property: no timing leakage
# ---------------------------------------------------------------------------
assert {!((commit_deviation || addr_deviation) && finish_1 && finish_2 && !stall_1 && !stall_2)}

# ---------------------------------------------------------------------------
# PTCI reachability covers
# ---------------------------------------------------------------------------
cover {sticky_dmem_wdata}
cover {allow_int_diff}
cover {allow_dmem_gnt_diff}
cover {commit_deviation}

# ---------------------------------------------------------------------------
# Prove configuration (Ht to find counterexample)
# ---------------------------------------------------------------------------
set_prove_orchestration off
set_engine_mode {Ht}
set_prove_time_limit 7d
prove -all

save -jdb results/my_jdb_sodor_cpu_c3 -capture_setup -capture_session_data -force

exit
