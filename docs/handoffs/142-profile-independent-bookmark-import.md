# #142 Profile-independent Bookmark import: local handoff

**Status:** implementation and final-candidate verification complete. Independent GPT-6.1 Sol High approved the runtime and completed evidence on 2026-11-07. This handoff records local completion; it does not authorize publication or integration.

## Candidate and implementation

- Issue: [#142](https://github.com/timberpile/Boorusama/issues/142)
- Branch: `feature/142-profile-independent-bookmark-import`
- Base: `b9405fdbd5312a797d8165d556d48785d183881d` (completed #158 hierarchy, carrying the preserved #155 storage implementation).
- Runtime candidate: `3faddca3bcbd2b9be5ba32872e88ad9e16b35a96`.
- Runtime commits:
  - `564addcbf63f109d405b1c55f07fef8e86d26510`: optional Bookmark profile hints and preview wording; required Following Topic references still control account selection and errors.
  - `4a22ec4e17e344ed200185725a5af011319f2236`: retain unavailable records, filter presentation through existing strict source policy, and restore exact local IDs during trusted transaction rollback.
  - `3662e5ac0a9216b561da2e79e1c7569b3a221436`: initialize lazy production Bookmark storage before acquiring the import snapshot lock.
  - `3faddca3bcbd2b9be5ba32872e88ad9e16b35a96`: revoke media and source actions immediately when the originating account disappears, before asynchronous grid refresh completes.

Valid Bookmarks import without matching profiles. Optional hints cannot select or poison the account chosen for required Topic references. Structural integrity, engine/payload compatibility and supported Group codec checks remain required. Import does not create profiles, probe a source for importability, invent an upstream ID or weaken #155's explicit-null-ID handling. Normal file-local ID mapping remains unchanged.

Merge, Update, Merge Into and Replace preserve complete Post/Group snapshots, loaded Details, hierarchy, memberships and dates. Unavailable records remain in storage, total membership counts and export projections; ordinary media grids and covers exclude them. Adding/removing compatible profiles recomputes presentation without rewriting Bookmarks. No anonymous reader, unavailable-count indicator or #143 feature is included.

The shared transaction rollback previously reused ordinary import, which restored content under new local IDs after late failure. A separate trusted local-preimage path now restores known tombstoned original IDs. Recoverable mutation journal version 3 records and validates the restored-ID whitelist. It neither lowers the allocator nor revives unknown reserved gaps. Ordinary upserts/import/Undo retain their existing deleted-ID rules; external file, clipboard and nearby inputs cannot invoke trusted restoration. This mutation journal version is distinct from the inherited v3 organization and v10 transfer format.

The cold-import deadlock was reproduced on Android at `4a22ec4` and with production Hive factories in a host regression. Lazy initialization tried to acquire the same mutation coordinator already held by preflight. Initializing the Bookmark provider after package preparation and before snapshot locking fixes that ordering without changing the global coordinator.

## Automated verification and independent review

All Flutter/Dart commands used pinned FVM Flutter 3.47.2 / Dart 3.13.2. Ordinary test concurrency was six physical cores.

The complete final-candidate command `./scripts/run_regression_tests.sh` passed at `3faddca3b`, exit 0, ending 2026-11-07 17:15:51 UTC. Evidence: `.worktrees/_artifacts/content-architecture/142/full-regression-3faddca-result.json` and `.log`.

- Application: 6,506 tests passed.
- Packages and CLI: 1,662 tests passed; two existing GoRouter tests skipped.
- Shell: 39 pull-request policy cases and 20 Android release-script cases passed.
- Python tooling: 76 tests passed.

Affected-Dart analysis passed with 0 errors, 0 warnings and 42 informational findings: `final-delta-analysis-3faddca-result.json` and `.log`. Final formatting checked all 21 affected Dart files with zero changes (`final-dart-format-3faddca-result.json`). The successful runs retained the existing libavif build-hook notice and occasional fixture/finalizer diagnostics; these are disclosed rather than interpreted as live-service evidence. No timeout or behavioral assertion was weakened.

Independent reviewer: actual `gpt-6.1-sol`, High effort, fresh nonauthor context. The initial review at `3662e5a` found a P1: a stale tile could borrow account B's auth after its hinted account A was removed. The renderer now uses the strict resolver directly, suppresses stale mixed-grid indices during refresh, and rechecks profiles for viewer/selection actions. The canonical test starts with A+B and asserts disappearance on the first pump after removing A. The reviewer's unchanged adversarial probe was RED on `3662e5a` and GREEN on `3faddca`; 90 independent focused tests passed. Initial and final reports: `sol-high-final-review.md` and `sol-high-final-rereview.md` under the same artifact directory. Final verdict is **APPROVE**, with no unresolved findings, covering runtime `3faddca` and the clean documentation candidate `aa11228476bec7ad67a6d765eb42233709e0db37`. This final status/evidence update changes documentation only.

Controlled host tests also cover zero HTTP creation during profileless import, all four import modes, repeated compatible ID reuse, unknown-schema zero writes, exact-ID late-failure rollback, stale-plan zero writes, journal boundary faults and cold reopen. Widget checks cover profile changes, same-site ambiguity/revocation, retained group counts and deferred hidden-browser previews.

## Normal Android acceptance

The normal final-source APK was built with `fvm flutter build apk --debug --flavor dev --target lib/main.dart --no-pub`. SHA-256: `e6b3c540f9c565ce068dfc741bf638040483c21ac199cedfbb1f4ee91bb05d12`. Build and installed-source correspondence are recorded in `native/normal-main-3faddca-build-provenance.json` and `native/installed-3faddca-source-provenance.json`.

The exclusively leased `emulator-5554` campaign used a controlled zero-profile seed, synthetic invalid-domain source and separate Bookmarks-only/profile-only packages. Original user data was parked separately and backed up before isolation. UI control used Maestro MCP. Checks ran at 320dp width and 2x system text.

1. Actual cold import at `3662e5a`, without first opening Bookmarks, completed with zero profiles and seven creations: four records and three imported groups, in addition to Default. Restart and nested navigation retained the hierarchy. The package contains an addressed Post, an explicit-null-ID Post, a Pool with loaded Details and Related with null preferred order.
2. A real Bookmarks-only Android export before profile creation matched both the input fixture and actual stored baseline. File `native/export-before-profile-3662e5a.bsexport`, SHA-256 `c485a623f86e285c08aac07b1240742ac392427aefde46185cf9ad2056e02934`.
3. Installed final `3faddca` restarted with no profiles. Explicit profile-only import created one matching anonymous synthetic profile. Reopening Imported Groups / Fixture parent / Fixture leaf displayed the previously excluded Pool. `native/3faddca-matching-profile.tar` has SHA-256 `abb1c5d69556b47131e1b2de17bf0df990e57d91131b329a6cb6268313976004`.
4. Deleting that profile through the normal profile context menu restored Browse's no-profile state. Nested groups remained navigable while media disappeared. A real Bookmarks-only export succeeded afterward: `native/export-after-profile-removal-3faddca.bsexport`, SHA-256 `44207077569f480ec1501c5ddf6472bde589407561bc05cc95c05118f567d3d9`.
5. A final cold restart again showed no profiles and retained nested navigation without the Pool card. Post-removal and cold archives are byte-identical, SHA-256 `9eaeea45c287dffed8542173187e20f13c9eb9f390debb435d4930820eddefa8`.

The first cold import was on `3662e5a`; its import/storage code is unchanged in `3faddca`, whose only subsequent runtime change is the renderer revocation guard. Final-source restart, profile creation/removal, presentation and export were exercised separately. Do not relabel the earlier cold import as an exact-final-SHA device run.

Host verifiers read copies of actual closed Android archives, checking raw active organization version 3 before repository initialization. `native-verifier/run-import/baseline.json`, `run-profile-final/result.json`, `run-profile-removed/result.json` and `cold-byte-comparison.json` establish unchanged full StoredBookmarkCodec payloads, local IDs, group graph, membership dates, indexes, tombstones, allocator and revision through profile changes and cold restart. The profile matches its fixture except for existing normalization from null proxy settings to disabled `ProxySettings.unknown()`. The tightened verifier explicitly checks that exact value, including proxy credential fields, and reruns the complete storage comparison: `profile-exact-proxy-final-result.json` and `native-verifier/run-profile-exact-proxy/result.json`, exit 0. The earlier helper asserted only the differing field name; use the tightened result for the exact-value claim.

Production package validation in `native-verifier/run-export-after-removal/result.json` checks manifest/part checksums, sole Bookmarks source, credentials flag false, all four complete transfer records and the complete four-group graph. Before/after payloads differ only in their top-level export `date`, generated by `DateTime.now()` in `data_converter.dart`; every stored record and membership date remains equal. Whole ZIP/payload byte equality is not claimed.

## Restoration and limits

The emulator disappeared during an intermediate capture. Its 512-byte archive is explicitly excluded in `native/excluded-captures.json`. The same Windows Phone1 AVD restarted without wipe, reset or snapshot restore. Both parked datasets remained intact; a recovered valid archive matched the complete import baseline. The original cached Maestro connection required a fresh task-owned MCP connection; later standard MCP control also resumed. Failed route/IME selectors are retained as diagnostic attempts, not counted as passing acceptance flows.

Original restoration passed: `native/restore-verifier/archive-result.json` compares all 132 original filesystem entries, bytes, types and modes exactly. `restore-result.json` and `restored-state-final-result.json` verify the original APK, 31 normalized permission entries including grants/flags, settings, display size/density and stopped state. `native/controlled-state-cleanup.json` records removal only of campaign-owned controlled-data containers, the empty original parking container, hash-verified staged fixture files and the two QA exports/owned export directory. Host backups remain. `emulator-lease-release-final-result.json` records successful lease release.

The campaign used a synthetic invalid domain. No successful live-service or decoded-media request, remote account mutation, native frame timing or device responsiveness is claimed. Host controlled tests establish the immediate A+B revocation boundary; the native campaign separately exercised a single matching synthetic profile. Anonymous access and source trust policy belong to #143.

## Continuation and authorization

Preserve completed #132/#154/#155/#158 and this hierarchy/storage/import contract. The final Sol High approval clears local continuation to #143, then #156, #140, #141 and #157, followed by the combined review. The user's later instruction requires **Sol High for every review after #158**, overriding older plan tables. Routine implementation and non-complex tasks may use GPT-6 Luna or GPT-6.1 Terra.

No PR, push, merge into develop, issue closure, remote branch deletion or publication is authorized. The issue remains open pending separately authorized shared publication.
