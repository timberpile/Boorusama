# AA02 source provenance map

## Partial ingestion checkpoint — not a validation verdict

All report files for AA02 agents 01 and 02 have been read at their pinned revisions: 30 and 27 files respectively, including every branch report, cross-branch record, inventory, manifest, README, final summary/handoff and complete review log. All five AA02 manifests and inventories were read. Agent 03's final handoff was read, but its detailed reports and those of agents 04/05 remain to be ingested. Do not interpret this partial map as all-agent coverage or a completed baseline assessment.

The implementation-edit gate remains closed. No application code, issues, local tests or CI runs have been changed/executed. The table preserves auditor claims; independent requirements, original/current code and counter-evidence checks remain pending. Unnumbered observations are retained below for indexing; no validated-defect total is asserted.

## Frozen source identities

| Agent | Exact audit branch | Pinned audit SHA |
|---|---|---|
| AA02-A01 | review/AA02/agent-01 | b00d6d25c5e060cb98632ad93a3a7fa64507fa00 |
| AA02-A02 | review/AA02/agent-02 | 5012c4e19783e319c4491ba737517542d0de692c |
| AA02-A03 | review/AA02/agent-03 | bbc004db66596d082fc4470abbd27f83b2e00250 |
| AA02-A04 | review/AA02/agent-04 | 0df3bc984af5da8dda9b0ef9f419266183f0f70c |
| AA02-A05 | review/AA02/agent-05 | c658f7c455d39208672aeeac45462c387cbb315d |

All source paths below are relative to `docs/reviews/AA02/agent-<ID>/` at the corresponding pinned SHA. Original source finding IDs are anchors within the indicated file; later cycle sections preserve their histories. Full repository identity is `timberpile/Boorusama`. Source-local target IDs differ between agents and are never an implementation identity.

## Numbered claims ingested so far

All eight source findings below remain retained/open in their source audits. Counts and confidence are not votes on correctness. Stable canonical identifiers are reserved here; shared AA01 causes retain their existing IDs rather than being counted again under a new batch ID.

