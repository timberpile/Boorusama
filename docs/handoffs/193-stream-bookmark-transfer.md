# Stream bookmark import and export

[Issue #193](https://github.com/timberpile/Boorusama/issues/193)

## Scope

Make normal `.bsexport` import and export stream bookmark data through the existing
Hive library. The acceptance target is a round trip of one group containing
100,000 posts, with its records and dated memberships intact after reopen. Keep
the current in-memory library behavior for this pass and measure its memory cost
separately from temporary transfer allocations. MiteMite cleanup is tracked in
[#192](https://github.com/timberpile/Boorusama/issues/192). The tag dictionary is a
separate optimization to revisit after the streaming path works.

## Current path

The source inspection was checked against develop at
`0ea00c0f74fccadec0be8d68f6284fdda655e139`. The host measurements used the
MiteMite task branch at `e708b36df`.

- **Export.** The Bookmark source takes a library snapshot and builds
  `BookmarkBackupData`. The JSON adapter serializes the complete data to a
  string, then the package source writes a UTF-8 part at
  `sources/bookmarks/data.json`.
  [Bookmark source](../../lib/core/backups/sources/bookmarks_source.dart) ·
  [JSON adapter](../../lib/core/backups/export_import/sources/legacy_json_source_adapter.dart) ·
  [Package source](../../lib/core/backups/export_import/sources/export_import_source.dart)
- **Wire shape.** Bookmark schema v6 stores each exported record once in `data`,
  including the source and snapshot. In `groups`, each group stores its
  hierarchy, a `bookmarkIds` array and an `addedAt` map keyed by bookmark ID.
  Multiple groups can reference the same record.
  [Bookmark codec](../../lib/core/backups/sources/bookmark_backup_codec.dart) ·
  [Group serialization](../../lib/core/backups/sources/bookmark_backup_data.dart)
- **Import.** The file workflow expects one part per JSON source, decodes the
  bookmark document as a whole and constructs the incoming data and local
  library snapshots for preview and matching. The transaction captures a
  verified rollback snapshot before applying changes. Read, planning, revision
  checks, apply and rollback all need inspection when removing full-sized
  temporary copies.
  [File import flow](../../lib/core/backups/export_import/import/import_flow_notifier.dart) ·
  [Bookmark decode worker](../../lib/core/backups/sources/bookmark_backup_worker.dart) ·
  [Import transaction](../../lib/core/backups/export_import/import/import_transaction.dart)
- **Local storage and refresh.** Bookmark records use ordinary Hive boxes with
  resident values. Group membership is stored as a list in a group value and
  the app refresh builds an in-memory library and indexes. Streaming the
  archive can reduce transfer allocations while leaving a device-dependent
  ceiling for the final group value and library refresh.
  [Hive setup](../../lib/core/bookmarks/src/data/hive/factory.dart) ·
  [Group object](../../lib/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart) ·
  [Library state](../../lib/core/bookmarks/src/types/bookmark_library_state.dart)
- **Archive limits.** The current reader defaults to 512 MiB per part and 2 GiB
  expanded in total. At the measured payload density, a million posts would
  need roughly 2.4 GiB of expanded bookmark JSON before format changes. This
  is an extrapolation from the sample.
  [Archive limits](../../lib/core/backups/export_import/package/export_package_limits.dart)

## Measurements

One 3,455-post group from a private export produced 8.51 MiB of bookmark JSON
and a 1.24 MiB MiteMite ZIP. On the host Flutter VM it retained about 38 MiB in
parsed bookmark objects. Holding the text, decoded JSON tree and bookmark
objects at the same time added about 64 MiB of live Dart heap. The seven-run
median was 106 ms for JSON decode, 116 ms for bookmark construction, 181 ms for
ZIP staging and text read, and 445 ms for the MiteMite semantic hash. These
measurements cover the stated phases on the host. The verification below
records the 100,000-post workload and Android memory samples.

The tag dictionary prototype assigns short IDs to frequently used tags, breaks
frequency ties alphabetically and sorts IDs within unordered tag fields. It
reduced that group's payload by 25% before compression and 18% after deflate.
For the full bookmark source it saved 24% raw and 18% after deflate. Its 18,630
distinct tag strings occupied 295 KiB as a compact JSON registry. A CBOR prototype
with the same fields was smaller raw but slightly larger after deflate for the
sample group. The dictionary can be shared by regular backups and a future
compact MiteMite format. Keep it out of the first streaming change.

## Proposed transfer format

Keep `manifest.json` for package and source versions, part paths, byte counts,
hashes and other small metadata. Use UTF-8 newline-delimited JSON for the
bookmark source with one complete object per line.

| Part | Row contents |
| --- | --- |
| `groups.ndjson` | Group ID, name, parent ID, sibling position and system role where applicable |
| `bookmarks.ndjson` | Bookmark ID and the existing transfer record with its full metadata |
| `memberships.ndjson` | Group ID, bookmark ID and membership date |

The format can use bounded part files where necessary. A tag registry can have
its own manifest-listed file when the dictionary is added. The published
`v4.6.1-timberpile.4` writer uses Bookmark schema v6, so use a new bookmark
source schema for the NDJSON layout and retain the published v4–v6 readers.
Reuse the existing per-bookmark codec and preserve scope selection, profile
mapping, and Copy, Merge and Replace behavior.

## Streaming and recovery

- Export consistently from a selected library revision. Iterate record and
  membership batches and write each part directly. Compute part digests while
  writing or in a bounded file pass.
- On import, verify the listed parts and decode lines into bounded batches.
  Stage parsed records and use disk-backed indexes for incoming IDs, content
  identity and membership links. Resolve conflicts and build the preview from
  that staging data. A temporary SQLite database is an option for staging
  while the existing Hive store remains the destination.
- Preserve the rollback contract across batched writes. Validate the import
  before committing it, and handle cancellation, retries, insufficient
  storage and process death without exposing a partial import. Budget actual
  expanded data and staging disk space, and bound individual record sizes.
- Measure transfer allocations over and above the live library. Record
  post-import refresh and opening the group separately. Full data structures
  built during Hive apply or refresh still constrain practical capacity.

## Verification target

Generate a synthetic one-group fixture with 100,000 posts and run the
normal export and import paths. Check counts, identities, group and membership
relationships, dates and full metadata after reopening storage. Include
representative published backups, shared memberships across groups, conflict
actions, duplicate and invalid references, and failure or restart from a
partially written import. Measure time, peak memory and temporary disk space
through transfer and separately through refresh and group opening on Android.
Report the transfer and library results even if the current library reaches its
limit before opening the group.

## Implemented format

The normal package writer lists three Bookmark v7 tables under
`sources/bookmarks/`. Each table starts at index 0000, for example
`bookmarks-0000.ndjson`. Parts hold at most 32 MiB and rows hold at most 8 MiB.
The Bookmark tables have a combined 8 GiB expanded limit. Selection metadata,
hashes, and byte counts stay in the v1 package manifest. The standalone JSON
reader retains v4–v6 and the v7 Local Media layout. The last public Bookmark
writer is v6 in the published tag `v4.6.1-timberpile.4` at
`45f3df6c3b2e2c977480b5ac3f3aef415765d218`.

Import uses temporary SQLite for validated incoming rows, conflict projection,
ID remapping, and the private rollback preimage. The existing package journal
owns the verified preimage until the transaction commits or recovers. Hive
writes records in bounded batches and writes each final Group as its existing
single membership value. The reservation bound stays monotonic during rollback.
The apply and refresh spans in Performance diagnostics measure those phases
independently.

## Verification

The final host workload used the normal export and import services. It verified
100,000 records and membership dates after closing and reopening Hive. The file
was 18,226,291 bytes, and the staging directory used 380,225,234 bytes at review.
Measured wall times were 34.6 seconds for export, 38.5 seconds for import review,
68.9 seconds for durable apply, and 15.0 seconds for library refresh. These are
single-run host observations. The process peaked at 3,047,485,440 bytes of
resident memory across seeding, transfer, refresh, and cold reopen.

On `emulator-5572`, an isolated profile build completed the same 100,000-post
import and reported 100,001 creations including the Group. Opening the Group
showed all 100,000 records as unavailable because the synthetic posts had no
matching profile. Sampled process PSS was about 300 MiB during review, 935 MiB
near the end of Hive writes, 1.59 GiB after refresh, and 2.18 GiB after opening
the Group. Android later reported an ANR when navigating to the menu. A cold
launch afterward reopened the Group and again showed all 100,000 entries. The
Android run preceded the review-count display fix. The final host checks include
the corrected counts and verify that the preview uses a bounded set of display
rows.

The host suite for the transfer, part validation, and preview passed 18 tests.
It covered later-source rollback, startup recovery, insufficient storage during
rollback capture, and invalid or duplicate incoming rows. Final Flutter analysis
reported zero findings.

`./scripts/run_regression_tests.sh` passed on the final runtime and test files.
It passed 8,495 application tests, 1,848 package and CLI tests, 149 Python tests,
and both repository shell suites. Two package tests were skipped.

The separate one-million-post host attempt stopped during fixture seeding. It
never reached export. The largest completed round trip reported here is 100,000
posts. During apply, Hive still requires a full list of member IDs and a full
map of their dates for each changed group. When the library contains a received
group, the repository also reconstructs the current group memberships for the
ownership check on each record batch. Refresh builds the full record and
membership indexes. Bounded archive parts do not bound these allocations.

## Import progress and responsiveness

Review reports archive extraction and integrity-check bytes separately. Bookmark
v7 reports bytes through the last validated row written to the incoming SQLite
database. A legacy JSON part reports bytes read and then shows decoding as its
own stage. Apply reports recovery-copy bytes, durable record batches, and
prepared group memberships. Planning, group serialization, journal
finalization, and rollback show an activity indicator. The library reports
records decoded and index-building progress before publishing the refreshed
snapshot. Progress updates are rate-limited to 100 ms within a stage, with
immediate stage boundaries.

Archive extraction, checksums, v7 staging, profile-reference selection, and
SQLite planning run in worker isolates. The apply worker writes its plan to a
temporary SQLite file. The main isolate keeps ownership of the Hive storage
session and yields between record and membership batches. Library decode,
group preparation, and index construction also yield. Hive still serializes
one group as a single value. The `bookmarkTransferGroupWrite` span measures that
call, including its write to Hive. The package transaction still owns rollback
and revision validation.

### Paired host comparison

The benchmark used one closed Hive fixture with 100,000 posts and their dated
memberships in one group. Each trial started a fresh Flutter test process with
a copy of that fixture, exported through the revision's normal package writer,
reviewed and applied a Replace into an empty library, and checked record
identities and membership dates after closing and reopening Hive. The
comparison collected three alternating successful trials at `2e08f5d29`
and `c9912e756`. One JSON trial ran under heavy host contention and took
428 seconds to review. The values below are observed wall-time medians.

| Measurement | JSON baseline | Streaming |
| --- | ---: | ---: |
| Export | 51.1 s | 54.2 s |
| Review | 75.9 s | 36.4 s |
| Durable apply | 50.8 s | 68.5 s |
| Library refresh | 12.2 s | 11.1 s |
| Apply and refresh including preparation | 72.3 s | 79.9 s |
| Measured phases combined | 199.3 s | 170.8 s |
| Peak process RSS through review | 3.84 GiB | 1.88 GiB |
| Peak process RSS through apply and refresh | 5.28 GiB | 2.68 GiB |
| Peak process RSS through reopen and checks | 6.51 GiB | 4.53 GiB |
| Observed peak named scratch files | 141 MiB | 363 MiB |

Scratch files include staged parts, temporary SQLite plan files, and the
recovery copy. The scratch sampler captured two complete streaming trials.
Process RSS includes the Flutter test runtime and any retained export
allocations. The cold-reopen benchmark materializes the records for verification.

### Progress-enabled host run

The final source completed the same 100,000-post check after the host restart.
Export took 35.3 seconds, review 20.6 seconds, durable apply 34.8 seconds, and
library refresh 5.4 seconds. Peak process RSS was 2.66 GiB through apply and
refresh, and 4.44 GiB through reopen and verification. Observed named scratch
files peaked at 583 MiB, including the apply plan produced by the worker. This
single run used the same fixture on a less contended host after restart, so
its wall times are a separate observation from the paired medians.

### Android verification with progress

The installed profile APK matched the recorded hash on `emulator-5572`. The
normal file picker opened the 100,000-post fixture. Maestro observed a
percentage during review, a bookmark count during Apply, and a count during
library refresh. The completion screen reported 100,001 creations including
the Group. The Group showed 100,000 unavailable entries, as expected for the
synthetic posts without a matching profile.

The group also reopened with all 100,000 entries after a cold restart. The
device stopped exposing the app controls after a Group open, and the menu
check remained unresolved. The final package exit history contained no
recorded ANR. Cold library startup exceeded the initial 120-second wait
before the Group became available. Android sampled about 0.27 GiB PSS
during review, 0.86 GiB near the end of record writes, and 1.54 GiB during
refresh. The isolated test package
and copied fixture were removed and the emulator lease was released.

The benchmark harness, logs, memory samples, and Android screenshots are
in the local `.worktrees/_artifacts/193-stream-bookmark-transfer/` directory.

### Regression checks

Flutter analysis reported zero findings. The full application suite passed
8,498 tests. The package and CLI suites passed 1,848 tests with two skips,
and 149 Python tests and both shell suites passed. A host restart interrupted
the package run after the application suite had finished, so the package and
tooling checks were rerun on the same source.

### Branch review

The reviewed branch meets the 100,000-post transfer target. On Android, cold
startup time and menu responsiveness after opening the group remain concerns.

A child-only backup carries its ancestors so the importer can place the child.
Matching local ancestors retain their direct memberships, including posts that
belong only to the parent. This applies to both the released nested JSON and
the streamed format. Recovery restores missing record IDs, restores their
original memberships, then restores changed metadata. This order preserves
shared records when a failed import temporarily removes their last local
membership. Review also checks ownership before planning writes to posts held
only by received groups.

The larger archive allowance is specific to normal backups. Callers supplying
a shared preparation budget, including MiteMite, count all parts against it.
Warm-library import now publishes one refresh. The final host workload verified
100,000 posts and dated memberships after cold reopen. The published
`v4.6.1-timberpile.4` encoder and package writer supplied a separate mixed v6
fixture for Merge, Update, Merge into Target and Replace checks.

On the reviewed source, the 100,000-post host run took 38.6 seconds to export,
32.8 seconds to review, 71.9 seconds to apply and 13.2 seconds to refresh.
Process RSS peaked at 2.28 GiB through refresh and 3.94 GiB through cold reopen
and verification. The regression suite ran concurrently. These are host
measurements for a single run. The review did not repeat the Android check.

The full regression run after the review fixes passed 8,503 application tests,
1,848 package and CLI tests (two skipped), 149 Python tests and both shell
suites. Flutter analysis reported zero findings.

## Large MiteMite publications

The Android comparison of deferred membership counts was inconsistent. One
debug run measured the `Add to` picker opening in 432 ms before the change and
807 ms after it. The repeat measured 480 ms before and 443 ms after, with the
counts arriving another 232 ms later. These are medians of five trials per
build. The deferred-count change was reverted and the earlier bulk-selection
improvements were retained.

The supplied legacy signed publication contains 22 Bookmark groups, 22,462
dated memberships and 4,312 distinct Post records. Its 8.0 MiB of compressed
revisions exceeded the old 256 MiB preparation estimate because the receiver
budgeted for every decoded group in the connected subscription at once. The
receiver now validates and stages each signed revision on disk and commits
the connected subscription as one operation. The supplied publication passed
host Subscribe, unchanged-revision retry and Hive cold-reopen checks with the
original signed files. An isolated Android debug receiver also subscribed
through the Storage Access Framework using the supplied publication.

New Bookmark publications use schema 7 tables and a signed `bookmarkTables`
descriptor flag. That format requires an updated subscriber. The receiver
continues to accept existing unmarked JSON publications. The transport reads
and verifies staged files in chunks. Each new archive can use up to 2 GiB of
compressed storage, and a connected apply has an 8 GiB expanded staging
budget. Both operations also require available device storage.

The host round trip published and subscribed one group with 100,000 posts.
Publication took 84.6 seconds and the durable receive took 242.8 seconds in
one run with other checks active. An unchanged-revision retry kept the mirror
epoch stable. All 100,000 records and dated memberships survived Hive cold
reopen. Peak RSS across seed, publication, receive and verification was
2.67 GiB for the test process.

The Android debug receiver authenticated the same 100,000-post archive through
SAF, wrote all 100,000 journal rows and cleared the journal after persisting
the records and mirror metadata. The durable commit took about 17 minutes on
the emulator. The app then rebuilt the Bookmark library projection under
guest memory pressure. After a cold restart, the Bookmark Groups screen
showed both publishers. A recurring system Pixel Launcher ANR blocked
verification of the synthetic card's exact count in the Android UI.

The focused Flutter checks passed 405 tests and analysis reported zero
findings. The schema audit passed against `v4.6.1-timberpile.4` and its 34
Python regression tests passed. The Android DocumentsProvider regression
compiled along with its fixture. The app test exercised the actual SAF read
from the private code cache.
