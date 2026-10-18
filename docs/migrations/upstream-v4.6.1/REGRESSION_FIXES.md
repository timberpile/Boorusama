# Migration regression repairs and verification

Work began 2026-10-17; final verification continued 2026-10-18 (Europe/Vienna). Branch: `maintenance/upstream-v4.6.1-migration`.
Repair start: `4858d146496e0ffe0503d1ddfe5d482d2b213351`.
Fetched comparison base: `origin/develop` at
`d52b6694eb370a8099c820c397250b5199b0baa5`, unchanged from handoff and an
ancestor of the candidate. Shared migration/upstream ancestry was preserved.

Runtime/test candidate: `bc55de7c26cea2f162394f11da5b4cc0e2402bcd`.
No additional merge, push, PR, release, tag or protected-branch modification was
performed during this repair/review cycle. The branch's existing genuine upstream
and origin-reconciliation merges were preserved.
The primary checkout and unrelated worktrees were preserved.

## Repairs

| Finding | Resulting behavior | Permanent regression coverage |
| --- | --- | --- |
| R01 | Coreutils, legacy and explicit-context mutation designations override safe hints and method inference. Mutation GETs skip retries and challenge replay; safe reads retain recovery. | `test/core/http/client/api_mutation_replay_test.dart`, existing protection startup/browser suites; actual Gelbooru/Rule34 transports and physical request counts. |
| R02 | Scope disposal leaves the process-owned named PIN box open for the replacement scope. Explicit storage close remains available. | `test/app_lock/pin_credential_lifecycle_test.dart`: real overlapping production Hive scopes, wrong/correct PIN, change/clear, cold reopen. |
| R03 | Very short masonry tiles constrain and clip metadata locally; quick-action/favorite burst remains outside that clipping. | `test/core/posts/listing/thumbnail_overlays_test.dart`: 1/20/40px heights, 40/80px widths, 200% text, actual badges/score/two actions and heart centering. |
| R04 | Rejected GIF animation falls back to the approved static quality/grid-size matrix while retaining original-format/size safety. | `test/settings/quality_feedback_test.dart`: quality/grid/animation/unknown/zero/oversized originals. |
| R05 | A second right-click dismisses the backdrop and resolves the deepest visible trigger through actual hit testing. Transparent children retain opaque trigger targets. | Complete Kurumi suite, extended `packages/kurumi/test/context_menu_test.dart`: ordinary/offstage/clipped/covered/nested targets. |
| R06 | Play/Pause/Toggle all honor enabled shortcuts, viewer visibility, video identity and editable-focus gating. | `test/application/video_media_key_lock_flow_test.dart`: real app and screen lock, playing/paused unlocked/locked/unlocked positive controls. |
| R07 | Bookmark-grid selection downloads freeze Off/TXT/JSON metadata before dispatch, preserving stored source identity and actual Original quality. | `test/downloads/download_metadata_regression_test.dart`, existing native completion/sidecar recovery suites. |
| R08 | Concrete choices forward URL and known quality. Actual resolver fallback identity reaches single/bulk snapshots; unknown exact or unresolved identity is custom. Resolver-only choices use null; empty exact URLs fail. | Actual toolbar choices under opposing preferences and default/site source-to-request snapshot matrices; existing application resolver flow. |
| R09 | Bookmark requests resolve the originating profile's media override with shared cross-host credential policy and destination bypass headers. | Stored origin versus active-profile case, transport options, credential stripping and destination clearance assertions. |
| R10 | Defaults seed a new metatag store once; saved empty and partial lists survive cold reopening, and scope disposal preserves the process-owned shared box. | `test/boorus/danbooru_user_metatag_repository_test.dart`, real disk-backed Hive. |
| R11 | Unresolved explicit Zerochan Original records immediate failure and localized feedback without a degraded transfer. | `test/boorus/zerochan_original_download_failure_test.dart`: actual API+HTML client responses, dispatch/activity and real toolbar feedback. |

