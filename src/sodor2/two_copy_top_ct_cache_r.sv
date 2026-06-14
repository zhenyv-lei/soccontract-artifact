`include "src/sodor2/param.vh"
`include "src/sodor2/sodor_2_stage.sv"

// =============================================================================
// Sodor + Regular Cache: Combined Verification
// =============================================================================
// Sodor Core with regular cache (hit/miss timing).
// Expected: PASS (Sodor has no speculative execution, same addresses → same timing)
// =============================================================================

// Simple single-entry cache for Sodor (same logic as SimpleOoO's cache_regular)
module sodor_cache_regular(
    input clk,
    input rst,
    input                req_valid,
    input  [31:0]        req_addr,
    input                req_we,
    input  [31:0]        req_wdata,
    output [31:0]        resp_data,
    output               resp_delayed
);
    reg [31:0] mem [`DMEM_SIZE-1:0];
    reg [31:0] cached_addr;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `DMEM_SIZE; i = i + 1)
                mem[i] <= 0;
            cached_addr <= 0;
        end else begin
            if (req_valid && req_we)
                mem[req_addr[31:2]] <= req_wdata;
            if (req_valid)
                cached_addr <= req_addr;
        end
    end

    assign resp_data = mem[req_addr[31:2]];
    assign resp_delayed = req_valid & (req_addr != cached_addr);
endmodule

module top(
    input clk,
    input rst
);

// =========================================================================
// Cache instances
// =========================================================================
sodor_cache_regular cache_1(
    .clk(clk), .rst(rst),
    .req_valid(copy1.io_dmem_req_valid),
    .req_addr(copy1.io_dmem_req_bits_addr),
    .req_we(copy1.io_dmem_req_bits_fcn),
    .req_wdata(copy1.io_dmem_req_bits_data),
    .resp_data(),
    .resp_delayed()
);

sodor_cache_regular cache_2(
    .clk(clk), .rst(rst),
    .req_valid(copy2.io_dmem_req_valid),
    .req_addr(copy2.io_dmem_req_bits_addr),
    .req_we(copy2.io_dmem_req_bits_fcn),
    .req_wdata(copy2.io_dmem_req_bits_data),
    .resp_data(),
    .resp_delayed()
);

// =========================================================================
// Shared imem, cache-controlled dmem
// =========================================================================
wire         io_imem_resp_valid_shared;
wire  [31:0] io_imem_resp_bits_data_shared;

// dmem resp: data from cache, timing controlled by cache hit/miss
// Use resp_delayed to gate clock (same mechanism as SimpleOoO's dmem_resp_delayed)
// For Sodor 2-stage: resp_delayed causes stall via resp_valid
wire         io_dmem_resp_valid_1 = ~cache_1.resp_delayed;
wire         io_dmem_resp_valid_2 = ~cache_2.resp_delayed;

// =========================================================================
// Core instantiation
// =========================================================================
reg stall_1, stall_2, finish_1, finish_2, commit_deviation, addr_deviation, invalid_program;

Core copy1(
    .clock(stall_1 ? 1'b0 : clk),
    .reset(rst),
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    .io_dmem_resp_valid(io_dmem_resp_valid_1),
    .io_dmem_resp_bits_data(cache_1.resp_data),
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(1'b0),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

Core copy2(
    .clock(stall_2 ? 1'b0 : clk),
    .reset(rst),
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    .io_dmem_resp_valid(io_dmem_resp_valid_2),
    .io_dmem_resp_bits_data(cache_2.resp_data),
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(1'b0),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// Shadow Logic (standard CT)
// =========================================================================
wire mem_valid_1 = copy1.io_dmem_req_valid;
wire mem_valid_2 = copy2.io_dmem_req_valid;
wire [31:0] mem_addr_1 = copy1.io_dmem_req_valid ? copy1.io_dmem_req_bits_addr : 32'b0;
wire [31:0] mem_addr_2 = copy2.io_dmem_req_valid ? copy2.io_dmem_req_bits_addr : 32'b0;

wire [31:0] if_pc_next_1 = copy1.d._if_pc_next_T   ? copy1.d.if_pc_plus4   :
                            copy1.d._if_pc_next_T_1 ? copy1.d.exe_br_target :
                                                      copy1.d._if_pc_next_T_7;
wire [31:0] if_pc_next_2 = copy2.d._if_pc_next_T   ? copy2.d.if_pc_plus4   :
                            copy2.d._if_pc_next_T_1 ? copy2.d.exe_br_target :
                                                      copy2.d._if_pc_next_T_7;

always @(posedge clk) begin
    if (rst) begin
        stall_1          <= 0;
        stall_2          <= 0;
        finish_1         <= 0;
        finish_2         <= 0;
        commit_deviation <= 0;
        addr_deviation   <= 0;
        invalid_program  <= 0;
    end
    else begin
        if (!stall_1 && !stall_2 && copy1.d.exe_reg_valid && copy2.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
        end
        else if (!stall_1 && !stall_2 && copy1.d.exe_reg_valid && !copy2.d.exe_reg_valid) begin
            stall_1 = 1;
            commit_deviation <= 1;
        end
        else if (!stall_1 && !stall_2 && !copy1.d.exe_reg_valid && copy2.d.exe_reg_valid) begin
            stall_2 = 1;
            commit_deviation <= 1;
        end
        else if (stall_1 && !stall_2 && copy2.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
            stall_1 = 0;
        end
        else if (!stall_1 && stall_2 && copy1.d.exe_reg_valid) begin
            if ((mem_valid_1 && mem_valid_2 && (copy1.d.io_dmem_req_bits_addr != copy2.d.io_dmem_req_bits_addr))
               || if_pc_next_1 != if_pc_next_2
               || copy1.c.io_ctl_pc_sel != copy2.c.io_ctl_pc_sel)
                invalid_program = 1;
            stall_2 = 0;
        end

        if (!commit_deviation && mem_addr_1 != mem_addr_2) begin
            addr_deviation <= 1;
        end

        if ((commit_deviation || addr_deviation) && copy1.d.exe_reg_valid)
            finish_1 <= 1;
        if ((commit_deviation || addr_deviation) && copy2.d.exe_reg_valid)
            finish_2 <= 1;
    end
end

endmodule
