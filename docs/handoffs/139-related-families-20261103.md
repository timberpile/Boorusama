# Issue #139: Related families implementation and verification

Follow-up: [Related ordering, bookmark feedback and Kurumi presentation](139-related-followup-20261103.md)
supersedes this candidate's verification for the latest branch tip.

Original candidate status: **READY FOR INTEGRATION**. Implementation is local on
`feature/139-related-families`. No push, PR, merge or issue closure is authorized.

Base: `02b0d60e99b2033c347f51549bcce1763a451f89`, reconfirmed as `origin/develop`
after verification. #138 is integrated at that base. Implementation commit:
`99acbd19ced80c0bdc6ad32a57744a04ebd569d9`. Fully tested candidate:
`db38378e6c626279743c22840d7e7f94bb7644b4` (adds a test-selector correction).
The subsequent handoff commit contains documentation and formatting of one test
only; the runtime and tested behavior remain unchanged.

## Result and decisions

- One `RelatedFamilyReference` supplies canonical engine/namespace/parent-anchor
  identity for both viewer entries and stored references. Positive parent IDs
  anchor children and siblings; otherwise the Post anchors itself. Direct members
  only, no recursive groups or reparenting recovery. Occurrence IDs remain separate.
- Danbooru's viewer capability renders a lazy `parent:N` Post grid, using the
  floating content-owned header and ordinary timeline controls. The existing
  Related Posts View all opens it. Members open the normal Post viewer, and Back
  restores the family, outer page and viewport. Selection suspends outer swiping.
- Bookmark Related uses the existing group picker. `RelatedBookmark` extends the
  shared `CollectionBookmark` reference record alongside `PoolBookmark`; it stores
  `anchorId`, never a fake Pool ID. Organization, mixed selection, removal/Undo,
  filtering, sorting, folders, refresh and import retain the existing machinery.
- Existing Hive Pool rows and the organization storage key remain compatible.
  Bookmark exports are version 7; versions 4/5/6 remain supported imports. Related
  rows require v7. Scoped exports, duplicate validation and merge/copy/replace use
  the shared pipeline. Service validation precedes mutation. Exception rollback
  includes both reference variants and reports failures, without crash-atomic claims.
- Metadata uses at most 40 Posts plus the producer's existing exact-count request:
  two network operations, no additional probes or crawling. Safe visible members
  contribute tags and static covers. Unknown counts remain unknown; partial or
  incompletely dated families cannot invent upload extrema. Failed refreshes keep
  the last saved summary. Cards do not load family members merely by appearing.
- Bound source/profile resolution is retained. Unbound Related imports keep local
  metadata without borrowing another account. Deferred writes recheck source and
  picker ownership. Optional Search toolbar work stays with #115; automatic timeline
  grouping stays with #134.

Architectural details: [Related families](../related_families.md).

## Review corrections

Review and failing tests led to these corrections before the final candidate:

- Retained the existing Pool tuple identity and serialization while adding Related
  identity, so older references and future unknown Pool engine IDs still round-trip.
- Rejected Related rows in v6 envelopes, conflicting reference IDs, malformed
  Related metadata and duplicate references. Added service-side pre-write validation.
- Moved empty-gallery observation inside the grid so initial controller notifications
  cannot rebuild an ancestor during build. Empty accessible families retain Retry.
- Prevented a shared picker race: Cancel pops a route before its reverse transition
  disposes the widget. A mere mounted check could save a late draft and pop another
  route. Deferred writes now require a current, undismissed route; cancellation also
  suppresses stale error feedback. The regression completes metadata immediately
  after Cancel, without waiting for the closing animation.
- Corrected test fixtures' interleaving dates, member payload type and legacy group
  dialog selector. Restored the existing Kurumi bookmark Search selector after its
  test revealed an overly broad fixture selector edit.

The final diff was reviewed for the supplied scope. There is no second reference
repository, Undo stack, member snapshot store or grouping/navigation implementation.

## Automated verification

Commands ran with the pinned FVM SDK and six detected physical-core workers.

