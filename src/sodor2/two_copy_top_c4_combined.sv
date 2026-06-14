`include "src/sodor2/param.vh"
`include "src/sodor2/sodor_2_stage.sv"
`include "src/sodor2/interrupt_controller.v"

// =============================================================================
// Sodor-S + Interrupt Controller: Combined Verification under C4
// =============================================================================
// Sodor Core with PMP constraint + real interrupt controller module.
// PMP: stores to periph_range must not carry secret data.
// Expected: PASS (PMP blocks secret → interrupt path)
// =============================================================================

`define PERIPH_START 0
`define PERIPH_END   1

module top(
    input clk,
    input rst
);

// =========================================================================
// Unconstrained platform inputs
// =========================================================================
wire         io_imem_resp_valid_shared;
wire  [31:0] io_imem_resp_bits_data_shared;
wire         io_dmem_resp_valid_shared;
wire  [31:0] io_dmem_resp_bits_data_shared;

// =========================================================================
// Interrupt controllers (one per copy, driven by CPU store)
// =========================================================================

// Detect store to periph_range for each copy
wire store_valid_1 = copy1.io_dmem_req_valid & copy1.io_dmem_req_bits_fcn &
                     (copy1.io_dmem_req_bits_addr[31:2] >= `PERIPH_START) &
                     (copy1.io_dmem_req_bits_addr[31:2] < `PERIPH_END);
wire store_valid_2 = copy2.io_dmem_req_valid & copy2.io_dmem_req_bits_fcn &
                     (copy2.io_dmem_req_bits_addr[31:2] >= `PERIPH_START) &
                     (copy2.io_dmem_req_bits_addr[31:2] < `PERIPH_END);

interrupt_controller intctrl_1(
    .clk(clk), .rst(rst),
    .wr_valid(store_valid_1),
    .wr_data(copy1.io_dmem_req_bits_data),
    .interrupt()
);

interrupt_controller intctrl_2(
    .clk(clk), .rst(rst),
    .wr_valid(store_valid_2),
    .wr_data(copy2.io_dmem_req_bits_data),
    .interrupt()
);

// =========================================================================
// Core instantiation
// =========================================================================
reg stall_1, stall_2, finish_1, finish_2, commit_deviation, addr_deviation, invalid_program;

Core copy1(
    .clock(stall_1 ? 1'b0 : clk),
    .reset(rst),
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    .io_dmem_resp_valid(io_dmem_resp_valid_shared),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_shared),
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(intctrl_1.interrupt),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

Core copy2(
    .clock(stall_2 ? 1'b0 : clk),
    .reset(rst),
    .io_imem_resp_valid(io_imem_resp_valid_shared),
    .io_imem_resp_bits_data(io_imem_resp_bits_data_shared),
    .io_dmem_resp_valid(io_dmem_resp_valid_shared),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data_shared),
    .io_interrupt_debug(1'b0),
    .io_interrupt_mtip(1'b0),
    .io_interrupt_msip(1'b0),
    .io_interrupt_meip(intctrl_2.interrupt),
    .io_hartid(1'b0),
    .io_reset_vector(32'b0)
);

// =========================================================================
// Shadow Logic (standard, same as C2)
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
