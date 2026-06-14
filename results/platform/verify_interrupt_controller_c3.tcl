# =============================================================================
# Platform_C2 / Platform_C3: Interrupt Controller Compliance Verification
# =============================================================================
# Platform_C2: wdata must NOT affect int → expected FAIL
# Platform_C3: wdata CAN affect int → expected PASS (trivially)
# =============================================================================

analyze -sva src/sodor2/intctrl_miter_verify.v src/sodor2/interrupt_controller.v src/sodor2/param.vh

elaborate -top intctrl_compliance_top
clock clk
reset rst -non_resettable_regs 0

# Platform_C2: different wdata must NOT affect interrupt
assert -name c2_intctrl {c2_intctrl_pass}

# Platform_C3: trivially PASS (C3 allows wdata → int)
assert -name c3_intctrl {c3_intctrl_pass}

# Prove
set_prove_orchestration off
set_engine_mode {AM}
set_prove_time_limit 1h

prove -all
save -jdb results/my_jdb_intctrl_compliance -capture_setup -capture_session_data -force
exit
