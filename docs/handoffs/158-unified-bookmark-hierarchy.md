# #158 Unified Bookmark hierarchy: local completion handoff

**Status:** implementation and verification complete for the exact runtime candidate below. Independent GPT-6 Astra High re-review approved it on 2026-11-07. Device restoration and emulator lease release passed. This handoff records local completion; it does not publish or integrate the branch.

## Candidate and review

- Issue: [#158](https://github.com/timberpile/Boorusama/issues/158)
- Branch: `feature/158-unified-bookmark-hierarchy`
- Base: `f6deb27590a38a812c532c939085742886cdda3f` (#155 unified Bookmark storage)
- Approved runtime: `7b3113ff585ec687212850ffd56f1d0091889267`
- Independent review: `.worktrees/_artifacts/content-architecture/158/astra-high-final-rereview.md` — **APPROVE**, `gpt-6-astra`, High effort. It reviewed the complete #158 delta against the base and reports no unresolved blocker.
- The candidate was reviewed clean at that SHA. The completion handoff changes documentation only; the runtime/test tree remains identical to the approved candidate.

The two design-history commits are `facd9903f` (hierarchy rollout plan) and `20630d665` (backup v10 format). The seven runtime commits are:

1. `a045f06df7120c67c74b70939508595bc44d5b88` — stage recoverable Bookmark group hierarchy
2. `b0fb23f48046630879e6c605a77b30b35aa7fc70` — preserve nested transfers and subtree scopes
3. `bd9ffec10808810bf3241bf5d28414862f8d7a1d` — add atomic hierarchy mutations and Undo
4. `750744da65b73a5d3738dd6f8a35757e4ff54e86` — unify hierarchy screens and picker navigation
5. `d2ee90198d8ff6651058f832cfab098b18e517b4` — preserve hierarchy drag selection and regression coverage
6. `c4332da57a3d9637c818fdc6861aea18726eda76` — protect hierarchy navigation from landscape suggestions
7. `7b3113ff585ec687212850ffd56f1d0091889267` — isolate hierarchy selection and canonical group routes

## Delivered behavior and storage

- Ordinary `BookmarkGroup` records form one nested tree through `parentGroupId`. Former folders convert to structural groups; they do not retain a second persistent folder type. Default remains a system group, and Home/All remain navigation and read views rather than writable parents.
- Startup stages the active unified Bookmark organization from v2 to v3 through the recoverable hierarchy conversion. It preserves UUIDs, direct membership dates, allocator state, tombstones, opaque records, aliases and existing source generations. Conversion and mutations use the journal and recovery paths; single and bulk hierarchy mutations publish atomically and support affected-only Undo.
- Direct group view shows immediate child cards and that group’s direct saved records. Subtree view includes descendants, deduplicates record IDs and keeps source membership dates. Per-group Structure/All Bookmarks preference is persisted. Picker destinations and canonical navigation use stable group IDs; explicit legacy `folderId` routes are translated without redirecting canonical Group IDs through old aliases.
- Backup v10 writes nested `parentGroupId` hierarchy and reads supported v4–v10 inputs. Export, import, selection and placement validation preserve nested structure. The non-unified legacy importer rejects nested plans before repository access rather than flattening them.
- The browser uses one scroll surface for cards and records. Group selection and post selection have distinct typed controllers and mutually deactivate. Header controls are measured and support narrow layouts, enlarged text, chip wrapping, keyboard insets and severe landscape IME geometry.

## Host verification

The exact-candidate full regression command was `./scripts/run_regression_tests.sh` at `7b3113f`; it exited 0. Counts are recorded in `.worktrees/_artifacts/content-architecture/158/final-suite-counts-7b3113.md` and `full-regression-7b3113.log`:

- Root application Flutter tests: 6,496 passed.
- Library package tests: 1,376 passed.
- CLI package tests: 286 passed.
- Two existing GoRouter tests are skipped; no other skips were reported.
- Shell checks: 39 pull-request policy cases and 20 Android release-script cases.
- Python tooling: 76 tests passed.

All Flutter/Dart commands used pinned FVM Flutter 3.47.2 / Dart 3.13.2. Ordinary tests used six detected physical cores. The successful runner retained the existing libavif build-hook notice and fixture image-fetch diagnostics; they are not live-service failures. The earlier c433 full run had one Python subprocess hang-guard timeout under competing SDK work and is not counted as a pass. The unchanged final candidate passed the complete runner without that competing work. No timeout or behavioral assertion was weakened.

Changed-Dart analysis covered 105 affected files at the exact candidate: 0 errors, 0 warnings and 331 infos, exit 0. See `final-delta-analysis-7b3113-result.json` and `.log`.

The separate serial benchmark command ran `benchmark/bookmark_mutation_latency_test.dart`, `benchmark/bookmark_pipeline_performance_test.dart` and `benchmark/scalability/workloads_test.dart` with concurrency 1; 11 tests passed. The run is recorded in `final-serial-benchmarks-7b3113-result.json` and `.log`. The host comparison in `host-evidence-summary.md` must retain these regressions (medians across 20 serial samples, at 5,000 bookmarks): shared removal increased from 4,088 µs to 14,908 µs (+265%), and rapid toggle of ten operations increased from 306,083 µs to 378,262 µs (+24%). Bulk add 20 decreased 20%; bulk remove 20 decreased 9%; existing-group add decreased 29%; final removal and Undo were approximately stable. Hydration `wallUs` was 187,012,472 µs (187.01 seconds) on the #155 predecessor and 178,760,212 µs (178.76 seconds) on this candidate; these are seconds, not milliseconds. The 1,000-bookmark pipeline run reported 1,018.1 ms / 216.0 ms predecessor write/cold-load and 797.0 ms / 208.8 ms final. These are host CPU and local-filesystem measurements, not Android frame times; filesystem and page-cache conditions are uncontrolled.

## Normal Android acceptance and legacy archive proof

The final dev-debug APK was built with `fvm flutter build apk --debug --flavor dev --target lib/main.dart --no-pub` from `lib/main.dart` at the exact candidate. APK SHA-256 is `4c66da1a59b56ef46ace6e15c087765e81aaaafab8a4f22fce970c9c5828069e`; installed provenance matches. Build and installation records are under `.worktrees/_artifacts/content-architecture/158/normal-android-build-7b3113-result.json` and `native/installed-7b3113f-source-provenance.json`.

The real normal-bootstrap UI campaign is summarized in `native/normal-main-campaign-summary.md`. Its controlled unified-v2 fixture had 106 records, including Loaded Details Group 109 and current-profile Post 110. Normal `lib/main.dart` startup opened the v2 organization and produced v3. Upgrade and subsequent cold-boot archives are byte-identical, SHA-256 `de195475d276bfe5acecff3eb70e49bb453695b834db273c4ec9fc6e0f37cd19`. The host verifier checked all 106 codec payloads, identity, memberships and dates, aliases, indexes, tombstones, allocator, Recent state, Details 109 and Post 110.

The later raw-legacy native captures `native/7b3113-legacy-upgrade.tar` and `native/7b3113-legacy-cold.tar` are also byte-identical, SHA-256 `1a7210df6bc368cde33cf92938e64264bf86c20b3da31e3774dd51c2c444755e`. Both ran the existing host-only `verify-v3-tar` Flutter test with the pinned v2 baseline from `native-fixtures/legacy-expected-v2/capture-v2/v2-source-baseline.json` and the normalized #155 semantic result in `native-fixtures/legacy-expected-v2/155-v2-migration-report.json`. They passed independently:

- Upgrade: `native/legacy-upgrade-v3-verify-7b3113-result.json`, `.log`, and `legacy-upgrade-v3-verify-7b3113/comparison.json`.
- Cold: `native/legacy-cold-v3-verify-7b3113-result.json`, `.log`, and `legacy-cold-v3-verify-7b3113/comparison.json`.

Both host comparisons assert raw `activeOrganization.version == 3` before repository opening. They match the four pinned records `[0, 5, 6, 7]`, full stored codec, memberships and dates, folder IDs and parents, and metadata. ID 5 remains intentionally unaddressable; Related ID 7 retains null preferred order. There are zero tombstones, no pending mutation, `nextId == 8`, and allocation floor 6. The two legacy folders become two structural groups: three existing groups plus two converted groups yields **five total v3 groups**, with no remaining v3 folder records. No parent addition, Details record 109 flag or profile Post 110 flag was supplied to these pure-upgrade checks.

The expected legacy-to-v2 state was generated on a disposable host copy using the pinned #155 implementation (`155-unified-bookmark-storage`, `f6deb27590a38a812c532c939085742886cdda3f`). That is synthetic host expectation data, not Android migration evidence. The device-produced raw-legacy archives are separate; the #158 host verifier copies and reads them, and checks v3 before opening the repository so verification cannot migrate a v2 archive into a false pass.

At 320dp and 2x text, the earlier exact normal UI candidate `d2ee901` exercised the broader card/timeline scroll boundary, direct/subtree search, query chips, viewer return and empty-child creation. That evidence is for the earlier source snapshot. Exact `7b3113f` separately retested severe landscape IME mode switching with query retention, mixed group selection and switching to post selection, nested group navigation/Back, membership save/remove, and Sync target persistence. The native summary identifies each Maestro YAML/result pair.

## Restoration, evidence limits and remaining scope

Restoration passed. `native/restore-verifier/archive-result.json` confirms all 132 original filesystem entries, bytes, types and modes exactly match. `restored-state-final-result.json` confirms the original APK, all 31 normalized permission lines including grant flags, settings, display size/density and stopped state. The initial broad permission comparison differed only in volatile resolver object addresses; the final parser normalizes only those object-address positions and retains negative tests for permission grants and flags. No permission grant or flag change was needed. `native/controlled-state-cleanup.json` records removal of the three owned controlled-data containers and the empty parking container; host backups remain. `.worktrees/_artifacts/content-architecture/158/emulator-lease-release-final-result.json` records successful release of the exclusive emulator lease.

The normal UI Sync checks used invented credentials for an invalid domain. No Sync Fetch, remote write, live account operation, successful source media request or live-service success is claimed. Reopening the dialog verifies the saved nested target in the UI; the root Hive archive omits the separate temporary-path settings box and therefore does not independently prove that setting. The UI-closed archive still proves all 106 record payloads/memberships unchanged after adding and removing Post 110 in the nested target, with only the expected revision +2 and Recent promotion; see `host-details-ui-roundtrip.md`. The campaign did not measure Android frame time or device responsiveness. Maestro’s short straight edge swipe committed navigation and did not establish a cancelled predictive-Back event; controlled widget tests cover cancellation and route ownership. Do not claim native cancellation/progress behavior. No future Work/Page stage is included.

## Review, continuation and publication boundary

- #158 is approved at the exact runtime SHA by independent GPT-6 Astra High. The initial `astra-high-final-review.md` CHANGES REQUIRED report applies to the earlier `c4332da` candidate; use the finalized `astra-high-final-rereview.md` for the approved result.
- Downstream #142 must carry this unified hierarchy and v10 import/export contract forward; do not restore a flat folder target or bypass the legacy nested-import preflight. #142 remains separate work.
- The user's later instruction overrides the older rollout reviewer table: **all reviews after #158 use Sol High**, including the final combined cross-stage review. #158 retains its completed Astra High gate. Routine implementation and other non-complex work may use `gpt-6-luna` or `gpt-6.1-terra`; this does not lower the independent review requirement.
- Resume #142 on its dependent isolated branch carrying this verified #158 candidate and handoff, then #143, #156, #140, #141 and #157. Completed #132/#154/#155 remain preserved. Do not restart them.
- This is a local handoff. No push, PR, merge, issue closure or publication is included. GitHub issues remain open pending separately authorized publication to shared develop.
