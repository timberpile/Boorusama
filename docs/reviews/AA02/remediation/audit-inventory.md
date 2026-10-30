# Frozen input inventory and coverage cohorts — AA02

## Audit inputs

All agents selected by `AUDIT_AGENTS=all` discovered under the exact AA02 prefix are included. No declared expected roster outside these refs was provided. All manifests, detailed reports, cross records, summaries and histories have been read at the pinned revisions; no missing file has been silently treated as negative coverage.

| Agent | Pinned audit head | Files read | Source coverage/disposition |
|---|---|---:|---|
| 01 | b00d6d25c5e060cb98632ad93a3a7fa64507fa00 | 30 | 23 first-pass reports including historical/coordination targets; 16 second passes among its 20 active/uncertain targets; closed by user |
| 02 | 5012c4e19783e319c4491ba737517542d0de692c | 27 | 20 first-pass reports including historical #111 and policy branch; 18 active app/tool targets; eight second passes; closed by user |
| 03 | bbc004db66596d082fc4470abbd27f83b2e00250 | 24 | 18 active full first passes, 12 second passes; historical #53/#76/#111 excluded; closed by user |
| 04 | 0df3bc984af5da8dda9b0ef9f419266183f0f70c | 28 | 21 full first passes including historical #53/#76/#111; second passes only #53/#111; coordination targets excluded; closed by user |
| 05 | c658f7c455d39208672aeeac45462c387cbb315d | 25 | 17 active complete first passes plus partial #68; historical #111 separately reviewed; no complete second round; closed by user |

Files total 134. AA01 separately contributes 34 files / three agents. All audit timing requirements remain unverified and all runtime tests unexecuted by their authors; closure does not turn partial second-cycle coverage into a completed audit protocol.

## Stable remediation targets across AA01 and AA02

Repository for every row: **timberpile/Boorusama**. T001–T005 preserve the existing AA01 remediation IDs. A source auditor's local T001 is not this T001. Initial/current observed task refs matched the original reviewed SHAs at discovery; a fresh head/ownership check is mandatory before writing.

Base aliases (exact SHAs): B1=`422aeae087c1108e655d85d1a3dac25120456cd6`; B2=`482ae4b1e5fd1e34b344a5c61959a210b8527281`; B3=`6875e0ce778aecfb2b83780c2185ce9273a9b2cc`; B4=`2e5ca00d7bca6881cfddd19125c72d5f80d9593d`.