Unavailable Moebooru JPEG/Large entries and empty e621 variants are omitted.
Concrete quality identity matches its actual resource, including named site variants.
The API constructor requires a concrete non-null URL; only resolver-based choices
use a null URL. Empty explicit URLs do not silently invoke the resolver.

## Independent review follow-up

The first reconstructed candidate passed its full gate, analysis and APK build,
but independent Luna Max review found two additional P2 defects. Those baseline
results are retained as baseline-3ed62 evidence and are not final acceptance.

- A supported Danbooru search-home profile eagerly creates the saved-metatag
  repository during profile-import Reboot. Old/new scopes shared the same Hive
  box, and old disposal closed replacement reads and writes. A real production
  container/Hive probe failed before the minimal process-ownership correction.
  Permanent tests cover overlap and retain explicit cold close/reopen for disk
  persistence. Fix commit: `6bbf64e34`.
- Requested quality could differ from the URL selected by a resolver fallback,
  including Zerochan Sample falling back to Full. Optional `resolvedQuality`
  now travels with resolved URLs from all four production extractors to both
  ordinary and bulk sidecar snapshots. Unknown identities are recorded as
  custom. Twenty real-extractor single/bulk regressions were observed failing,
  then passing; URL choice, redirect cookies and exact Original guarantees remain
  covered. Fix commit: `b90fb0994`.

All three independent source reviewers rechecked `b90fb0994` and recorded no
remaining confirmed source finding in their assigned areas. Native testing then
found a third P2: completed sidecars persisted false failures because the store's
change callback used `ref.invalidate` on its own dependent. The pinned Riverpod
debug cycle check throws after publication, and retry re-creates a failed record.
A fresh no-fault Android download and two production-provider tests reproduced
this independently. Commit `bc55de7c2` uses the owning container for the notification,
retains the disposal guard, and leaves file/URL/quality behavior unchanged. The
corrected affected run passed 218 cases; Reviewer B independently accepted the
minimal patch. This is established for the debug artifact; no release-mode
reproduction is claimed. The earlier b90 gate/native results remain attributed
baseline evidence. The new complete gate passed; native recovery results are consolidated below.

## Verification fixture changes

Python overlay tests now use ten authentic historical Dart snapshots from the
two actual supported revisions. Both commits were available locally; no source
was reconstructed. Fixture suffixes prevent analysis as application code, while
all ten byte sequences were verified against their recorded Git sources.
Representative EN/DE catalogs preserve unrelated entries. Revision/dirty-tree
guards and atomic no-write failure behavior remain covered and unchanged in
production. See `scripts/tests/fixtures/viewer_diagnostics/README.md`.

SQLite export failure tests now use a real second connection and exclusive lock,
assert SQLITE_BUSY, preserve source bytes and reject output publication. They
retain schema/first-use/corruption/round-trip coverage and work independently of
host chmod privileges. No production export behavior changed.

## Focused evidence

These are scoped passes, distinct from the complete candidate gate:

- Request/storage: 228 affected tests passed; initial direct 45 passed, isolated
  network consumer 6 passed. New tests first reproduced the real defects.
- UI/media: 340 application/consumer tests and all 128 Kurumi tests passed.
- Downloads: 126 affected tests passed, including 18 new focused regressions,
  actual client/menu/notifier and existing native completion/recovery consumers.
- Export/import: all 298 tests passed; isolated feedback file 4 passed.
- Repository Python tooling: all 63 tests passed, including 8 overlay tests.
- Follow-up fixes: 24 state/lifecycle cases and 508 affected download/bulk/share cases passed; the final focused download rerun passed 38. UI playback setup now awaits completion; its 233-case focused check passed.
- Final candidate formatting: 35 changed Dart files checked, zero changes.

All Flutter/Dart commands used FVM Flutter 3.47.2 / Dart 3.13.2. Focused jobs used
concurrency two while domains ran independently. The complete runner uses the
physical-core detector (six) and runs package/tooling suites serially.

