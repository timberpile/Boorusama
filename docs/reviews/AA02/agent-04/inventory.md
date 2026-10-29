# Scope inventory

Discovery: 2026-10-29T22:39:57.065Z UTC; `develop` 84df0c2de6cf8fe0177c49babb3fb0eee880f866. Cycle 1 frozen target list. Branches below have commits not incorporated in `develop` as of discovery. `head` is the observed SHA, and `merge-base` is the pinned shared history of `develop` and that head; `develop` has advanced, so branch comparison is against merge-base. Branch activity and any unclear issue associations require reconfirmation.

| ID | Exact branch | Issue | Head SHA | Merge-base SHA | Coverage |
|---|---|---|---|---|---|
| T001 | `bug/53-realbooru-prefetch-refresh` | #53 | `f7eba53fec0bc0369a9c3e84a8931353c0a8a3cf` | `6875e0ce778aecfb2b83780c2185ce9273a9b2cc` | Complete static C1; F0001 |
| T002 | `bug/76-realbooru-original-metadata` | #76 | `b8895d1e142c6b0e86b4a1f7359e7288ecc6fee5` | `6875e0ce778aecfb2b83780c2185ce9273a9b2cc` | Complete static C1; F0002 |
| T003 | `bug/92-selection-share-image` | #92 | `e8816c22048b324f00d682b7637c0ab1040147ca` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T004 | `bug/97-follow-destination-identity` | #97 | `6056bd06cfd7510aec41c00562d7dfd37c8725a7` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T005 | `bug/98-search-overlay-surface` | #98 | `89e064d4f86b0acad62c11c96e6a085fe522ccc7` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T006 | `bug/106-live-undo-toast-insets` | #106 | `ebb9c8ecbbd3841e2546f2b59927a71eeaaf0db8` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T007 | `bug/113-collection-pagination` | #113 | `a1bc1d42903861a46e7230349515946bae678357` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T008 | `feat/android-maestro-mvp` | Unverified/none | `4ae377b842aad4dcb63a0f2685c21eb484f9b3c4` | `482ae4b1e5fd1e34b344a5c61959a210b8527281` | Complete static C1; no finding; activity provisional |
| T009 | `feature/group-neighboring-series` | #68 | `771082d9c58363348d74b97a2da23732cdd921f0` | `482ae4b1e5fd1e34b344a5c61959a210b8527281` | Complete static C1; F0003 (policy-sensitive) |
| T010 | `feature/91-branded-search-link-share` | #91 | `e8c880c2783fefe5a58b0b73d98bf3914157809f` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T011 | `feature/95-artist-links` | #95 | `7fa4e4f7fadd28cdf332c6855ac18e4fd28b3e9a` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T012 | `feature/99-selected-tag-suggestions` | #99 | `98d4b0ae68dded641475a0662318c56f65b625f7` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T013 | `feature/104-expanded-details-swipe` | #104 | `0b7bbb2c9630292eda16bcb769b8ac057199452e` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding; device UX gate |
| T014 | `feature/107-local-post-sorting` | #107 | `7a73544cb79c9f5e3c2337a08140833024a31591` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T015 | `feature/108-selection-action-parity` | #108 | `c6d3e62ed525d7f3298ddf115b46d5d6c3dd01cd` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T016 | `feature/111-android-update-flow` | #111 | `9ac4dd73b4c505c9c300a0e5fe43bf1ba0d06d07` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; F0004; branch deleted after integration |
| T017 | `feature/112-viewer-toolbar-layout` | #112 | `8213b6fbb87cb09d30d5056ad6667821371f22f6` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding; device UX gate |
| T018 | `feature/114-timeline-toolbar` | #114 | `5bb52794468b172b7d6878fb825b42b00d654675` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T019 | `feature/116-compact-follow-button` | #116 | `5ac3ad9bc5f852f000012499c19468151c73734b` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding; device UX gate |
| T020 | `feature/117-pixiv-favorites` | #117 | `e2929259b7725c484d11483d6ea48270079eb2f4` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; F0005 |
| T021 | `feature/118-pixiv-following-artists` | #118 | `1d02bef637966999fbd0b72ecb9c6f0e1eedce8a` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Complete static C1; no finding |
| T022 | `maintenance/independent-issues-handoff-2026-10-25` | Unverified/none | `89346f7a2a0e1af187e82fed3c7a10b42813fdec` | `2e5ca00d7bca6881cfddd19125c72d5f80d9593d` | Excluded: temporary audit source export workflow; no app feature |
| T023 | `maintenance/issue-branch-publication` | Unverified/none | `fdb89b5c03e438e4d909db1821332e78b6f39ae9` | `422aeae087c1108e655d85d1a3dac25120456cd6` | Excluded: unmerged policy/docs proposal only |

