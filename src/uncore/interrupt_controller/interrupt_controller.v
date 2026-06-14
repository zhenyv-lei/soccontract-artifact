// =============================================================================
// Simple Memory-Mapped Interrupt Controller
// =============================================================================
// Write non-zero value → assert interrupt
// Write zero → deassert interrupt
// This creates wdata → int information flow (satisfies C3 but NOT C2)
// =============================================================================

module interrupt_controller(
    input clk,
    input rst,
    // Write interface (from CPU store)
    input                       wr_valid,
    input  [`REG_LEN-1:0]       wr_data,
    // Interrupt output
    output                      interrupt
);

    reg [`REG_LEN-1:0] int_reg;

    always @(posedge clk) begin
        if (rst)
            int_reg <= 0;
        else if (wr_valid)
            int_reg <= wr_data;
    end

    assign interrupt = (int_reg != 0);

endmodule
