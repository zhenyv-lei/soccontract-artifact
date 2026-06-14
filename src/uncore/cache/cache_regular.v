// =============================================================================
// Regular Cache: Single-entry cache with hit/miss timing
// =============================================================================
// Hit (same address as cached): 1 cycle
// Miss (different address): 3 cycles (EXECUTING_1 → EXECUTING_0 → FINISHED)
// This cache has address-dependent timing → satisfies C2 but NOT C1.
// =============================================================================

module cache_regular(
    input clk,
    input rst,
    // Read interface
    input                       req_valid,
    input  [`MEMD_SIZE_LOG-1:0] req_addr,
    output [`REG_LEN-1:0]       resp_data,
    output                      resp_delayed,
    // Write interface (from CPU store at commit)
    input                       wr_valid,
    input  [`MEMD_SIZE_LOG-1:0] wr_addr,
    input  [`REG_LEN-1:0]       wr_data
);

    // Internal storage
    reg [`REG_LEN-1:0] mem [`MEMD_SIZE-1:0];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `MEMD_SIZE; i = i + 1)
                mem[i] <= 0;
        end
        else if (wr_valid) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Single-entry cache tag
    reg [`MEMD_SIZE_LOG-1:0] cached_addr;
    always @(posedge clk) begin
        if (rst)
            cached_addr <= 0;
        else if (req_valid)
            cached_addr <= req_addr;
    end

    // Data: combinational read (always returns correct data)
    assign resp_data = mem[req_addr];

    // Timing: address-dependent!
    // Hit (same as cached addr): immediate (delayed=0)
    // Miss (different addr): delayed (delayed=1)
    assign resp_delayed = req_valid & (req_addr != cached_addr);

endmodule
