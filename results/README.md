# Historical Results

The raw JasperGold project databases and terminal logs are intentionally not
included. The following values were extracted from historical development runs.

| Method | Verification object | Result | Time |
| --- | --- | --- | --- |
| Decomposed | Sodor under C1 | Proven | 4.82 s |
| Decomposed | Sodor under C2 | Proven | 7.76 s |
| Decomposed | Sodor under C4 without PMP | Counterexample | 0.44 s |
| Decomposed | Sodor under C4 with PMP | Proven | 8.13 s |
| Full system | Sodor + regular cache under C2 | Proven | 25.30 s |
| Full system | Sodor + interrupt controller under C4 without PMP | Timeout | 604800.31 s |
| Full system | Sodor + interrupt controller under C4 with PMP | Proven | 1.70 s |

The C4 baseline full-system run without PMP reached the configured seven-day
time limit and remained undetermined. The decomposed core-side run found the
corresponding incompatibility quickly.
