`include "src/simpleooo/param.v"
`include "src/simpleooo/cache_regular.v"
`include "src/simpleooo/cache_secure.v"

// =============================================================================
// Experiment II: Cache Contract Compliance Verification
// =============================================================================
// C2 check: same req/addr, different wdata → gnt must be same
//   (C2 does NOT allow wdata→gnt)
//
// C1 check: same req, different addr → gnt must be same
//   (C1 does NOT allow addr→gnt)
// =============================================================================

module cache_compliance_top(
    input clk,
    input rst
);

// =========================================================================
// Unconstrained inputs (formal tool explores all)
// =========================================================================
wire                       req_valid;
wire [`MEMD_SIZE_LOG-1:0]  addr_shared;     // shared address for C2 test
wire [`MEMD_SIZE_LOG-1:0]  addr_1, addr_2;  // different addresses for C1 test

// Store signals: shared addr/valid, different wdata for C2 test
wire                       wr_valid;
wire [`MEMD_SIZE_LOG-1:0]  wr_addr_shared;
wire [`REG_LEN-1:0]        wdata_1, wdata_2;  // different write data

// =========================================================================
// C2 compliance: Regular Cache
// Same req/addr + same wr_addr, different wdata → gnt must be same
// =========================================================================
cache_regular reg_cache_c2_1(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(addr_shared),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(wr_valid),
    .wr_addr(wr_addr_shared),
    .wr_data(wdata_1)
);
cache_regular reg_cache_c2_2(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(addr_shared),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(wr_valid),
    .wr_addr(wr_addr_shared),
    .wr_data(wdata_2)
);

// C2 assertion: different wdata must NOT affect gnt (timing)
wire c2_regular_pass = (reg_cache_c2_1.resp_delayed == reg_cache_c2_2.resp_delayed);

// =========================================================================
// C1 compliance: Regular Cache
// Same req, different addr → gnt must be same
// =========================================================================
cache_regular reg_cache_c1_1(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(addr_1),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(1'b0),
    .wr_addr({`MEMD_SIZE_LOG{1'b0}}),
    .wr_data({`REG_LEN{1'b0}})
);
cache_regular reg_cache_c1_2(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(addr_2),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(1'b0),
    .wr_addr({`MEMD_SIZE_LOG{1'b0}}),
    .wr_data({`REG_LEN{1'b0}})
);

// C1 assertion: addr must NOT affect gnt (timing)
wire c1_regular_pass = (reg_cache_c1_1.resp_delayed == reg_cache_c1_2.resp_delayed);

// =========================================================================
// C1 compliance: Cache-S (secure, fixed latency)
// Same req, different addr → gnt must be same
// =========================================================================
cache_secure sec_cache_c1_1(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(addr_1),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(1'b0),
    .wr_addr({`MEMD_SIZE_LOG{1'b0}}),
    .wr_data({`REG_LEN{1'b0}})
);
cache_secure sec_cache_c1_2(
    .clk(clk), .rst(rst),
    .req_valid(req_valid),
    .req_addr(addr_2),
    .resp_data(),
    .resp_delayed(),
    .wr_valid(1'b0),
    .wr_addr({`MEMD_SIZE_LOG{1'b0}}),
    .wr_data({`REG_LEN{1'b0}})
);

// C1 assertion: addr must NOT affect gnt
wire c1_secure_pass = (sec_cache_c1_1.resp_delayed == sec_cache_c1_2.resp_delayed);

endmodule
