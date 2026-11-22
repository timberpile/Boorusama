# Published-data upgrade qualification

The baseline is `v4.6.1-timberpile.3` at
`422aeae087c1108e655d85d1a3dac25120456cd6`. The compatibility branch was rebased
onto `d9203ae62dcbc5ff81e0bd70702607fb24070787`. Both original branch commits
replayed without a patch change. The original remote tip `016755e82` is also a
parent of the task branch ancestry commit. Its tree is identical to the first
parent, which permits ordinary fast-forward publication of the rebased work.

## Final formats

| Contract | Published | Final |
| --- | --- | --- |
| Bookmark transfer | Writer 5, readers 4/5 | Writer 6, readers 4/5/6. Version 6 requires explicit nested organization and complete dated memberships. |
| Local Bookmark organization | 1 | 2, activated directly from the released layout. |
| Bookmark repository metadata | New | 1, with a required ownership document from initialization. |
| Bookmark mutation journal | New | 1, with a hashed operation and plan for records, organization, restoration and mirrors. |
| MiteMite protocol and source payloads | New protocol, existing Following payload | Protocol 1, Bookmark payload 6, Following payload 2. |
| MiteMite private activity, events, outbox, tap intent and Following rollback | New | Initial version 1 for each format. Following definition digests use the same version-1 state and explicitly cover profile and child definitions. |
| Listed Post payload | New | 1 with the listed discriminator. The published common envelope and Gelbooru V2 engine payload are both version 2. |

Released Bookmark v4/v5 file imports and published rollback exports use
the released semantics. A current private rollback retains exact reserved
local IDs and checks its existing authority. The user-facing wire decoder
rejects development v6-v10 shapes. The local migration preserves the released
source files and rejects obsolete active or pending development generations
before replacing them. The v1 recovery input and current Collection projections
still use legacy Pool and Related metadata, so those conversions remain in
place. Repository and import tests exercise corruption, partial writes, commit
guards, read-only ownership and replay after restart.

## Source inventory

The source audit initially found six violations in the four Bookmark contracts
and their dependent readers and alias. The final inventory covers 87 changed
marker paths. Its registered paths cover the final formats above and the
published profile, settings, tag, Following, feed, SQLite, container and link
contracts. Manual review also covered references to known versions inside
registered files.

The separately named Post Hive row marker remains distinct from its embedded
common and engine payloads. Native Group metadata delegates its payload version
to the selected engine. Existing SQLite versions, record revisions, allocator
bounds, Following definition and transport sequence counters, app/Android
versions, UUID variants and external API paths retain their established meanings.
The remaining inventory includes version-1 content references, local policy and
diagnostic formats, MiteMite catalog and preference records, aliases and
publication intents. Android notification channel/group tags are OS identifiers,
while the native tap payload is a versioned document. Imports of protocol or
conversion modules and dynamic references to registered versions add no format.

## Evidence

The tested candidate was `c8cfc5ad0c11bed1d0a3402dc3fa7b78e5a8cb72` with tree
`f9dc529f08253566426185318eeb1598e5c045b2`. The subsequent report commit adds only
this document.

The [fixture inventory and generation commands](../../test/fixtures/released_upgrade/README.md)
identify the six published writers. The raw captures are pinned in
[SHA256SUMS](../../test/fixtures/released_upgrade/SHA256SUMS).

- The released Bookmark v4/v5 fixtures enter production decode, Replace, Merge,
  Copy and v6 re-export paths. The latest package provides the released
  Bookmark bytes and Following/feed bindings. Current recovery accepts the
  published rollback payload after its old local IDs have disappeared.
- Host tests copy the closed production Hive and SQLite fixture. Assertions
  cover exact stored Bookmark snapshots and IDs, shared memberships, empty
  folders, deterministic aliases, ordering, timestamps, ID reservation,
  profile bindings, explicit settings, tags, Following, feeds, history,
  downloads and sidecars. They inspect first start and two cold opens.
- The migration fault tests interrupt each of the six exposed durable
  boundaries. Recovery validates source evidence, replays the plan and
  reopens again without duplicating records or groups.
- The supplementary snapshot comparator matched all nine projected domains
  at first start and cold reopen. Expected state came from tagged exports,
  closed SQLite rows, and the documented transforms. The projection materializes
  the disabled proxy from the released Hive converter, includes the additive
  settings defaults, and accounts for the older swipe/zoom selectors removed
  in the develop base. Separate production assertions cover published
  timestamp precision and the allocated IDs.
- The source audit passed all 29 registered checks. Manual review covered
  all 87 inventory paths. The checksum manifest verified all 19 fixture files.
- The 74 focused migration and durability tests passed. The follow-up fixture,
  rollback and notification run passed 19 tests. The Undo, mirror-schema and
  snapshot capture run passed 13 tests. The eight dependent test files passed
  all 61 tests after their data and expectations were aligned to the final format.
- The complete regression command exited 0 with 8,004 app tests, 1,730 package
  and CLI tests, 140 Python tests, and both shell suites passing. Two
  `go_router` tests retained their existing skips.