Earlier intermediate failures in new fixtures and a download interface transition
are retained in implementation logs, followed by completed clean focused runs.
The recurring native-hook File modified during build warning is documented in
`docs/build_troubleshooting.md`; it is not used as a substitute for command exit
status. A separate Dart VM finalizer diagnostic also reproduces in the exact reviewed
4858 baseline under the same SDK and locked dependencies, with all six isolated
tests passing. It predates these repairs; its cause and production impact remain
unestablished. No SDK, dependency, native hook or safety check was changed to hide
it. See the preserved baseline log and diagnostic-assessment.md. Native Android
results are assessed separately.

## Candidate gates and independent/native review

Final runtime/test candidate: `bc55de7c26cea2f162394f11da5b4cc0e2402bcd`.
Origin was fetched at 2026-10-17 23:39:40 UTC after the final gate; the comparison
base remained d52b6694 and the remote task branch remained 4858d146. This is the
last fetched remote state, not a publication of the local repairs.

| Final command/check | Actual result |
| --- | --- |
| `./scripts/run_regression_tests.sh` | Exit 0: 4,048 app tests; 1,029 tests across all 12 package/CLI suites; 63 Python tests; policy and Android release script suites passed. No reported individual test skips. |
| `fvm flutter analyze --no-pub --no-fatal-infos` | Exit 0; 177 infos, no warnings/errors. Normalized comparison with the original review found no new diagnostic. Pre-existing infos were retained. |
| `fvm flutter build apk --debug --flavor dev --no-pub` | Exit 0; exact dev APK below. |
| `fvm dart format --output=none --set-exit-if-changed` on changed Dart paths | Exit 0; 35 files, zero changes. |
| `git diff --check origin/develop HEAD` | Exit 0. |

APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`, 458,494,022 bytes.
SHA-256: `3a0dce5b3566ff5dc7903942a627593e68ba66be8fe89d2dc81bc977805cc613`.
Package: `com.timberpile.boorusama.dev`, version `4.6.1-timberpile.1-dev`,
version code `190`; minimum Android SDK 24, target/compile SDK 36;
ARM32, ARM64 and x86_64. This dev artifact does not establish production signing
or production upgrade compatibility.

The full runner completed from 00:50:17 to 00:57:35 on 2026-10-18 Europe/Vienna.

On the b90 baseline, the three independent reviewers ran their own focused
checks serially to avoid host contention; the sidecar-only bc follow-up is
reviewed and retested separately:

| Reviewer | Independently executed result |
| --- | --- |
| A: request/storage | 62 request, startup, actual-client mutation, PIN, real-Hive metatag and lifecycle consumer tests; exit 0. |
| B: downloads | 38 permanent metadata, resolved-quality and Zerochan failure tests; exit 0. |
| C: UI/media | 277 affected application/widget cases and the complete 128-case Kurumi package suite; both exit 0. |

Each was dispatched with requested and accepted model `gpt-6-luna`, reasoning
effort `max`, and a fresh review context. The reviewers inspected both the full
branch against the fetched base and their repair boundaries; they did not author
the initial fixes. Their source reports distinguish tests they ran from logs they
inspected. Initial external FVM cache permission failures were followed by
completed escalated runs; the first attempts remain in evidence.

Reviewer B then independently ran 40 cases on `bc55de7c2` (the two new provider
regressions plus its original 38-case boundary): exit 0. Native final-artifact
checks prove a fresh ordinary TXT download has no false ready failure and the
exact deliberately faulted record can retry metadata without changing media
hash/mtime. The final native review and cleanup evidence is consolidated below.

See [FINAL_ACCEPTANCE.md](FINAL_ACCEPTANCE.md) for the concrete user-run checklist
and [MANUAL_ACCEPTANCE_CHECKLIST.md](MANUAL_ACCEPTANCE_CHECKLIST.md) for broader
migration acceptance. Automated/controller tests, local native UI, live transport,
physical device and production-signed upgrade acceptance are separate boundaries.

## Native evidence and remaining boundaries

Three exclusive API-36 x86_64 emulator leases were used with Maestro MCP for UI
control and targeted ADB for install/properties/native key events/file assertions.
All three dev packages were absent initially; these are disposable fresh dev
installations, not signed-in production upgrade tests. No account credentials
were read. Each owner renewed before device operations and recorded cleanup.
The shared b90 APK was installed first; all three were subsequently updated with
`install -r` to the final bc55 APK above. Review reports retain precise artifact
attribution rather than implying all earlier cases were repeated.

| Area | Native observation and evidence | Limit |
| --- | --- | --- |
| R07 bookmark sidecars | On b90, actual bookmark-grid selection downloads produced Original media with Off/TXT/JSON under global Thumbnail. Parsed JSON source/post/quality and media hashes agreed; TXT had expected tags and Off no sidecar. Two-item Original/TXT bulk completed. `reviewer-b/REPORT.md` and `reviewer-b/native/bookmark-grid-*`, `bookmark-bulk-*`. | Compatible source-specific bookmark viewer uses its ordinary toolbar; it is a different path. b90 publication bytes passed while its status was affected by the now-fixed provider defect. |
| R08 explicit source | On b90, opposing global preferences and explicit Thumbnail/720/Original produced the expected actual dimensions/formats. Original JSON recorded original, the source host and real post ID. Final bc55 focused 40 cases rechecked actual resolver fallback and bulk metadata. | Full native site-specific menu matrix and missing variants remain manual; deterministic tests cover them. |
| Sidecar finalization/retry | On bc55, a fresh ordinary TXT download left no false ready record. Exact intentionally faulted task 387345235 retried metadata successfully; 547,311-byte media SHA-256 and mtime were unchanged and the published TXT had 52 tags. `reviewer-b/REPORT.md` and `sidecar-followup/REPORT.md`. | Confirmed old debug false-failure defect is closed. Release-mode reproduction is not claimed. |
| Background/resume | Final bc55 Home/resume smoke found complete media/TXT and no failed task. | Small transfer may have finished before backgrounding; continuation and crash recovery were not demonstrated. |
| R09 mirror routing | Final bc55 bookmark-grid download with Default active and a different originating Zerochan profile stored task 1347097288 with `http://127.0.0.1:45515/media/post.271018.full.png` and `mediaHostOverridden=true`, matching the saved `media-source.invalid` to `127.0.0.1` rule. Deterministic tests separately cover credential policy and destination bypass. | Origin-specific URL rewriting is confirmed. Cronet ERR_EMPTY_RESPONSE preceded any fixture media GET; transfer, header filtering and destination clearance remain unverified natively. |
| R11 unavailable Original | Final bc55 fresh 640x480 fixture post 271021 omitted API full and HTML Original. API then HTML returned 200; Maestro asserted “The original media file is unavailable. Retry.” No substitute media request or new sidecar intent/native task followed. | Controlled native failure passed; broader live-site variety remains manual. |

No global DNS, trust, TLS or security settings were changed to make fixtures work.
The native viewer screenshot request was rejected by automatic approval review
because of a private-profile/content classification. That classification does not
establish that the fresh dev installation was signed in. No alternate screenshot
capture was used; reviewer C retained sanitized hierarchy/assertion and key-event
evidence, and removed its transient listing/menu screenshots.

Reviewer B restored Original quality, metadata Off, Any network, notifications on
and skip-existing off; removed both test bookmarks, all task output files, the
synthetic conflict directory and only identified stale test intent records. Its
lease was released. The empty dedicated Download/BoorusamaNativeQA_20261018 folder
and persisted grant remain because the app offers no unset-folder control. This
is retained fresh-dev test setup, not existing user data. The later controlled
supplement also retained one enqueued and one cancelled WorkSpec for synthetic
R09 task 1347097288: Download Manager showed all task views empty, but no visible
scoped cancel control remained. Its app-private intent was removed while stopped;
the WorkManager database was preserved and no app-data reset was used.

