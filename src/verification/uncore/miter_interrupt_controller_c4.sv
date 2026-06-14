`include "src/core/sodor/param.vh"
`include "src/uncore/interrupt_controller/interrupt_controller.v"

// =============================================================================
// Interrupt-controller platform compliance under C4
// =============================================================================
// C4 permits wdata to affect interrupt only for writes to periph_range.
// The address decoder and interrupt controller together form the platform DUT.
// =============================================================================

`define PERIPH_START 0
`define PERIPH_END   1

module miter_interrupt_controller_c4(
    input clk,
    input rst
);

wire                  wr_valid;
wire [`REG_LEN-1:0]   addr;
wire [`REG_LEN-1:0]   wdata_1;
wire [`REG_LEN-1:0]   wdata_2;

wire in_periph_range = (addr[31:2] >= `PERIPH_START) &
                       (addr[31:2] < `PERIPH_END);
wire store_valid = wr_valid & in_periph_range;
wire diff_wdata_periph = store_valid & (wdata_1 != wdata_2);

reg sticky_wdata_periph;
always @(posedge clk) begin
    if (rst)
        sticky_wdata_periph <= 1'b0;
    else
        sticky_wdata_periph <= sticky_wdata_periph | diff_wdata_periph;
end

interrupt_controller intctrl_1(
    .clk(clk), .rst(rst),
    .wr_valid(store_valid),
    .wr_data(wdata_1),
    .interrupt()
);

interrupt_controller intctrl_2(
    .clk(clk), .rst(rst),
    .wr_valid(store_valid),
    .wr_data(wdata_2),
    .interrupt()
);

wire c4_intctrl_pass = sticky_wdata_periph |
                       (intctrl_1.interrupt == intctrl_2.interrupt);

endmodule
