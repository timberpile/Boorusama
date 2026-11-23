# Issue #68: immediate Pool Bookmark targeting

Branch: `feature/group-neighboring-series`.
Checked runtime/test commit: `214cfe0a7afab94fe479896615395911668ef836`.
Parent: `a06e31f48a68c4786c2ef8249d098bcc30f614e2`.

## Cause and change

The button previously awaited `poolBookmarkDraftProvider` before opening the
shared group picker. That draft performs bounded member/tag/cover indexing and,
when needed, two upload-date probes. This put network latency before the dialog.
Its busy flag also covered the entire awaited dialog lifetime, so the button
remained a spinner until dismissal.

The normal Bookmark icon now stays visible. A new remote-Pool target constructor
opens the existing picker immediately using the already loaded collection
identity. The existing bounded summary starts while the user chooses a group.
Saving and group creation require its completed draft; requests, sampling,
cover policy and persistence rules are unchanged. Repeated actions are guarded.
Cancellation prevents a pending action from saving after dismissal, and a
removed/changed source profile rejects the save without borrowing another one.
Existing saved references use their local metadata without new indexing.

The design also records the user's clarification: older apps need not read new
Series backups. The new importer accepts Bookmark source formats 4/5/6; older
readers may reject format 6. These are schema numbers, not app release versions.

## Verification

FVM Flutter 3.47.2; six physical-core test workers.

```sh
fvm flutter test --no-pub --concurrency=6 \
  test/application/pool_bookmark_flow_test.dart test/core/bookmarks \
  test/core/backups/bookmark_backup_codec_test.dart \
  test/core/backups/bookmark_import_service_test.dart
```

Passed all 655 tests on the unchanged final runtime/test candidate. A controlled
metadata gate reproduces the former closed-dialog behavior and now proves that
the picker and normal icon appear before metadata completes. Coverage includes
choosing a group before completion, repeated taps, cancellation before/after a
choice, source removal, retained covers/tags, existing references, ordinary
Bookmarks, shared picker consumers, persistence and backups. Existing application
checks also exercise the picker at normal/enlarged text and keyboard flows.

Scoped `fvm flutter analyze --no-pub --no-fatal-infos` over all three changed Dart
files: exit 0, zero errors/warnings, eight existing informational findings in the
application test file. FVM formatting, final diff review and `git diff --check`
passed. The repeated native-hook message is the documented unchanged-checkout
warning in [build troubleshooting](../build_troubleshooting.md); it is not an
application test failure. Final checks observed no runtime/test source edits.

Durable logs/provenance: `.worktrees/_artifacts/68-pool-picker-latency-20261101/`,
particularly `picker-final-regression` and `picker-verified-analysis`.

## Limits and manual acceptance

No new APK/device timing or live-network response-time measurement was performed.
The gated tests establish that network completion no longer gates opening; they
do not claim a measured device frame time. No complete repository regression was
run for this scoped follow-up. Run it on the eventual integration candidate.

On device, open a previously unbookmarked Pool, tap/long-press Bookmark, and
confirm an immediate group picker with a normal Bookmark icon behind it. Try
choosing a group quickly and cancelling during preparation; saving should keep
one reference with its safe summary, while cancellation should save nothing.
Compare an already bookmarked Pool and normal Post targeting.

This handoff adds documentation only. The branch remains local for review;
no #68 push, develop integration, PR, issue closure or deletion was performed.