Reviewer C's final bc55 Android run loaded a real 20-second WEBM and established
unlocked positive controls for Android media Toggle (85), Play (126), and Pause
(127). With playback paused at 0:03, locked Toggle and Play left the timeline at
0:03 after successful unlock and a second observation. Locked-playing Pause and
Toggle remain unverified: a reliable unlock/timeline observation was unavailable
for the attempted Pause and playing Toggle was not attempted. The timeline table
with UTC readings is in `reviewer-c/REPORT.md`. These are native events, separate
from the deterministic all-key/all-playing-state lock tests. Hidden/editable
native media-event gating remains unexercised and is source-reviewed; the focused
application lock regression does not explicitly drive those two branches.

C exercised final listing/viewer/settings navigation and animated-result loading;
b90 evidence separately covers bookmarks, Android long-press/dismissal without
tap-through, and 200% text with the search keyboard open. Final landscape listing
was reachable at 2400x1080; one tile coordinate failed to establish a viewer
transition and is recorded as a selector limit. The initial public-content phase did not identify panoramic dimensions or a
trustworthy live static-GIF resource tier; the controlled supplement below closes
the identified-fixture prerequisite for a bounded native case. A bounded details-panel
gesture did not establish closing or retained playback. None of these missing
observations is reported as a confirmed source defect. Desktop secondary-pointer
acceptance remains separate from Android long press and Kurumi pointer tests.

C restored and read back 1080x2400 at density420, font scale1.0, accelerometer
rotation1/user rotation0, manual brightness102 and timeout2147483647, returned the
app to the Default listing and released emulator-5558. The initial public-content phase changed no bookmark/profile or
persistent quality/autoplay state; controlled-fixture cleanup is recorded below. The fresh dev installation remains
available for review. Screenshot rejection and removed transient paths are
recorded in the C report.

Reviewer A's final bc55 native run completed a non-empty profile Replace through
Settings -> Export and Import, followed by wrong-PIN rejection, correct unlock,
and cold-process unlock. Saved metatags were edited to empty through the real
pencil/check controls, remained empty after cold restart, then were set to only
rating/user and remained exactly those two after another cold restart. The
original six tags were restored. Anonymous credential-free fixtures and parsed
part-integrity evidence are under `reviewer-a/native/`; temporary profile removal
was explicitly previewed before import. The final A report records lock/profile
restoration and the completed change/clear PIN cycle separately.

The intended Search-first import fixture did not establish eager Search-home
startup on Android: Hive CE sorts profile UUID keys lexically, so the Default
profile still precedes the added Search profile regardless of payload ordering.
This explains the observed Default home and does not show a skipped Reboot.
See `reviewer-a/native/coordinator-profile-order-assessment.md`. The eager overlap
is supported by source tracing and the real production-provider/Hive regression,
while the native empty/partial cold-persistence and post-import PIN cases are
actual separate passes.

A also changed the known temporary PIN, verified the changed PIN after resume,
cleared the lock, restored the 30-second timeout, and confirmed a final cold
launch needed no PIN. Only the original anonymous Default profile and six
original metatags remain. The five device export fixtures and empty task folder
were removed, the private PIN file was deleted, and emulator-5554's lease was
released. The coordinator independently checked that lease availability and
absence of the temporary PIN file. After deliberately removing the active test
profile, the existing invalid-profile chooser required selecting Default; a
second cold launch retained that choice. Relevant lookup/recovery/restart logic
matches origin/develop, so no automatic-selection redesign was introduced.

### Controlled native image supplement

After the initial C report, a bounded HTTP fixture used an existing credential-free
Danbooru profile, a host loopback-only server, and an exact per-emulator ADB reverse.
No APK or network-security change was made. Final bc55 loaded two synthetic posts:
identified 2400x600 panorama and a real one-frame GIF measured at 720x405 and
6,535,729 bytes (over 5 MiB). The panorama's hierarchy bounds were 493x123px at
Medium grid and 241x60px at Tiny. Medium grid with Auto thumbnail quality requested
and received the static 720 resource and the 180 placeholder, not the oversized
original. Server code, exact requests and sanitized hierarchy are under
`reviewer-c/fixture/`. This establishes actual controlled native resource loading;
it is separate from the full deterministic quality matrix and live-site acceptance.