- Dart analysis of changed files finished with 0 errors, 0 warnings and 287
  informational findings. Changed Dart files were formatted with FVM.

The principal commands ran from the isolated task checkout:

```bash
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate c8cfc5ad0 --inventory --json
./scripts/run_regression_tests.sh
(cd test/fixtures/released_upgrade && sha256sum -c SHA256SUMS)
git diff --name-only origin/develop c8cfc5ad0 -- '*.dart'
```

The analyzer ran `fvm dart analyze` on the existing Dart files in the last
command's output. The complete runner used six physical cores. Its log and
the JSON audit, capture and comparison artifacts are in
`.worktrees/_artifacts/release-compatibility-policy/` under the primary
checkout. The regression log SHA-256 is
`2406dc7dd33a546457add0e4e76a0a688403000e6e0d4fe5ddb8bacf8aa8c964`.

## Review remediation on 2026-11-22

The host checks ran on `1c0ef70854639e6988711ac2a38f27b4737bee58` with tree
`8b5d65c8491b1ec187f97aef37c7072cd2516291`. This candidate continues
`249c7f8df1594cc752594e4c67532d7a83877c81` and retains the review's
schema-audit and fixture-capture fixes.

- The `v4.6.1-timberpile.3` writer captured the released transaction after
  its inner rollback deleted the incoming Post and before it restored the
  Group membership. The closed Hive files, transaction plan, journal and
  private rollback payload came from the published producer at
  `422aeae087c1108e655d85d1a3dac25120456cd6`. A fresh writer run reproduced
  the Hive and plan bytes, the logical rollback snapshot, and a valid journal
  hash for the recapture. Each run supplies its own export timestamp.
  [Fixture generation and capture details](../../test/fixtures/released_upgrade/README.md#interrupted-released-import).
- The startup recovery provider failed at `249c7f8` with
  `Legacy Group references an absent Post`. On the final candidate, recovery
  verifies the private rollback, restores the Posts and dated Group
  memberships, and activates one hierarchy. Two cold reopens retain the
  restored profile hint, graph, and activation. The allocator advances beyond
  the deleted ID recorded by the released Group. The malformed store alone
  and a damaged rollback hash both preserve the released files and block
  activation. The tests also interrupt hierarchy staging and the outer
  recovery commit and verify retry after a cold restart.
- The production import flow plans profile dependencies and applies all nine
  sources from the published `.bsexport`. Destination checks cover profile
  and settings links, remapped Bookmark IDs and Group memberships, both tag
  lists, Following and feed ownership, downloads and sidecars, and search
  history. Success survives two cold reopens. A separate fault at the final
  journal commit follows durable writes for all nine sources. Every seeded
  destination domain is restored and survives two cold reopens. This test also
  exposed a preflight failure when the destination export catalog omitted
  legacy feeds. Package import now gets the version from the registered
  decoder in that case.
- All 58 focused tests passed. The schema audit passed 29 registered checks
  and produced the same 87 inventory paths as the earlier candidate. All 25
  fixture checksums verified. Changed Dart was formatted with FVM and analyzed
  with 0 errors, 0 warnings, and 10 existing informational findings.
- The full regression runner exited 0 with 8,011 application tests, 1,730
  package and CLI tests, 148 Python tests, and both shell suites passing. Two
  existing `go_router` tests were skipped. An earlier broad run had two
  profile-mapping confirmation failures before the feed fallback was narrowed
  and one MiteMite timeout. All three tests passed in the final regression.

```bash
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" --reporter expanded \
  test/core/backups/released_{import_recovery,bookmark_upgrade,auxiliary_upgrade}_test.dart \
  test/core/backups/export_import/import_{recovery,recovery_gate,transaction,source_durability,profile_mapping_flow}_test.dart \
  test/core/backups/bookmark_unified_import_recovery_test.dart \
  test/core/bookmarks/bookmark_{storage_migration,hierarchy_migration,id_allocator_hive,id_allocator,unified_organization}_test.dart
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate 1c0ef7085 --inventory --json
(cd test/fixtures/released_upgrade && sha256sum -c SHA256SUMS)
python3 -m unittest discover -s scripts/tests
./scripts/run_regression_tests.sh
```

The analyzer ran on the Dart files changed since `249c7f8`. The targeted and
full suites used six physical cores. The logs and audit JSON are under
`.worktrees/_artifacts/release-compatibility-policy/review-remediation/` in
the primary checkout. The full regression log SHA-256 is
`67aa020f2d7682a10e6b147f181cdc2e8dc9333f99422826f62b75ee78db6283`.

## Combined-candidate verification on 2026-11-22

The task branch advanced from `3a3558e19e28b7da916edbe16984b41d1a0e9dc6` and
incorporated `origin/develop` at `b81cffd3253a8ac873b293493fb4c3ad9d4619d6`.
The tested candidate is `7a6e0b819f6886dd62a9c73ab1645f9194679368` with tree
`3197cb2a400f94cae6b6b3dac2cbc5afbaef99f5`. The combined commit retains the
R1 and R2 implementation, fixtures and tooling fixes. Code generation ran
for the combined English localization inputs. Verification required no
further runtime changes.

- The 58 focused fixture, import, recovery, allocator and organization tests
  passed. The source audit passed all 29 registered checks and reported 87
  inventory paths. All 25 released fixture checksums verified.
- FVM formatting checked 130 Dart files with zero changes. Analysis of that
  scope returned 0 errors, 0 warnings and 289 informational findings.
- `./scripts/run_regression_tests.sh` exited 0 on the combined commit.
  It passed 8,074 application tests, 1,792 package and CLI tests, 148 Python
  tests and both shell suites. Two existing `go_router` tests were skipped.
  The application and package runners used six physical cores.

```bash
./gen.sh
python3 scripts/audit_schema_versions.py \
  --baseline v4.6.1-timberpile.3 --candidate 7a6e0b819 --inventory --json
(cd test/fixtures/released_upgrade && sha256sum -c SHA256SUMS)
./scripts/run_regression_tests.sh
git diff --check
```

The focused command used the same paths shown above. Formatting and analysis
used the union of existing Dart files changed relative to `3a3558e` and
`b81cffd32`. The full regression log `regression-resumed.log` has SHA-256
`3419a3c0151f2caf8f9b44865155b743656343ec5669fc24b71a8bba62b9eb03`.

## Native Android acceptance on 2026-11-22

The live latest public release was `v4.6.1-timberpile.3` at
`422aeae087c1108e655d85d1a3dac25120456cd6`. Its genuine x86_64 APK had
Android versionCode `4192` and SHA-256
`5d87324c4e81d93eacef628c33a680e9f06560fedf2af2f64f757db85e68a3d7`
as recorded by the published update manifest.
[GitHub release](https://github.com/timberpile/Boorusama/releases/tag/v4.6.1-timberpile.3).

The local production APK built from the combined commit had versionCode
`4193` and SHA-256
`7014d57a894106dee44ccc1141485f2a4f77e1465d1069874099cc4f5428a990`.
Both APKs verified as `com.timberpile.boorusama` for x86_64 with the same
certificate SHA-256
`2121bb6443f3d3fc4a560c62939e7e42f3e25c5c0235e39f0ea23743168b27eb`.
The installed candidate APK hash matched the built APK.

```bash
fvm flutter build apk --no-pub --release --flavor prod \
  --target-platform android-x64 --split-per-abi --build-number 193 \
  --build-name 4.6.1-compatibility-local --dart-define=RELEASE_CHANNEL=github
apksigner verify --print-certs <apk>
aapt dump badging <apk>
adb -s emulator-5560 install -r <candidate-apk>
```

Testing used the leased disposable `BoorusamaCompatibility20261122` AVD on
Android 17 (API 37), x86_64, with 16 KiB pages and synthetic Android profiles.
The nine domains came from the pinned released writer's closed files. The
genuine released APK opened the library and then set up the synthetic App Lock
PIN and SAF grant and wrote a backup. Android replaced the APK in place and
preserved the test profile's `firstInstallTime`.

- First launch and two force-stopped cold launches accepted the original PIN
  and displayed the migrated Bookmark hierarchy. Production decoders compared
  allowlisted copies of all nine Android stores against the released fixture
  projection. The expected settings differences were the App Lock mode, enabled
  Auto Backup, verified SAF URI and released backup timestamp. All three
  captures matched. Each capture already contained the same active
  organization-v2 metadata bytes and had no pending Bookmark mutation or
  migration. A later UI-added membership survived another cold launch with
  both original Posts and their Archive memberships intact.
- The candidate retained the released app's persisted read/write tree grant
  and wrote a second backup in the same folder. Renaming the synthetic folder
  in Android Files revoked the old grant. Backup Now reported
  `check_persisted_permission`. Reselecting the renamed folder recorded a new
  persisted grant and wrote a third backup alongside the two earlier files.
- Android reported `POST_NOTIFICATIONS` granted and posted discoveries for
  two local synthetic MiteMite peers on `mitemite.discovery.v1`. A warm
  notification tap opened Devices. A separate tap after the background
  process was confirmed absent showed App Lock before navigation. Entering
  the released PIN opened Devices with the expected second peer.
- A separate synthetic profile loaded the authentic interrupted released
  import fixture into the signed candidate's startup path. The private
  journal completed and the original released Group files remained byte-for-byte
  equal. The activated hierarchy restored Post 42 at local ID 12 with its
  profile hint, dated Archive membership and recent Group. The allocator
  remained above the discarded ID.

This native pass exercised the GitHub APK and device-discovery notifications
on the listed x86_64 Android target. The full regression log, APK checks,
sanitized UI observations, grant and backup receipts, and synthetic store
probes are in
`.worktrees/_artifacts/release-compatibility-policy/native-acceptance/`
under the primary checkout.
