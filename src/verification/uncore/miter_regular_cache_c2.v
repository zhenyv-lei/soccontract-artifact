`include "src/core/simpleooo/param.v"
`include "src/uncore/cache/cache_regular.v"

// =============================================================================
// Regular-cache platform compliance under C2
// =============================================================================
// C2 permits address-dependent response timing but does not permit write data
// to influence response timing.
// =============================================================================

module miter_regular_cache_c2(
    input clk,
    input rst
);

wire                      req_valid;
wire [`MEMD_SIZE_LOG-1:0] req_addr;
wire                      wr_valid;
wire [`MEMD_SIZE_LOG-1:0] wr_addr;
wire [`REG_LEN-1:0]       wdata_1;
wire [`REG_LEN-1:0]       wdata_2;

cache_regular cache_1(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(req_addr),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(wr_valid),
    .wr_addr(wr_addr),
    .wr_data(wdata_1)
);

cache_regular cache_2(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(req_addr),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(wr_valid),
    .wr_addr(wr_addr),
    .wr_data(wdata_2)
);

wire c2_regular_pass = (cache_1.resp_delayed == cache_2.resp_delayed);

endmodule
