# =============================================================================
# Interrupt-Controller Platform: C4 Contract Compliance Verification
# =============================================================================
# C4 allows wdata to affect interrupt only for writes to periph_range.
# Expected result: PASS
# =============================================================================

analyze -sva src/verification/uncore/miter_interrupt_controller_c4.sv

elaborate -top miter_interrupt_controller_c4
clock clk
reset rst -non_resettable_regs 0

assert -name c4_intctrl {c4_intctrl_pass}
cover -name c4_peripheral_flow {sticky_wdata_periph}

# Prove
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 1h

prove -all
save -jdb my_jdb_interrupt_controller_c4 -capture_setup -capture_session_data -force
exit
