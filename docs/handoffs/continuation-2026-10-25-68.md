# Issue #68 local implementation and acceptance

Branch: `feature/group-neighboring-series`. Runtime candidate: `54b633a9a`.
Based on develop `a7cdaaff3a285b3ae6e87c9755a28301af02c0e6`.
Implementation and local verification are complete. No branch push, develop
integration or issue closure is authorized yet.

## Result

Bookmark Groups now contain one ordered grid of saved Posts and explicit typed
Pool/Series references. Danbooru and Szurubooru own the collection capability;
normal Pool detail Bookmark controls reuse the existing group picker, active
target and group creation flow. References reopen the full source collection.
They contain compact source identity, group membership and bounded summary facts,
never member snapshots or credentials. Removing a reference never saves, deletes,
downloads or favorites its remote members.

A summary uses at most three metadata requests, examines at most 40 members,
and uses at most two single-result upload-extrema queries. Unknown, partial and
complete coverage remain distinct. Positive and negative local filtering uses
stored tag union even when partial; filtering starts no requests. Refresh replaces
stale tags. Unknown oldest upload can fall back to known newest upload; collection
creation/update dates never substitute for member uploads.

Only confirmed Series can project adjacent saved Posts into a gallery card.
The count is the whole remote Series count. Entering selection restores those
Posts, while an explicit reference remains one selection. Background membership
lookup uses bounded scoped caching, one active admission and the newest queued
view; a built prefix stays stable while scrolling. Download actions use only the
actual saved Post selections. Existing Post-only paths retain their fast paths.

Covers use static visible member media and the originating profile's rating,
blacklist and visibility policy. The final fix hashes typed granular-rating
settings, with a regression showing custom rating changes invalidate old covers.
An unavailable originating profile cannot borrow another account's cover policy.

Backup source schema 6 accepts schemas 4 and 5, emits the optional collection
field only when present, and preserves reference identity and group remapping
through scoped export, import conflict/copy/merge/replace and rollback. Unknown
future engine identifiers survive round trips.

## Verification

- `./scripts/run_regression_tests.sh`, exact runtime candidate `54b633a9a`:
  exit 0; 5,029 application tests, 1,535 tests in all 13 package/CLI suites,
  both shell tooling suites and 72 Python tooling tests. Two existing go_router
  tests skipped. Log: `/tmp/boorusama-68-regression-release-candidate.log`.
- Changed-scope `fvm dart analyze`: exit 0, 121 informational diagnostics, no
  warnings/errors. Log: `/tmp/boorusama-68-analysis-release-candidate.log`.
- Changed Dart files formatted; `git diff --check` passed. Localization generated
  from the English input using the existing i18n generator.
- Tests exercise real Hive persistence/reopen and legacy repair, mixed group
  actions/Undo/rollback, snapshot/import/export compatibility, source isolation,
  partial filtering, actual production Pool pages and group dialogs at width 320,
  enlarged text and open keyboard, mixed selection and asynchronous projection.
- Bounded live Danbooru metadata for Series 32509 verified actual member upload
  extrema and all 12 members within the first 40-item request. No media fetched
  for this check. Evidence: `/tmp/boorusama-68-live-pool.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json
  --target-platform android-x64` passed, then passed unchanged again (6.9 s).
  Final APK SHA-256:
  `4d542e161d8e636b9574e16e2b5e77a790b896b1eb2b99dc6ceb83a1c0d8a44e`.
  Existing toolchain deprecation/support warnings remain.

## Android acceptance

Real Maestro actions on API 37 emulator `emulator-5554`, without clearing data:

- Earlier runtime `6a8132b7a`: opened a safe Pokemon Series, saved its reference
  through a new `Issue68-QA` group while the keyboard was open, saw `Series · 1`
  in Bookmarks, selected one reference without a Download action, reopened the
  full Pool, restarted the app and verified persistence. Deleted only the QA group
  and verified All Bookmarks remained empty. Screenshot:
  `/tmp/boorusama-acceptance-evidence/68-pool-reference.jpg`.
- Final runtime `54b633a9a`, final APK above: saved the same safe Series to Default,
  opened its `Series · 1` card from Bookmarks, reopened the full Pool, removed the
  reference and verified the group empty. Restored Default profile and Browse.
  The earlier persistence/group-creation run is explicitly earlier-source evidence;
  final candidate coverage for those flows also comes from the passing tests.
- Two exploratory flows failed on selectors after navigation (combined Series tab
  label and an absent Back button at the Browse root); hierarchy/screenshot checks
  resolved the actual page state. They were not counted as successful flows.
- Exact lease released after final cleanup. No VM forwarding/profiling remains.

## Remaining delivery gate

Obtain explicit approval for develop integration/publication. If develop changes,
reconcile and run the complete suite on the combined runtime candidate. Issue #77
is a separate unapproved branch and is not included in this acceptance.
