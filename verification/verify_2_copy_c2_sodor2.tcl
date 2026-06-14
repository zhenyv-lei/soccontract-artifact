# =============================================================================
# Phase 1a: Core Verification under C2 Platform Timing Contract (Sodor 2-stage)
# =============================================================================
# C2 = Cache
# Expected result: PASS (core is timing-safe under ideal memory)
# =============================================================================

analyze -sva src/sodor2/sodor_2_stage.sv src/sodor2/two_copy_top_c2.sv src/sodor2/param.vh

elaborate -top top -bbox_mul 256 -bbox_a 1024 -bbox_m plusarg_reader -bbox_m GenericDigitalInIOCell -bbox_m GenericDigitalOutIOCell -bbox_m ClockDividerN -bbox_m EICG_wrapper
clock clk
reset rst -non_resettable_regs 0

abstract -init_value {copy1.d.regfile}
abstract -init_value {copy2.d.regfile}

get_design_info -list undriven

# ---------------------------------------------------------------------------
# Address range constraints (same as original, adapted for Core module)
# ---------------------------------------------------------------------------
assume {(copy1.io_imem_req_bits_addr >> 2) < `IMEM_SIZE}
assume {(copy2.io_imem_req_bits_addr >> 2) < `IMEM_SIZE}
assume {(mem_addr_1>>2 < `MEM_SIZE && mem_addr_1>>2 >= `DMEM_SIZE) || mem_addr_1 == 0}
assume {(mem_addr_2>>2 < `MEM_SIZE && mem_addr_2>>2 >= `DMEM_SIZE) || mem_addr_2 == 0}

# ---------------------------------------------------------------------------
# Abstract memory contents (same as original, adapted for Core module)
# ---------------------------------------------------------------------------
# abstract -NET {io_imem_resp_valid_shared io_imem_resp_bits_data_shared}
# abstract -NET {io_dmem_resp_valid_shared io_dmem_resp_bits_data_shared}
# abstract -NET {io_imem_resp_valid_unc io_imem_resp_bits_data_unc}
# abstract -NET {io_dmem_resp_valid_unc io_dmem_resp_bits_data_unc}

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


# PTCI 的 allow 信号是否可达
cover {allow_imem_gnt_diff}
cover {allow_imem_rdata_diff}
cover {allow_dmem_gnt_diff}
cover {allow_dmem_rdata_diff}

# sticky 是否可达
cover {sticky_imem_req}
cover {sticky_imem_addr}
cover {sticky_dmem_req}
cover {sticky_dmem_addr}
cover {sticky_dmem_we}
cover {sticky_dmem_wdata}

# diff 信号是否可达
cover {diff_imem_req}
cover {diff_imem_addr}
cover {diff_dmem_req}
cover {diff_dmem_addr}

cover {commit_deviation}

# resp_valid 解耦后，两个 copy 是否真的收到了不同的 resp_valid？
cover -name cvr_resp_valid_diff {allow_dmem_gnt_diff &&
    (io_dmem_resp_valid_shared != io_dmem_resp_valid_unc)}

# 解耦后，是否存在一个 copy stall 而另一个不 stall？
cover -name cvr_stall_diff {allow_dmem_gnt_diff &&
    (copy1.d.io_ctl_stall != copy2.d.io_ctl_stall)}

# ---------------------------------------------------------------------------
# Prove configuration
# ---------------------------------------------------------------------------
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 7d
prove -all

save -jdb my_jdb_c2_2copy_sodor2 -capture_setup -capture_session_data -force

exit
