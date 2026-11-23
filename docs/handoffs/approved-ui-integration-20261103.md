# Approved Bookmark and UI integration — 2026-11-03

The user accepted the combined UI test stand and explicitly authorized merge.
Integrate the accepted snapshot `161f78dbd` as one Conventional Commit on local
`develop`, based on fetched `origin/develop` `02b0d60e9`, then publish to
`origin/develop`. No PR or release is involved.

## Scope and issue disposition

Complete #139 (Related families and ordering/feedback/cards), #145 (shared Kurumi
picker workflow/rules), #149 (Pool Gallery Header inset), #150 (leading context
icons), #151 (4 dp grid defaults) and #152 (membership dates, responsive writes,
directional All ordering and v9 backup output with v4–v9 readers).

Include #136's approved documentation/evidence and audit tooling. Keep #136 open
and retain its branch/worktree: Penpot's component/state studies and canonical
screen acceptance remain separate unfinished work. #105/#112/#146/#147/#148 are
outside this runtime integration and are not closed or cleaned up.

The source implementation branches and combined test branch are superseded after
verified publication; remove their clean task worktrees and exact local/remote
branches under the repository workflow. Retain durable logs/captures under
`.worktrees/_artifacts/`. The primary checkout is clean, detached at the approved
snapshot, and remains untouched. Local develop is advanced through an isolated
integration checkout. No device reset or new review APK is required.

## Verification reuse

- The staged squash tree before this handoff exactly matches the approved tree.
- The checked runtime/test candidate is
  `e1e04d8c0e7100136b82b682ea159a4edb5f0b0d`; later accepted changes are documentation
  only. Runtime, tests, packages, dependencies, generated tracked runtime output,
  platform files and tooling are compared to that candidate before publication.
- Complete final regression: **6,161 app tests; 1,661 package/CLI tests across
  13 suites; both shell suites; 76 Python tests; REGRESSION_EXIT=0**.
  Two pre-existing go_router skips remain. Format 94 Dart paths: 0 changes.
  Affected analysis: 0 errors, 0 warnings, 122 infos, nonfatal-infos exit 0.
- Reuse that unchanged-candidate complete pass; no redundant application rerun
  for this integration/handoff is needed. Check handoff links and final diff.
- User acceptance covers the reviewed UI behavior. The host 20,000-member read
  experiment is performance evidence for the corrected decoding segment, not
  independent Android frame-time measurement. No new device QA is performed
  during integration. Earlier branch device checks retain their stated limits.

## Retained evidence

Current behavior: [All/membership dates and v9](152-all-membership-order-20261103.md),
[responsiveness](152-related-bookmark-responsiveness-20261103.md),
[picker](145-rounded-search-final-20261103.md),
[combined candidate](ui-combined-test-20261103.md).
The older local-only and pending-device statements in those handoffs describe
historical milestones; this user acceptance/merge authorization supersedes their
local delivery boundary. Publication hash and actual issue/cleanup outcome are
recorded in the final report and issue comments after remote verification.

Durable integration evidence:
`.worktrees/_artifacts/approved-ui-integration-20261103/`.
Original full log:
`.worktrees/_artifacts/related-bookmark-responsiveness/combined-verification.log`.