A changed-tier expectation was corrected against actual UI localization:
Thumbnail quality **Medium** maps to internal `high`, and UI **High** maps to
`highest`. UI High + Tiny therefore expects 720, not 360; absence of a 360 request
is expected. A fresh changed-tier resolution was not independently established
because 720 was already cached. The 1/20/40px, two-action, score/badge and 200% text
matrix remains directly covered by widget tests; this native fixture does not
claim all of those extremes. C removed its fixture profile, stopped the loopback
server, removed the exact reverse mapping, restored Medium/Auto and the display
baseline, and released emulator-5558. An initial sandbox ADB cleanup denial was
followed by a successful authorized exact-device cleanup.


### Controlled native download supplement

Reviewer B used the final bc55 APK with a credential-free Zerochan profile,
loopback-only HTTP server and exact emulator-5556 reverse mapping. Existing HTTP
support and the normal add-profile URI were used; no APK, backend, DNS, trust,
TLS or security policy was modified. The additive profile-export helper files
for B and C were not imported; their unused provenance is retained.

For R09, the saved origin-profile rule was `media-source.invalid` to `127.0.0.1`,
while Default was independently confirmed active at bookmark-grid selection.
An exact-task-only WorkManager lookup under `no_backup` confirmed task 1347097288's
rewritten URL and override flag. The temporary database/WAL/SHM copies were used
only for that filtered lookup and removed. Cronet reported ERR_EMPTY_RESPONSE
and the server recorded no full-media GET. This confirms request construction,
not successful transfer or native header/destination-clearance behavior. No new
source defect was established by that transport failure.

For R11, the first fixture accidentally included the HTML selector that the
current client correctly recognizes as Original. Its queued attempts were setup
errors, not a reproduction of missing Original. After canceling those four
identified tasks, a fresh ID 271021 omitted both API full and the HTML Original
selector and supplied actual 640x480 preview bytes. API and HTML fallback were
observed, then the localized failure appeared, with no substitute media request
and no new native task/sidecar intent. This closes the bounded controlled native
R11 case; a persistent failed-task row is unnecessary when dispatch never starts.

An initial 1x1 image also exposed a pre-existing debug viewer scale assertion:
unchanged origin/develop and current Kurumi calculations can produce maxScale
below minScale for such tiny decoded media. The bounded fixture was enlarged to
640x480 to exercise download behavior. The assertion was not introduced or fixed
by this migration repair; release impact remains unestablished. Source comparison
and fixture corrections are preserved under `reviewer-b/native/fixture/`.

## Local handoff decision

The confirmed R01–R11 findings and three material follow-up findings are repaired
and committed. The final runtime/test candidate passed the complete local gate,
analysis assessment and dev build. All three independent Luna Max reviews and
the requested local emulator/Maestro phase are complete with the exact limits
above. The branch is ready for the user's final review; production upgrade,
remaining native/live/platform cases and integration approval remain open in
[FINAL_ACCEPTANCE.md](FINAL_ACCEPTANCE.md). This does not assert that all broader
migration acceptance criteria have passed.

The final documentation commit contains only this report, that checklist and the
migration README, so it reuses the complete pass on runtime/test commit bc55de7c2.
The exact documentation SHA, final state and all review logs are preserved in the
ignored worktree folder `.migration-verification-bc55de7c2/`. Its verified
`review-evidence-2026-10-18.tar.gz` includes per-file SHA-256 checksums and the final
documents; the APK is separate at the path above. All three emulator leases were
released, temporary fixture servers/reverse mappings and task-owned data removed,
and the tested display/app settings restored. Fresh dev installs remain; B's empty
dedicated download folder, persisted SAF grant and the R09 WorkManager row
are the documented restoration exceptions. No phone was operated on and no remote mutation was performed.
