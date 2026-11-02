# Issue #68 integration review

Reviewed 2026-11-02 on the existing `feature/group-neighboring-series` worktree.
The user explicitly authorized squash integration, publication, issue closure and
completed-branch cleanup after verification, without a PR.

## Candidate and review

- Starting feature head: `e55d684f21241179d5e016a2386333df7371b684`.
- Fetched develop base: `74cdf43a5bd5205baa8f7cefb164986fe2656dd1`.
- Reconciled runtime/test candidate: `e57df6bf0f30ab4cc85e8e8bb35d341c034fd55d`.
- Candidate tree: `c03209ebd3003d85fee8ad48ae27af15dd1fd3cc`.
- This report and its design-link updates change documentation only. The complete
  pass below qualifies the unchanged runtime/test candidate for squash replay.

Read current AGENTS, development/issue/verification/device workflows, the live
issue and all comments, current designs and the successive branch handoffs.
Reviewed the complete resulting diff against fetched develop and its consumers.
All registered worktrees initially had clean tracked/untracked status. The
primary checkout stayed detached at its original head; unrelated worktrees were
not edited.

Reconciliation retained develop's compact timeline, adaptive batch dialogs,
feedback routing, source-aware blacklist counters and request-generation guards.
The final grid controller and viewer implementation are identical to develop.
Full viewer/details/gesture regressions were included. Related grouping, Mixed
Viewer, Pixiv fixes and collection-identity migration remain outside this change.

Confirmed corrections:

1. Preserve typed Pool membership/counts inside the newer batch-dialog/menu
   components, and retain the compact Bookmark header plus indexed-filter help.
2. Mixed Bookmark score modes previously reordered Posts by saved date/identity
   once any reference existed. Both directions now retain the shared Post score
   order and ties. Unscored references follow in library order; no member score
   aggregate or lookup is introduced. New tests reproduced both failures first.
3. Leaving Artist during its Post request caused a disposed-WidgetRef error.
   Capture the capability before awaiting and skip metadata after disposal. A
   held-response production-widget regression reproduced and verifies the fix.
4. Correct stale reference/subset-count and 40-ID-budget assertions, a newer
   Post-picker consumer's nullable access, and badge test widths for Flutter's
   Ahem font. Preserve meaningful fallback and membership assertions.
5. Remove an unsupported, redundant white-color SVG filter from the supplied
   Collection asset. Its paths, masks and stacking remain intact; actual Android
   rendering was inspected. Format every changed Dart file.

## Acceptance evidence

| Contract | Evidence on the reconciled candidate |
| --- | --- |
| Pool/Series Bookmark buttons, shared group targeting/creation | Production application tests, including pending metadata, repeated actions, cancellation/profile removal and keyboard/enlarged layouts; Android save through a new group with the keyboard open. |
| Independent references beside individual Posts, full counts/navigation | Mixed production-grid/selection/removal/Undo tests; Android Series 29 and Collection 49 saved together, distinct cards and full remote navigation. Restart retained the Series cover/reference. Selecting a reference selected one item and offered no Download action. |
| Compact references, bounded tags/extrema and strict indexed filtering | Indexer, selector, refresh-failure, exact-host and source-policy tests; no member snapshot persistence, no filtering I/O, positive/excluded tags, failed-refresh retention and documented unknown/fallback dates. |
| Rolling five-result Search/Artist grouping | Boundary/overlap/raw-index tests, held real-order fixture, production Search/Artist tests; live Search `malberrybush` displayed Series 29 with decoded first-member cover, and badge tap opened all 29 members. |
| Pagination, cancellation, retry, raw selection and stable anchors | Production underfill budget/manual continuation/failure/cancellation/query-replacement/paginated-mode tests, controller exhaustion/generation and hidden-index anchor tests. Current develop's controller is preserved exactly. |
| Individual Bookmarks and explicit collection queries remain ungrouped | Production application tests; no automatic Bookmark membership requests; explicit Pool/Series references stay independent selectable entries. |
| Cover quality and source restrictions | Production persisted/legacy-cover, policy invalidation and unavailable-profile tests; Android High/Low visibly changed decoded cover sharpness while both reference identities/counts remained. No device request-count or pixel-resolution measurement is claimed. |
| Persistence, groups, export/import and removal safety | Real Hive reopen, group duplication/deletion, mixed removal/Undo/rollback and scoped backup/import/profile-remapping tests. Post-only formats 4/5 and new format 6 remain supported; removing references preserves saved member Posts. |

## Executed verification

FVM Flutter 3.47.2; six detected physical-core test workers.

- Focused `fvm flutter test --no-pub --concurrency=6` covering
  `test/application/pool_bookmark_flow_test.dart`, `test/core/bookmarks`,
  `test/core/backups`, `test/core/posts/listing`, `test/core/posts/pools`,
  `test/boorus/danbooru_artist_page_test.dart`,
  `test/boorus/danbooru_series_membership_test.dart` and
  `test/core/posts/details`: **1,600 passed**, 220.4 seconds. The source was
  committed while this command ran; the clean exact-commit gate below is the
  authoritative final-candidate pass.
- `./scripts/run_regression_tests.sh`: **exit 0**, 912.94 seconds, clean
  `e57df6bf0` before and after. **5,980 application tests, 1,654 tests across all
  13 package/CLI suites, both shell suites and 72 Python tests passed**. The two
  existing vendored-router skips remain.
- `fvm flutter analyze --no-pub --no-fatal-infos` on all 81 changed Dart paths:
  **exit 0; zero errors, zero warnings, 134 informational findings**, exact clean
  `e57df6bf0`. Formatting and `git diff --check` passed.
- Generated outputs were refreshed because develop changed localization/runtime
  inputs. No tracked generated runtime output changed after qualification.
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **exit 0**, clean `e57df6bf0`,
  80.28 seconds. Installed APK SHA-256 matched the built APK:
  `beb00dd7076dc33f81abfa5869fb418b72621a7e1b0c27d3bf7f53d5283ec190`.

Early diagnostic failures are retained and superseded by these final passes.
Existing native-hook notices, occasional VM callback/finalizer diagnostics and
Android toolchain warnings remain distinct from the passing command results.
Durable local logs, screenshots, APK correspondence and worktree inventory are
under `.worktrees/_artifacts/68-integration-20261102/` in the primary checkout.

## Android scope and remaining limits

Used Maestro MCP on exclusively leased `emulator-5556`, launched as an independent
read-only Phone2 instance with snapshot saving disabled. The busy emulator-5554
and physical phone were not used. Installed without clearing app data.

Verified decoded Series/Collection icons and covers, badge taps, whole-collection
navigation, local save/restart/selection, and mixed-reference rendering at 320dp
and 2x text. Four-column Tiny layout retained both source/type icons with count
fallback; Medium layout retained readable totals. High/Low covers both decoded.
One Collection Gallery load showed a generic error; ordinary Retry succeeded.
This does not establish the cause of that single failed live request.

Dark Android rendering and light-theme widget rendering were checked; a separate
light Android run, deleted-profile visual fallback, physical assistive input,
long-session performance and hardware frame-time distributions were not measured.
Source/fallback, narrow/enlarged/keyboard behavior, cover resolution and async
contracts have controlled regression coverage. These limits leave no critical
acceptance gap for this integration. There is no new physical-device swipe or
gesture-performance claim.

The exact QA group and its two references were deleted. Original Medium grid,
Auto quality, font scale and display size were restored. The theme preview was
not applied. The independent read-only emulator was stopped without saving its
AVD state, verified absent from ADB discovery, and its lease released. No remote
account mutation or recipient send occurred; the persistent AVD remains unchanged.
