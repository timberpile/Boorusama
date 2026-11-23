# Viewer, folder cover, and Following repairs

The work continues on `bug/2026-11-18-followup` from `6654b6935`.
The owner confirmed Bookmark source selection and live Pool cover retry on
19 November 2026. Realbooru Favorites Sync had already passed their live check.

| Requirement | Evidence |
| --- | --- |
| Following keeps its displayed rows until explicit apply | The mounted-feed test publishes and applies two distinct batches, then publishes an identical batch. It exercises both empty and filtered feeds without new data requests. |
| Refresh progress and source status are visible without a timeline gap | Widget tests cover first-row spacing at 1× and 2× text, the determinate manual ring, progress shared with an automatic pass, and the scrollable source status dialog with enlarged text and keyboard insets. History completion is shown with continuation. |
| Refresh publication avoids unrelated feed decoding | Repository regression uses a malformed unrelated payload and verifies guarded refresh and the targeted reread still work. Checkpoint, rollback, and reset-generation regressions remain in the complete suite. Timeline markers cover decode, merge, encode, authorization, and publication. |
| Prepared galleries preserve their real UI during a swipe | A controlled held-swipe test checks gallery element identity, first-batch coalescing, and display acknowledgement only after settling. Public Group tests exercise saved Pool and Related navigation and Back. |
| Cached Pixiv avatars can paint before activation | The prepared inactive artist row decodes the image and joins the visible row's exact provider key. Request counts and existing Pixiv CDN authorization tests cover cache reuse and credential stripping. |
| Older folders show saved Work and Pool covers | Tests exercise a Work later than the first four candidates, stable four-cell layout, URL-only legacy Pool repair, receiver-local selection, and stale cover-candidate rejection. |

## Verification

The runtime source tree is `5d52a775337362cdbedf443e5576b1ac884469d2`.
The final documentation change records this tested tree.
The focused qualification run passed 242 tests before the last thumbnail-budget
and compatibility refinements. All 75 focused compatibility tests passed
on the final runtime tree.

- `./scripts/run_regression_tests.sh` passed 7,827 application tests,
  1,727 package and CLI tests, both repository shell suites, and
  76 Python tooling tests. Two package tests were skipped.
- Changed files passed `fvm dart format --output=none --set-exit-if-changed`
  and `git diff --check`. Affected-scope
  `fvm flutter analyze --no-pub --no-fatal-infos` reported zero errors, zero
  warnings, and 174 informational findings.

Logs are in `.worktrees/_artifacts/2026-11-19-followup-repairs/`.
Android discovery found a connected physical phone and no emulator.
Device swipe timing, profile-mode frame comparisons, in-place upgrade, and the
owner's specific historical cover records remain unverified. The repository
work-count evidence does not establish that the device freeze is gone.

The test run covered this task branch. Current develop includes the separately
accepted #134 Related and Series grouping.

## Folder mosaic ordering

Folder mosaics use the four newest eligible bookmarks across Posts, Works,
Pools, and Related groups. A direct folder uses its membership dates. A
descendant preview or All uses the latest membership within its scope, with
received-only memberships excluded from All. Legacy memberships fall back to
record creation, and equal dates use the stable bookmark key. Bookmark
timeline sorting and shuffle are independent of mosaic ordering.

Missing cover metadata can be repaired for visible candidates that could
enter the mosaic. Existing source and blacklist checks apply, and a recovered
cover uses its original date position. A cover repair leaves membership dates
intact.

On this change, `fvm flutter test --no-pub` passed 1,348 tests across
`test/core/bookmarks`, the affected Bookmark and Pool application flows, the
preview selector tests, and the MiteMite bookmark mirror engine tests. The tests
cover date and upload order disagreement, re-add and storage reopen, sort menu
changes, bounded repair, and receiver cover policy. Formatting and
`git diff --check` passed. Affected-scope analysis reported zero errors,
zero warnings, and 59 informational findings. Logs are in
`.worktrees/_artifacts/2026-11-19-mosaic-order/`.

Device review of this ordering with an existing mixed folder, in-place
upgrade, and complete verification of a develop integration candidate remain
open.
