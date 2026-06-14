# 补充实验结果导出

日期: 2026-04-01

## 一、Sodor-S (PMP) 补充实验

### 1. Sodor-S CPU_TCI(C1)
- 验证文件: src/sodor2/two_copy_top_c1.sv + PMP assume
- TCL 脚本: verification/verify_2_copy_c1_sodor2_pmp.tcl
- 验证引擎: AM
- 结果: **Proven**
- 验证时间: **4.63s**
- 备注: commit_deviation unreachable，PMP 对 C1 无影响

### 2. Sodor-S CPU_TCI(C2)
- 验证文件: src/sodor2/two_copy_top_c2.sv + PMP assume
- TCL 脚本: verification/verify_2_copy_c2_sodor2_pmp.tcl
- 验证引擎: AM
- 结果: **Proven**
- 验证时间: **6.14s**
- 备注: commit_deviation unreachable，PMP 对 C2 无影响

---

## 二、SimpleOoO (NoFwd) C3 补充实验

### 3. SimpleOoO CPU_TCI(C3)
- 验证文件: src/simpleooo/two_copy_top_ct_ptci_c3.v
- TCL 脚本: verification/verify_nofwd_ct_ptci_c3_simpleooo.tcl
- 防御策略: NoFwd (USE_DEFENSE_PARTIAL_STT + PARTIAL_STT_USE_SPEC)
- 验证引擎: Ht
- 结果: **CEX (counterexample)**
- 反例周期: **11 cycles**
- 验证时间: **0.07s**
- Cover 可达性:
  - sticky_dmem_addr — covered in 7 cycles
  - sticky_wr_data — covered in 8 cycles
  - sticky_wr_data_periph — covered in 8 cycles
  - allow_timing_diff — covered in 7 cycles
  - allow_int_diff — covered in 8 cycles
  - commit_deviation — covered in 9 cycles
  - copy1.interrupt_taken — covered in 4 cycles
  - copy2.interrupt_taken — covered in 4 cycles

---

## 三、SimpleOoO-S (Delay) C3 补充实验

### 4. SimpleOoO-S CPU_TCI(C3)
- 验证文件: src/simpleooo/two_copy_top_ct_ptci_c3.v
- TCL 脚本: verification/verify_delay_ct_ptci_c3_simpleooo.tcl
- 防御策略: Delay (USE_DEFENSE_PARTIAL_DOM)
- 验证引擎: Ht
- 结果: **CEX (counterexample)**
- 反例周期: **11 cycles**
- 验证时间: **0.06s**
- Cover 可达性:
  - sticky_dmem_addr — covered in 7 cycles
  - sticky_wr_data — covered in 8 cycles
  - sticky_wr_data_periph — covered in 8 cycles
  - allow_timing_diff — covered in 7 cycles
  - allow_int_diff — covered in 8 cycles
  - commit_deviation — covered in 9 cycles
  - copy1.interrupt_taken — covered in 4 cycles
  - copy2.interrupt_taken — covered in 4 cycles

---

## 四、对照实验：中断机制对 C2 安全性的影响

### 5. SimpleOoO-S (Delay + int_shared) CPU_TCI(C2)
- 验证文件: src/simpleooo/two_copy_top_ct_ptci_c2_int_shared.v
- TCL 脚本: verification/verify_delay_c2_int_shared.tcl
- 防御策略: Delay + 无约束共享中断
- 验证引擎: Ht
- 结果: **CEX (counterexample)**
- 反例周期: **14 cycles**
- 验证时间: **3.02s**
- 备注: Delay 原本通过 C2 (8118s Proven)，加入无约束中断后 C2 也 FAIL

### 6. SimpleOoO-S (Delay + interrupt=0) CPU_TCI(C2)
- 验证文件: src/simpleooo/two_copy_top_ct_ptci_c2_int0.v
- TCL 脚本: verification/verify_delay_c2_int0.tcl
- 防御策略: Delay + 中断接地
- 验证引擎: AM
- 结果: **Proven**
- 验证时间: **8805.85s**
- 备注: interrupt=0 时等价于原始设计，确认硬件改动本身不破坏 C2 安全性

### 对照实验结论

| 配置 | 结果 | 时间 | 含义 |
|------|------|------|------|
| Delay（无中断硬件）C2 | PASS | 8118s | 基线 |
| Delay（有中断硬件）interrupt=0, C2 | PASS | 8806s | 硬件改动无害 |
| Delay（有中断硬件）int_shared, C2 | FAIL (14cyc) | 3.02s | 无约束中断是时序放大器 |

**根因：中断信号作为无约束外部输入，可在一个副本提交而另一个未提交的精确时刻触发 flush，将内部时序差异放大为可观测的提交偏差。**

---

## 五、完整 CPU_TCI 结果矩阵

| 处理器 | CPU_TCI(C1) | CPU_TCI(C2) | CPU_TCI(C3) |
|--------|-------------|-------------|-------------|
| SimpleOoO (NoFwd) | PASS (652s) | FAIL (33s, 16cyc) | FAIL (0.07s, 11cyc) * |
| SimpleOoO-S (Delay) | PASS (207s) | PASS (8118s) | FAIL (0.06s, 11cyc) * |
| Sodor | PASS (4.82s) | PASS (7.76s) | FAIL (0.44s, 7cyc) |
| Sodor-S (PMP) | PASS (4.63s) * | PASS (6.14s) * | PASS (5.08s) |

标 * 为本次补充实验

---

## 六、更新后的兼容性矩阵

| 处理器 | Regular Cache (满足 C2) | Cache-S (满足 C1) | 中断控制器 (满足 C3) |
|--------|------------------------|--------------------|--------------------|
| SimpleOoO (满足 C1) | × | ✓ (C1) | × * |
| SimpleOoO-S (满足 C2) | ✓ (C2) | ✓ (C1) | × * |
| Sodor (满足 C2) | ✓ (C2) | ✓ (C1) | × |
| Sodor-S (满足 C3) | ✓ (C2) | ✓ (C1) | ✓ (C3) |

标 * 为本次补充实验填充的空位

---

## 七、新增文件清单

### 修改文件
- `src/simpleooo/cpu_ooo_ext_mem.v` — 新增 interrupt/interrupt_taken 端口

### 新建文件
- `src/simpleooo/two_copy_top_ct_ptci_c3.v` — C3 验证顶层
- `src/simpleooo/two_copy_top_ct_ptci_c2_int0.v` — C2 对照（interrupt=0）
- `src/simpleooo/two_copy_top_ct_ptci_c2_int_shared.v` — C2 对照（int_shared）
- `verification/verify_nofwd_ct_ptci_c3_simpleooo.tcl` — NoFwd C3 脚本
- `verification/verify_delay_ct_ptci_c3_simpleooo.tcl` — Delay C3 脚本
- `verification/verify_delay_ct_ptci_c3_simpleooo_pmp.tcl` — Delay+PMP C3 脚本
- `verification/verify_2_copy_c1_sodor2_pmp.tcl` — Sodor-S C1 脚本
- `verification/verify_2_copy_c2_sodor2_pmp.tcl` — Sodor-S C2 脚本
- `verification/verify_delay_c2_int0.tcl` — 对照实验 A 脚本
- `verification/verify_delay_c2_int_shared.tcl` — 对照实验 B 脚本