| Check | Final result |
| --- | --- |
| `./scripts/run_regression_tests.sh` on `db38378e6` | Complete pass: 6,061 application tests; 1,655 package/CLI tests; both shell policy/release-script suites; 72 Python tooling tests |
| Existing package skips | Two pre-existing go_router tests skipped; no new skips |
| `fvm flutter analyze --no-pub --no-fatal-infos` with all 39 changed Dart paths from `git diff --name-only 02b0d60e9 db38378e6 -- '*.dart'` | Exit 0; zero errors, zero warnings, 117 informational findings |
| `fvm dart format` on changed Dart files; final no-output format check | Formatted; final check retained with local artifacts |
| `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks/bookmark_exact_source_filter_test.dart` after its formatting-only correction | One test passed |
| `git diff --check` | Passed |
| `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` | Passed on the final runtime candidate |

The full regression covers the added identity, metadata, v7/legacy compatibility,
real Hive reopen and reference-service scenarios as well as neighboring consumers.
The existing persistence suite now runs for both Pool and Related references.
Related gallery/picker widget cases cover 320 px width, 1.0/2.0 text, 120-member
pagination, member Back, eviction checkpoints, mixed indices, selection ownership,
unavailable/Retry, group creation with the keyboard open, cancellation and profile
removal. Real Danbooru producer tests count network operations, enforce summary
bounds and exercise singleton/missing-parent, direct membership, blacklist/rating,
unknown metadata, concurrent consumers and failed refresh behavior.

Earlier failed and superseded checks are retained separately; they are not final
passes. In particular, the first broad affected-suite run exposed the Cancel race
and the Search selector fixture error. Superseded full runs were terminated after
candidate changes. The final runner's durable completion marker is
`REGRESSION_EXIT=0`, after every expected phase. Its combined stop/restart shell
session reported exit 143; the recorded subprocess result and full completion log
establish the final runner's completed pass independently of that wrapper status.

The repeated native-hook `File modified during build` warning is documented in
[build troubleshooting](../build_troubleshooting.md); it also appears on unchanged
inputs. Nonfatal native Dart-finalizer diagnostics and Android toolchain support
warnings appeared. Completed results, rather than those warnings, determine the
verification claims above.

## Android acceptance and limits

Maestro controlled exclusively leased `emulator-5554` without resetting app data.
The debug APK was built from `99acbd19c`; `db38378e6` changes only a test selector.
Runtime source equivalence was checked. Installed/local APK SHA-256 matched:
`e4757ceb9c237a34a53e65546abb834655826a02226798251098578e791b73f5`.

Live Danbooru Search used separate `rating:g` and `has:children` chips. From an
ordinary Post's Related Posts View all, opened the complete four-member family.
Observed decoded gallery thumbnails and its safe static saved cover. Created
`QA Related 139` using the keyboard-visible group-name dialog, saved the family,
opened it from Bookmarks, opened a member and returned to the same gallery.
Separately saved that member as an ordinary Post, then added a Series reference
to the same group. Horizontal swipes traversed Series / Post / Related and back.
Removed the Related membership through its picker and successfully invoked Undo;
the separately saved Post remained independent.

Cleanup deleted only the temporary group and its three unique task-created
bookmarks. All Bookmarks then showed No data available. Browse was restored to
Safebooru (Danbooru), whose selected state was inspected. Font scale stayed 1.0;
network and other settings were unchanged. The profile picker was dismissed and
the exclusive lease released. QA queries remain in normal Search history.

Two exploratory flow assertions failed: one expected the original Post details
sheet to exit with too few Back actions, and one tapped a member before its grid
was ready. Both flows were corrected using the inspected hierarchy; subsequent
member and mixed navigation succeeded. One lease renewal's automatic approval
timed out; its single authorized retry succeeded. No action remained blocked.

No physical-device, latency benchmark, long-gallery device scrolling, live
reparenting, restricted/missing-family, expired-account, offline-device or live
backup-upgrade claim is made. Deterministic host tests cover the relevant edge
cases; the four-member live gallery cannot establish long-gallery behavior.

Durable local evidence: `.worktrees/_artifacts/139-related-families/`, including
`regression-db38378e6.log`, `analyze-db38378e6.log`, Android build logs,
`android-provenance.json`, focused logs and earlier failed/superseded runs.

Future develop integration still requires authorization and a full pass on any
changed combined candidate. No implementation blocker remains on the recorded
base and candidate.