## Exclusions / unresolved candidates

- `develop` and `master`: protected integration/release branches.
- `review/AA01/agent-01`, `review/AA01/agent-02`, `review/AA01/agent-03`: other audits; intentionally not opened.
- `feature/55-undo-reversible-actions`: ahead of `develop` by 0 commits; its head is an ancestor of `develop` (observed comparison), so no unfinished branch changes to inspect.
- `maintenance/feature-review-notes-2026-10-20`: historical design/review notes rather than an implementation change; excluded pending any evidence of unfinished active work. Its source was not read.
- `feat/android-maestro-mvp` and the two maintenance branches remain provisionally included because unmerged changes exist despite lacking confirmed issue associations. Their activity should be checked before final scope closure.

Refresh branch discovery at the start of each new cycle; never silently delete historical targets.

## Cycle 2 discovery — 2026-10-29T23:27:27.165Z UTC

- Live `develop`: `894ab270693cdb054a5d527c96182e21e2b14ffc` (advanced from initial `84df0c2de6cf8fe0177c49babb3fb0eee880f866` by an application update integration commit). Issue #111 is now closed and its original `feature/111-android-update-flow` branch was removed. The pinned T016 review remains historical evidence; the update dialog's F0004 source path persists on this new `develop` revision and should be revalidated in a separate cycle-2 branch pass.
- Branch listing pagination: page 1 contained 34 branch records; page 2 was empty. No new eligible implementation branch was discovered; all 20 still-remote, eligible implementation branches retain their originally pinned head SHAs. The latest active target scope is the previously reviewed 20 remote branches; T016 remains a completed historical reviewed target but not a current implementation branch. Other `review/AA02/*` agents' documentation was not opened.
- T022 `maintenance/independent-issues-handoff-2026-10-25` is now **excluded**: the only change is a temporary, read-only source-bundle GitHub Actions workflow triggered only on its own maintenance branch; it is audit infrastructure, not an unfinished app/issue implementation branch. Its workflow contents were inspected solely for scope classification, and the workflow was not executed.
- T023 `maintenance/issue-branch-publication` is now **excluded**: it proposes workflow-policy Markdown changes and one implementation handoff, without app code or an implementation issue. It is separate governance documentation, not in-scope issue work. Existing `develop` instructions remain authoritative; source was inspected solely for classification.
- Both T022/T023 remain in the table as historical provisional discovery entries, never silently deleted. Earlier excluded `feature/55-undo-reversible-actions` remains ancestor of current `develop`; its changes are no longer a separate incomplete feature branch.
- Cycle 1 initial source inspection is now accounted for **21 eligible implementation/tooling branches**: T001–T021. T022–T023 were reclassified out of scope. All 21 received individually published source-level review reports at recorded revisions; one (#111) has since been merged and removed.
- Cycle 2 coverage is **not complete**: beginning adversarial revalidation of the original target set. Active-work-hour minimum remains unverified/unmet; there is no guaranteed 5-hour measurement and no background continuation.