| Original ID | Canonical source path / source-local target | Exact implementation branch and code SHA | Original kind / severity / confidence | Canonical record(s) | Preserved trigger and assessment boundary |
|---|---|---|---|---|---|
| AA02-A01-F0001 | branches/T009.md / T009 | feature/group-neighboring-series @ 771082d9c58363348d74b97a2da23732cdd921f0 (#68) | defect / medium / static-confirmed | AA02-C0001 | Same-host A/B profiles share Pool identity; B can mutate/remove A's group reference. Source itself acknowledges the shared-vs-account-bound identity policy is not explicit. No speculative persistence migration. |
| AA02-A01-F0002 | branches/T009.md / T009 | feature/group-neighboring-series @ 771082d9c58363348d74b97a2da23732cdd921f0 (#68) | defect / medium / static-confirmed | AA02-C0002 | Membership warming admits only the first 40 saved Posts, not later visible entries. Preserve no-scroll-admission, cached-prefix, filter/source and frozen-anchor variants. |
| AA02-A01-F0003 | branches/T021.md / T021 | feature/118-pixiv-following-artists @ 1d02bef637966999fbd0b72ecb9c6f0e1eedce8a (#118) | risk / low / suspected | AA01-C0003; AA02-C0003 | Split: unknown age restriction defaults safe (existing rating cause); independently missing visible/isMuted flags are accepted. Actual endpoint guarantees remain unknown; do not claim an observed content leak. |
| AA02-A01-F0004 | branches/T020.md / T020; cross-branch-findings.md reference | feature/117-pixiv-favorites @ e2929259b7725c484d11483d6ea48270079eb2f4 (#117); bug/113-collection-pagination @ a1bc1d42903861a46e7230349515946bae678357 (#113 dependency) | defect / medium / static-confirmed | AA01-C0001 | Empty first/intermediate cursor page ends the old Grid; final nonempty page permits another request. Session correctness in cycle 1 was not end-to-end consumer coverage; cycle 2 corrects that implication. |
| AA02-A02-F0001 | branches/T012.md / T012 | feature/112-viewer-toolbar-layout @ 8213b6fbb87cb09d30d5056ad6667821371f22f6 (#112) | risk / medium / high-confidence | AA02-C0004 | New button-list identity closes More on benign favorite/vote provider rebuilds. Existing test deliberately closes on callback change; stale-source safety must not be removed as a shortcut. |
| AA02-A02-F0002 | branches/T018.md / T018 | feature/group-neighboring-series @ 771082d9c58363348d74b97a2da23732cdd921f0 (#68) | defect / medium / static-confirmed | AA02-C0002 | Same first-40 admission cause; preserve requirement to skip cached entries before filling a bounded window and avoid scanning the entire library. |
| AA02-A02-F0003 | branches/T018.md / T018 | feature/group-neighboring-series @ 771082d9c58363348d74b97a2da23732cdd921f0 (#68) | risk / medium / high-confidence | AA02-C0001 | Same site-only identity; additional symptom: B's saved group remains bound to A and cannot open after A is removed. Strict no-auth-fallback is correct. Auditor explicitly leaves product identity undecided, unlike A01's defect label. |
| AA02-A02-F0004 | cross-branch-findings.md; branches/T014.md, branches/T009.md references | feature/114-timeline-toolbar @ 5bb52794468b172b7d6878fb825b42b00d654675 (#114); feature/107-local-post-sorting @ 7a73544cb79c9f5e3c2337a08140833024a31591 (#107 consumer) | defect / medium / static-confirmed; pre-existing | AA01-C0022 | Numeric-only blacklist matches allegedly collapse siteA#42/siteB#42 in the mixed Cached Feed. One-matches and both-match variants have different visible effects. AA01's previously rejected RawPostScope/Bookmarks trigger does not disprove this different Feed path. Independently verify the Feed blacklist wiring before accepting or rejecting the shared cause. |

Eight numbered originals currently produce nine atomic source-to-cause links and seven provisional unique causes. These figures exclude the three not-yet-ingested agents and additional unnumbered observations. No full-batch denominator or defect total is inferred.

## Revision and coverage cohorts

- The #68 original merge-base is `482ae4b1e5fd1e34b344a5c61959a210b8527281`; the remaining numbered-claim branches above share `422aeae087c1108e655d85d1a3dac25120456cd6`. Original AA02 comparison develop was `84df0c2de6cf8fe0177c49babb3fb0eee880f866`, later observed `894ab270693cdb054a5d527c96182e21e2b14ffc`. None is interchangeable with a task head.
- A01: 23 scoped first passes, including historical #53/#76/#111 and two coordination/tooling branches; 16 second passes among its 20 active/uncertain targets.
- A02: 20 scoped first passes, including historical #111 and a policy-only branch; 8 second passes among 18 active implementation/tooling targets.
- A03/A04/A05 inventories use different historical exclusions; A05's #68 review is partial. Full common-branch coverage and per-defect applicability still require the remaining detail reports.
- A01/A02 complete source passes are not runtime tests. A missing second cycle is a coverage limitation, not evidence of absence. The five-hour audit protocol was not substantiated; this remediation assignment has no runtime quota.

## Unnumbered observations preserved for final indexing

These source locations are retained now and will receive explicit ingestion references/dispositions in the completed map. Ordinary acceptance checklists remain branch coverage, not invented defects.

- A01 T001: slow obsolete speculative prefetch can delay later speculative work; auditor treats serialization as intentional and says foreground detail fetch is independent. A01 T002: plain Size/Resolution labels assumed original metadata; live conflicting HTML fixture absent. These may be relevant counter-evidence for A04's still-unread historical findings.
- A01 T003 and A02 T004: stored original-URL correctness is inherited; separately, Image fallback preferring original over thumbnail is a quality/transfer-size trade-off, not an established #92 defect.
- A01 T003/T015: apparent missing await in Share was disproved by ShareService.sharePost returning void. A02 T001: navigating a childless folder by trailing chevron is an inherited out-of-scope observation, not attributed to keyed checkbox changes.
- A01 T006: toast surviving root notifier teardown is a hypothetical lifecycle scenario, not a demonstrated crash. A01/A02 #106 reports: actual Android keyboard/OKToast host behavior is an explicit manual acceptance gap despite simulated-host widget tests.
- A01 T017's defensive More closure note maps to AA02-C0004. A02 T012 cycle 2 rejects a disabled vote bypass because the menu passes onTap:null when removal is unavailable.
- A02 T009: newest/oldest means upload createdAt rather than cached-at; no contrary product contract established. Its review-log cycle 2 rejects stale local sorting because a filter-keyed PostScope is recreated.
- A02 T006: desktop initial query-matcher ownership is unchanged; no introduced #99 failure established. Both agents note response-local alias knowledge cannot infer absent server alias relationships.
- A02 T010: unresolved-account local bookmark mutations are a policy question; empty fallback auth is not used to derive origin identity or send credentials.
- A02 T016: mismatched stored Pixiv account metadata and token could target another account's public favorites; login metadata establishment is inherited and no occurrence is established. A02 T017: first-three preview admission may omit later eligible images, but the bounded up-to-three design does not promise all slots are filled; its own cycle-2 log explicitly retains that boundary.
- A01 T008/A02 T019: unqualified Maestro YAML, source/APK equivalence not automatically authenticated, and heuristic credential scanning are explicitly documented limits. No runner, reset, workflow or device command is authorized/executed by this remediation checkpoint.
- A01 T022: a full source bundle can contain already-committed historical secrets; no actual disclosure established and no workflow launch authorized. A02 T020: ambiguous 'work through issues' wording does not override a planning-only/no-push assignment or current develop instructions.
- Cross-branch checkpoints: #68/#107 mixed typed sorting; #92/#108 share; #104/#106/#112 viewer/overlay/gesture ownership; #114/#116/#106 responsive chrome; #117/#118 shared Pixiv client/options/navigation. These are not assertions of an already merged failing candidate. Shared Pixiv integration is AA01-C0017; other explicit claims will be reconciled with A03–A05 before final counting.

## Next exact action

Read all remaining AA02 A03/A04/A05 detailed reports, cross-branch records and histories at the frozen SHAs; resolve every original claim and unnumbered observation into the final source map. Then finish independent original/current source checks, concrete decisions and coverage/assessment matrices before any application edits. Read current ownership and applicable instructions again immediately before each authorized branch write.
