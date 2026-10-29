# Branch inventory — discovery cycle 1

Observed at 2026-10-29T22:38:58.156Z; develop `84df0c2de6cf8fe0177c49babb3fb0eee880f866`. Exact target head SHAs are pinned for initial passes. All listed heads were compared against this develop revision, and each had commits not contained in develop. Existing reported divergences must be checked for inherited versus introduced code. Issue IDs inferred from names pending issue-body verification.

| ID | Branch | Observed head SHA | Issue association | Coverage |
| --- | --- | --- | --- | --- |
| T001 | `bug/53-realbooru-prefetch-refresh` | `f7eba53fec0bc0369a9c3e84a8931353c0a8a3cf` | #53 | Excluded: issue closed, published/superseded |
| T002 | `bug/76-realbooru-original-metadata` | `b8895d1e142c6b0e86b4a1f7359e7288ecc6fee5` | #76 | Excluded: issue closed, published/superseded |
| T003 | `bug/92-selection-share-image` | `e8816c22048b324f00d682b7637c0ab1040147ca` | #92 | Complete static passes 1+2; no actionable finding |
| T004 | `bug/97-follow-destination-identity` | `6056bd06cfd7510aec41c00562d7dfd37c8725a7` | #97 | Complete static passes 1+2; no actionable finding |
| T005 | `bug/98-search-overlay-surface` | `89e064d4f86b0acad62c11c96e6a085fe522ccc7` | #98 | Complete static passes 1+2; no actionable finding |
| T006 | `bug/106-live-undo-toast-insets` | `ebb9c8ecbbd3841e2546f2b59927a71eeaaf0db8` | #106 | Complete static passes 1+2; no actionable finding |
| T007 | `bug/113-collection-pagination` | `a1bc1d42903861a46e7230349515946bae678357` | #113 | Complete static pass 1; source-total risk noted |
| T008 | `feat/android-maestro-mvp` | `4ae377b842aad4dcb63a0f2685c21eb484f9b3c4` | No confirmed issue | Complete static pass 1; pilot unqualified |
| T009 | `feature/group-neighboring-series` | `771082d9c58363348d74b97a2da23732cdd921f0` | #68 | Complete static pass 1; F0005 and cross-branch F0002 |
| T010 | `feature/91-branded-search-link-share` | `e8c880c2783fefe5a58b0b73d98bf3914157809f` | #91 | Complete static pass 1; 0 findings |
| T011 | `feature/95-artist-links` | `7fa4e4f7fadd28cdf332c6855ac18e4fd28b3e9a` | #95 | Complete static pass 1; F0001 low error-path defect |
| T012 | `feature/99-selected-tag-suggestions` | `98d4b0ae68dded641475a0662318c56f65b625f7` | #99 | Complete static pass 1; 0 independent findings |
| T013 | `feature/104-expanded-details-swipe` | `0b7bbb2c9630292eda16bcb769b8ac057199452e` | #104 | Complete static pass 1; 0 actionable findings |
| T014 | `feature/107-local-post-sorting` | `7a73544cb79c9f5e3c2337a08140833024a31591` | #107 | Complete static pass 1; cross-branch F0002 |
| T015 | `feature/108-selection-action-parity` | `c6d3e62ed525d7f3298ddf115b46d5d6c3dd01cd` | #108 | Complete static pass 1; 0 findings |
| T016 | `feature/111-android-update-flow` | `9ac4dd73b4c505c9c300a0e5fe43bf1ba0d06d07` | #111 | Excluded cycle 1: merged/deleted during audit |
| T017 | `feature/112-viewer-toolbar-layout` | `8213b6fbb87cb09d30d5056ad6667821371f22f6` | #112 | Complete static pass 1; 0 findings, UX unverified |
| T018 | `feature/114-timeline-toolbar` | `5bb52794468b172b7d6878fb825b42b00d654675` | #114 | Complete static pass 1; 0 findings |
| T019 | `feature/116-compact-follow-button` | `5ac3ad9bc5f852f000012499c19468151c73734b` | #116 | Complete static pass 1; 0 findings, visual unverified |
| T020 | `feature/117-pixiv-favorites` | `e2929259b7725c484d11483d6ea48270079eb2f4` | #117 | Complete static pass 1; F0003 medium pagination defect |
| T021 | `feature/118-pixiv-following-artists` | `1d02bef637966999fbd0b72ecb9c6f0e1eedce8a` | #118 | Complete static pass 1; F0004 content-rating risk |

## Exclusions

- T016 / #111: at refresh 2026-10-29T23:05:07.268Z, issue closed on 2026-10-29T22:41:47Z. Remote `feature/111-android-update-flow` no longer exists and current develop `894ab270693cdb054a5d527c96182e21e2b14ffc` is a `feat: streamline Android download and install updates (#111)` commit. Original pinned head retained in inventory for reproducibility; no complete static T016 review claimed. Removed from active target count after publication.

- T001 / #53 and T002 / #76: both issues closed on 2026-10-27; issue comments explicitly identify dependency-code publication in develop via commits `c3f83f0bb` and `8920dd2ff`. The old task branch snapshots may not be byte-identical to current develop; this is an activity/scope exclusion, **not** a claim of branch equivalence or independent acceptance of the final integrated code. Retained rows preserve the discovery trail.

- `feature/55-undo-reversible-actions` at `482ae4b1e5fd1e34b344a5c61959a210b8527281`: ancestor of develop (compare ahead=0), no outstanding branch delta.
- `develop`, `master`: integration/release branches.
- `review/AA01/agent-01`, `review/AA01/agent-02`, `review/AA01/agent-03`: other audit reports, never used as evidence.
- `maintenance/feature-review-notes-2026-10-20`, `maintenance/independent-issues-handoff-2026-10-25`, `maintenance/issue-branch-publication`: documentation/coordination branches, not implementation targets; revisit status if actual code work appears.

## Caveats

- Branch status is assessed from pinned Git ancestry, not labels alone. No open PRs were returned at discovery.
- 18 active implementation branches at latest discovery: all 18 have one complete static pass at recorded head SHA. T001, T002 and T016 are historical/excluded; they are not counted. All exact target heads were unchanged at the latest discovery; report contains no claim of runtime acceptance.
- Issue requirements and relevant comments were inspected branch by branch. Cross-branch integration and local runtime checks remain unresolved. Diff coverage for #68 was corrected to 69 introduced paths relative to its merge-base (not 75 against moving develop).
- Scope refreshed after #111 was integrated; remote branch list now includes other independent audit report branches that are deliberately excluded without reading their findings.
