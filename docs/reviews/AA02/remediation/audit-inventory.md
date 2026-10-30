# Frozen input audit inventory — AA02

| Agent | Exact report branch | Pinned head | Observed disposition and claimed coverage |
|---|---|---|---|
| 01 | review/AA02/agent-01 | b00d6d25c5e060cb98632ad93a3a7fa64507fa00 | Closed by user; 23 first passes including historical targets, 20 active, 16 second passes; four canonical findings claimed |
| 02 | review/AA02/agent-02 | 5012c4e19783e319c4491ba737517542d0de692c | Closed by user; 20 first passes, 18 active runtime targets, eight second passes; four canonical findings claimed |
| 03 | review/AA02/agent-03 | bbc004db66596d082fc4470abbd27f83b2e00250 | Final handoff closed by user; 18 active first passes, 12 second passes; five canonical findings claimed |
| 04 | review/AA02/agent-04 | 0df3bc984af5da8dda9b0ef9f419266183f0f70c | Closed by user; 21 first passes, 20 active, two second passes; five canonical findings claimed |
| 05 | review/AA02/agent-05 | c658f7c455d39208672aeeac45462c387cbb315d | Closed by user; 18 active targets, 17 full and one partial static pass; four canonical findings claimed |

All five match the selected repository and batch. Each configured all implementation branches, but scope differs because obsolete/historical branches and documentation-only branches were handled differently. Do not infer identical denominators or sum these assertions as validated findings. Original audited implementation SHAs and exact target eligibility remain to be reconciled from the detailed inventories.

All five audits have an explicit closed/final reporting disposition. Timing criteria were not demonstrated; no runtime tests are claimed. An incomplete second cycle is not negative evidence. The matching-refs response contained all eight AA01/AA02 audit refs; no additional expected roster was provided. Detailed reports, cross-branch records, summaries and histories remain to be ingested at this checkpoint.