| Target | Issue | Exact branch | Audited code head | Base | Cohort |
|---|---|---|---|---|---|
| T001 | #113 | bug/113-collection-pagination | a1bc1d42903861a46e7230349515946bae678357 | B1 | Active app; also AA01 |
| T002 | #114 | feature/114-timeline-toolbar | 5bb52794468b172b7d6878fb825b42b00d654675 | B1 | Active app; also AA01 |
| T003 | #116 | feature/116-compact-follow-button | 5ac3ad9bc5f852f000012499c19468151c73734b | B1 | Active app; also AA01 |
| T004 | #117 | feature/117-pixiv-favorites | e2929259b7725c484d11483d6ea48270079eb2f4 | B1 | Active app; also AA01 |
| T005 | #118 | feature/118-pixiv-following-artists | 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a | B1 | Active app; also AA01 |
| T006 | #92 | bug/92-selection-share-image | e8816c22048b324f00d682b7637c0ab1040147ca | B1 | Active app |
| T007 | #95 | feature/95-artist-links | 7fa4e4f7fadd28cdf332c6855ac18e4fd28b3e9a | B1 | Active app |
| T008 | #68 | feature/group-neighboring-series | 771082d9c58363348d74b97a2da23732cdd921f0 | B2 | Active app; A05 only partial |
| T009 | #112 | feature/112-viewer-toolbar-layout | 8213b6fbb87cb09d30d5056ad6667821371f22f6 | B1 | Active app; UX trial |
| T010 | #107 | feature/107-local-post-sorting | 7a73544cb79c9f5e3c2337a08140833024a31591 | B1 | Active app |
| T011 | #97 | bug/97-follow-destination-identity | 6056bd06cfd7510aec41c00562d7dfd37c8725a7 | B1 | Active app |
| T012 | #98 | bug/98-search-overlay-surface | 89e064d4f86b0acad62c11c96e6a085fe522ccc7 | B1 | Active app |
| T013 | #106 | bug/106-live-undo-toast-insets | ebb9c8ecbbd3841e2546f2b59927a71eeaaf0db8 | B1 | Active app |
| T014 | None established | feat/android-maestro-mvp | 4ae377b842aad4dcb63a0f2685c21eb484f9b3c4 | B2 | Existing tooling pilot; activity/ownership requires confirmation |
| T015 | #91 | feature/91-branded-search-link-share | e8c880c2783fefe5a58b0b73d98bf3914157809f | B1 | Active app |
| T016 | #99 | feature/99-selected-tag-suggestions | 98d4b0ae68dded641475a0662318c56f65b625f7 | B1 | Active app |
| T017 | #104 | feature/104-expanded-details-swipe | 0b7bbb2c9630292eda16bcb769b8ac057199452e | B1 | Active app; UX prototype |
| T018 | #108 | feature/108-selection-action-parity | c6d3e62ed525d7f3298ddf115b46d5d6c3dd01cd | B1 | Active app |
| T019 | #53 | bug/53-realbooru-prefetch-refresh | f7eba53fec0bc0369a9c3e84a8931353c0a8a3cf | B3 | Historical integrated/closed according to input evidence; no write permission inferred |
| T020 | #76 | bug/76-realbooru-original-metadata | b8895d1e142c6b0e86b4a1f7359e7288ecc6fee5 | B3 | Historical integrated/closed according to input evidence; no write permission inferred |
| T021 | #111 | feature/111-android-update-flow | 9ac4dd73b4c505c9c300a0e5fe43bf1ba0d06d07 | B1 | Historical integrated, source ref deleted; never recreate or patch develop |
| T022 | None established | maintenance/independent-issues-handoff-2026-10-25 | 89346f7a2a0e1af187e82fed3c7a10b42813fdec | B4 | Coordination/source-export workflow, read-only evidence |
| T023 | None established | maintenance/issue-branch-publication | fdb89b5c03e438e4d909db1821332e78b6f39ae9 | B1 | Policy proposal, not current instructions; read-only evidence |

Audit comparison develop: `84df0c2de6cf8fe0177c49babb3fb0eee880f866`. Report initialization/current instruction develop: `894ab270693cdb054a5d527c96182e21e2b14ffc`. Audit heads and code heads are distinct; none should be substituted for another.

## Source-local target translation

A01/A03/A04/A05 use the same local numbering where present: source T001→remediation T019; T002→T020; T003→T006; T004→T011; T005→T012; T006→T013; T007→T001; T008→T014; T009→T008; T010→T015; T011→T007; T012→T016; T013→T017; T014→T010; T015→T018; T016→T021; T017→T009; T018→T002; T019→T003; T020→T004; T021→T005; T022→T022; T023→T023.

A02 differs: source T001→T011; T002→T012; T003→T015; T004→T006; T005→T007; T006→T016; T007→T017; T008→T013; T009→T010; T010→T018; T011→T021; T012→T009; T013→T001; T014→T002; T015→T003; T016→T004; T017→T005; T018→T008; T019→T014; T020→T023.

## Publication boundary

No application write is currently unlocked. The initial AA01 allowlist remains the five explicitly scoped tasks; AA02 candidate correction branches are T001/T002/T004/T005/T006/T007/T008/T009/T010, subject to every-claim baseline assessment and fresh ownership/instruction/ref checks. Remaining active targets are retained for claim/coverage/handoff review, not a license for discretionary changes. Historical, protected, coordination and audit branches are excluded from application writes.
