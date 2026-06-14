# =============================================================================
# Interrupt Controller: Uncore Contract Compliance Verification
# =============================================================================
# Platform_C2: wdata must NOT affect int → expected FAIL
# Platform_C3: wdata CAN affect int → expected PASS (trivially)
# Expected result: C2 counterexample; C3-permitted flow is reachable
# =============================================================================

analyze -sva src/verification/uncore/miter_interrupt_controller_compliance.sv src/uncore/interrupt_controller/interrupt_controller.v src/core/sodor/param.vh

elaborate -top miter_interrupt_controller_compliance
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
save -jdb my_jdb_interrupt_controller -capture_setup -capture_session_data -force
exit
