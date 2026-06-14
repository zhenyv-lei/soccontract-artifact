// =============================================================================
// Cache-S: Secure Cache with Fixed Latency
// =============================================================================
// All memory accesses take exactly 1 cycle regardless of address.
// No address-dependent timing → satisfies C1 (and therefore C2).
// =============================================================================

module cache_secure(
    input clk,
    input rst,
    // Read interface (from CPU load)
    input                       req_valid,
    input  [`MEMD_SIZE_LOG-1:0] req_addr,
    output [`REG_LEN-1:0]       resp_data,
    output                      resp_delayed,
    // Write interface (from CPU store at commit)
    input                       wr_valid,
    input  [`MEMD_SIZE_LOG-1:0] wr_addr,
    input  [`REG_LEN-1:0]       wr_data
);

    // Internal storage (initialized by TCL abstract/assume)
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

    // Fixed 1-cycle latency: combinational read, no address-dependent timing
    assign resp_data = mem[req_addr];
    assign resp_delayed = 1'b0;  // Never delayed — constant timing

endmodule
