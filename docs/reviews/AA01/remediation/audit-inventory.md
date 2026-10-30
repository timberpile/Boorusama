# Frozen input audit inventory — AA01

| Agent | Exact report branch | Pinned head | Observed disposition |
|---|---|---|---|
| 01 | review/AA01/agent-01 | 290c41b9cdcbdfbfbb949c2116899c8cc07374b8 | Manifest: closed at user request; 11 cycles, 12 canonical findings claimed; independent ingestion pending |
| 02 | review/AA01/agent-02 | 737b3e06a0a56ba7938db013df9826d647eff4fe | Final handoff: closed at user request; six static passes, 11 canonical findings claimed; independent ingestion pending |
| 03 | review/AA01/agent-03 | db5834b6f3bf36e712d500e82a66e4ca05164d82 | Final static handoff: two passes, five findings claimed; protocol timing and runtime unverified; no ongoing review stated |

All three discovered agents match the requested batch and repository. The matching-refs response contained all eight AA01/AA02 audit refs and no remediation ref before initialization. No expected agent outside the discovered set was supplied; absence of a declared expected roster is not proof that none exists.

All three configured the same five targets. Stable remediation target IDs:

| Target | Issue | Exact implementation branch | Original audited head |
|---|---|---|---|
| T001 | #113 | bug/113-collection-pagination | a1bc1d42903861a46e7230349515946bae678357 |
| T002 | #114 | feature/114-timeline-toolbar | 5bb52794468b172b7d6878fb825b42b00d654675 |
| T003 | #116 | feature/116-compact-follow-button | 5ac3ad9bc5f852f000012499c19468151c73734b |
| T004 | #117 | feature/117-pixiv-favorites | e2929259b7725c484d11483d6ea48270079eb2f4 |
| T005 | #118 | feature/118-pixiv-following-artists | 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a |

Original common base: `422aeae087c1108e655d85d1a3dac25120456cd6`. Report initialization base: `894ab270693cdb054a5d527c96182e21e2b14ffc`. These are not interchangeable source revisions. Final handoffs and manifests are inventory evidence, not independent validation of their assertions. Detailed reports, cross-branch records and histories remain to be ingested at this checkpoint.
