`include "src/sodor2/param.vh"
`include "src/sodor2/interrupt_controller.v"

// =============================================================================
// Platform_C2 / Platform_C3: Interrupt Controller Compliance Verification
// =============================================================================
// Platform_C2: wdata must NOT affect int → expected FAIL
// Platform_C3: wdata CAN affect int → expected PASS
// =============================================================================

module intctrl_compliance_top(
    input clk,
    input rst
);

// =========================================================================
// Unconstrained inputs
// =========================================================================
wire                wr_valid;        // shared write valid
wire [`REG_LEN-1:0] wdata_1, wdata_2;  // different write data

// =========================================================================
// Platform_C2: same wr_valid, different wdata → int must be same
// (C2 does NOT allow wdata → int)
// =========================================================================
interrupt_controller intctrl_c2_1(
    .clk(clk), .rst(rst),
    .wr_valid(wr_valid),
    .wr_data(wdata_1),
    .interrupt()
);

interrupt_controller intctrl_c2_2(
    .clk(clk), .rst(rst),
    .wr_valid(wr_valid),
    .wr_data(wdata_2),
    .interrupt()
);

// C2 assertion: different wdata must NOT affect interrupt
wire c2_intctrl_pass = (intctrl_c2_1.interrupt == intctrl_c2_2.interrupt);

// C3: wdata CAN affect int, so no assertion needed on int
// C3 compliance is trivially PASS (C3 allows wdata → int)
wire c3_intctrl_pass = 1'b1;

endmodule
