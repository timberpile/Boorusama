# Approved issue integration - 2026-11-18

The owner accepted #121, #122, #131, #147, #168, #169, #170, #171 and #174
and authorized their integration into develop. #96 was explicitly left pending;
#146 and #175 are investigation-only. Unlisted work, including #134, is excluded.
The primary detached preview checkout remains untouched.

## Approved source revisions

| Issue | Source branch | Accepted source revision |
| --- | --- | --- |
| #121 | `bug/121-export-folder-labels` | `2d001500207775577c913d1a271b8bce227dbaab` |
| #122 | `bug/122-profile-reordering` | `0f5c1c9ec76d99707c474a3f0181b0cec2772b95` |
| #131 | `bug/131-favorites-header-scroll` | `ed8b7b66de83b824fe30e741875e4f5603d31913` |
| #147 | `bug/147-timeline-system-bars` | `586be27c62b1539abdbe7d91e9b12d5e8bf5cbe3` |
| #168 | `feature/168-double-tap-corner-focus` | `c77bd6ccc6f20dd83a63055aa6edb9cf8285a166` |
| #169 | `bug/169-pixiv-refresh-state` | `a0cc70501702cef4b8082cb0a41c9cb52818bd64` |
| #170 | `feature/170-following-topics-added-sort` | `3bd9dd97df3f5e5ddf051d1f1086b0b207f07da3` |
| #171 | `feature/171-short-informational-toasts` | `8cdc963a41b8f00e7ce0db79023685f24ea25c05` |
| #174 | `bug/174-pixiv-work-grouping` | `bc8434c60d50b62ddbd7a3ece9097297f593cbf8` |

Base: `a9ce9de09e4a9d8c994c24804d7c65ef8cefe270` from origin/develop.
Each accepted branch was squash-integrated as its own issue-linked Conventional
Commit. #170 includes its local accepted label simplification beyond the earlier
remote tip: Manual, Name, Unread First and Recently Added. Removed oldest-first
values fall back to Manual; feed-member sorting is unchanged.

The automatic compositions in export presentation (#121/#122), Following Topics
(#122/#170), and the native timeline (#169/#174) were reviewed. Other changed
source paths match their accepted branch blobs exactly. The combined native grid
retains refresh content while preserving Work route position restoration.

## Integration test correction

The preliminary full application run exposed four failures in two existing test
files after #171 changed the toast policy. Backup imports now explicitly retain
long confirmations, bypassing the test host's zero-duration default. Their tests
now verify the displayed success message and advance its controlled lifetime
through completion. Selection-toast inset checks now wait for the actual geometry
instead of consuming the short confirmation's lifetime in unrelated animation
settles; they also verify eventual expiry. No runtime behavior was changed by this
correction. The preliminary run was stopped after those failures and is not a
completed gate.

Focused corrections: 4 backup-flow tests and 2 selection-toast tests passed.
Analysis of the two adjusted files found no issues.

## Final verification

Checked final candidate: `42bcea726dec6fd8e08a6988f4b83d00e0820df7`.
`./scripts/run_regression_tests.sh` completed with `REGRESSION_EXIT=0`, using the
physical-core detector's six workers:

- Application: **7,638 passed**.
- All 13 package/CLI suites: **1,722 passed**; two existing go_router skips remain
  (`routing_config_test.dart` and `go_router_test.dart`).
- Both repository shell suites passed.
- Python repository tooling: **76 passed**.

The checked candidate is clean. The integration report is the only tracked
change after this complete pass; runtime, tests, dependencies and tooling stay
identical. Current origin/develop still matches the recorded base.

- `./gen.sh`: generated missing outputs and updated translation output.
- Changed-file formatting: 65 original changed Dart files, zero changes; the two
  corrected test files were formatted separately.
- `fvm dart analyze`: zero errors, zero warnings, 4,292 informational findings
  across the repository, exit 0, before the fixture-only correction. Focused
  analysis of those two corrected files: no issues.
- `git diff --check`: passed.

No Android/emulator/Maestro, APK, live API or account checks were performed during
integration. Owner acceptance of the ready branches is the manual acceptance.

Durable local evidence: `.worktrees/_artifacts/approved-ready-integration-20261118/`.
The source manifest and composition proof record the exact accepted tips.

## Remaining issues: read-only findings

### #146: strip below selected search tags

On `a893c420b019ae2dbda6b9cbb2855ea764183349`,
`raw_search_page_scaffold.dart` reserves a fixed 48 dp selected-tag extent in top
viewport padding. `SelectedTagList` uses a 35 dp chip viewport and the popup's
24 dp icon plus 6 dp padding per side, giving a normal row around 36 dp. That
mismatch can leave about 12 dp below the painted Search region. The fresh Search
route is deliberately non-opaque and its Material is transparent; the full editor
background is only painted outside the applied-results state. The gap therefore
allows the prior Browse page to show through. This is a source-level explanation,
not a new device reproduction.

Remaining work: coordinate reserved and actual search-region geometry and paint
the applied-results surface where needed while preserving the initial transparent
editor. Add a real transparent-route regression that verifies surface coverage,
not just lack of toolbar overlap, including tag changes and hide/reveal states.

### #175: navigation background and ranking date selector

On `c21042ac686a1e46efa2a7c63e67a22eee9afece`, the native grid forwards navigation
scroll signals, but `AppNavigationShell` gives the destination its full bottom
MediaQuery inset while `barHiddenFraction < 1`. The bar itself translates by the
continuous fraction. That binary-versus-continuous mismatch can leave the page's
opaque bottom area visible until the bar is fully hidden.

Pixiv Explore's `_RankingDateStepper` is a fixed Column sibling outside the Work
grid and does not observe navigation visibility. It therefore stays visible by
construction. Remaining work: coordinate the visible bottom extent, painted
surface and date selector with the same navigation transition; preserve selection,
keyboard, menu, viewer and reduced-motion behavior. Verify partial hide and reveal
frames, not only fully shown/hidden states. These are source-level findings;
Android rendering has not been rechecked.

### #96: transient Danbooru section error

The branch `6c0cfb29d9b64e6f608fb8700e6cd23ec030e82c` contains only an investigation
handoff, explicitly claiming no runtime fix. The section message is Flutter's
global build-error fallback; ordinary post-loading failures use a different path.
No triggering exception or account mismatch has been established. The #122
provider-cycle correction is not evidence that this separate symptom is fixed.
Leave the issue open until a current reproduction yields the associated exception
and stack trace. Do not suppress the fallback speculatively.

All three issue branches, worktrees and issue states remain unchanged.
