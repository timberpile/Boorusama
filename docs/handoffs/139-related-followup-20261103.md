# Issue #139 follow-up

Continuation: [Bookmark UI corrections](139-bookmark-ui-corrections-20261103.md)
supersedes the 28 dp overlay description and records the later checked candidate.

Local delivery on `feature/139-related-families`, continuing `a40f2df38`. No push,
PR, merge or issue closure. The separate Bookmark Picker cleanup must follow this
branch; it will start from this delivery and contain only its additional changes.
The earlier implementation evidence is retained in
[the original handoff](139-related-families-20261103.md).

## Behavior

- Related galleries use the shared timeline selector with Oldest / Newest and a
  shared Settings preference (default Oldest, invalid/missing values also Oldest).
  Normal Settings storage and backup/restore serialize the preference. Ordered
  requests use `parent:N order:id_asc` / `order:id_desc`; identity stays canonical.
- A successful order change clears selection, resets scrolling and reloads page
  one. A replaced controller isolates stale responses. Existing viewer occurrences
  retain their initial or chosen order and viewport through Back and eviction;
  new occurrences read the saved preference. Failed saves retain the content/order
  and show localized feedback.
- The gallery bookmark icon observes canonical memberships, including removal and
  Undo. Related cards omit the title and its space but retain type/count semantics.
  Shared source icons and type badges use 28 dp footprints, 4 dp overlay insets
  and a 4 dp gap, inside the existing 2 dp tile padding.
- Related gallery actions use `BookmarkGroupPickerAnchor` / `KurumiAnchor`.
  Related card context actions use `KurumiDialog`. Existing picker content and
  mutation semantics are reused; other legacy picker callers remain for the
  separate cleanup. The Related name dialog owns deferred creation after its
  anchor closes and rejects cancelled or removed-profile writes.

## Automated checks

Checked runtime candidate: `98f0dbaf57ddf8878e4863f3939722879841c87c`.
The following handoff commit changes documentation only.

- `fvm dart format` on all ten changed Dart files: completed.
- `fvm flutter analyze --no-pub --no-fatal-infos` on those ten files: exit 0,
  zero errors, zero warnings, 36 informational findings.
- `fvm flutter test --no-pub --concurrency=6 test/application/pool_bookmark_flow_test.dart
  --plain-name Related`: 10 passed after corrections. The subsequent full suite
  covers the final candidate, including Settings persistence and RTL geometry.
- `./scripts/run_regression_tests.sh`: all 6,073 application tests and 1,655
  package/CLI tests passed, plus both shell tooling suites. Two existing go_router
  tests remain skipped. The wrapper exited 143 during the Python phase without
  recording completion; that incomplete phase was rerun independently.
- `python3 -m unittest discover -s scripts/tests -v`: exit 0, all 72 passed.
  Every required complete-suite phase therefore has a completed pass on this
  candidate, although the aggregate wrapper itself did not complete.
- `git diff --check`: passed.

The Related cases cover canonical icon transitions and Undo, title removal,
28 dp overlays, 320 px width, enlarged text, keyboard creation, cancellation,
profile removal, remembered ordering, failed preference saves, pagination and
old-order page completion. A real Hive reopen plus Settings JSON round trip
covers the Settings backup representation. Existing gallery tests cover Back and
eviction. Timeline widget taps emit render-surrogate hit-test warnings while
still opening the menu; Android pointer taps succeeded. Native-hook modification
and Dart finalizer diagnostics appeared as in prior runs; final results above
are based on completed checks, not their absence.

## Android acceptance

Built with `fvm flutter build apk --debug --flavor dev --target-platform android-x64
--no-pub`; installed without resetting data on exclusively leased `emulator-5554`.
Installed and local APK SHA-256 both:
`b1cefe84d4335a4edfa7672e3ed4aeddc9fc280de774eac49da7d4854cb7f494`.

Maestro exercised a live two-member Danbooru family: Oldest default, Newest menu
selection, immediate bookmark anchor, keyboard-visible group creation, filled
bookmark feedback, removal and Undo, saved Related card without a title, aligned
source/type overlays, reopening with Oldest, enlarged text (2x), and Back dismissal.
Decoded thumbnails and the filled icon/card geometry were visually inspected.

The temporary `QA Related Followup 139` group and its unique reference were deleted;
All Bookmarks showed No data available. Restored the original Danbooru profile,
font scale 1.0, and released the lease. Search history retains the QA query.
An exploratory section-wide accessibility selector hit a thumbnail; the corrected
header-coordinate flow succeeded. Invalid YAML escaping/fractional coordinates
were corrected before running the affected actions.

No physical device, desktop pointer, live backup upgrade, long-gallery device
pagination, offline/expired-account or live profile-change claim is made. Host
behavior tests cover ordering, pagination, stale responses, save failure, cancel
and profile removal. Compact widths, enlarged text, keyboard layout and RTL badge
geometry have automated coverage. Desktop focus/pointer and assistive-input
acceptance remains manual.

Local logs: `.worktrees/_artifacts/139-related-followup/`. Earlier failed checks
are retained as diagnostic evidence and are superseded by final checks below.
