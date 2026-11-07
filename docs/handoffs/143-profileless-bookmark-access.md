# #143 Profileless Bookmark access: local handoff

**Status:** implementation, complete regression and Android acceptance verified locally. Independent Sol High final review is pending. Do not start #156 before that gate passes. No publication or integration is authorized.

## Candidate and scope

- Issue: [#143](https://github.com/timberpile/Boorusama/issues/143).
- Branch: `feature/143-profileless-bookmark-access`.
- Base: `73b63f5fef412800d6106dd78cf5dc3848d28784`, the reviewed #142 handoff, preserving #155 and #158.
- Runtime candidate: `07c9b6978cc4470b1b5371cf2c70546d57659009`.
- Implementation commits: `fc1d11c0a19ad90ca31a58452ab5aa1b79eedff4` (public read boundary), `8c4de312f5ed4181337ddb51d120d649f4124797` (source-bound media and unavailable states), `2e4f540e7fd0e39e735e98eee39952815e6740fa` (controlled transport fixtures), and `07c9b6978cc4470b1b5371cf2c70546d57659009` (public viewer download controls).
- Specification: the approved contract, stage `04-profileless-access.md`, review protocol and live issue snapshot in `.worktrees/content-architecture-reference` / local evidence below. The user's later instruction requires actual **GPT-6.1 Sol High** for every independent review after #158, overriding older Astra selections.

## Behavior and boundaries

Existing exact/compatible profiles remain preferred, with ambiguity and removed originating profiles handled explicitly. A bound viewer cannot borrow another account after revocation. Public viewers pin their anonymous actor even if a compatible profile appears later. Public contexts are transient; conversion/persistence paths reject them, favorites repositories return empty, and source bindings retain the local Bookmark ID separately from upstream IDs.

Anonymous read is restricted to exact built-in HTTPS source roots and explicit API/media destinations for Danbooru, Gelbooru V2 and Moebooru installations. No suffix wildcard, imported custom installation, localhost or arbitrary imported CDN grants access. Sakuga's configured root-to-www API endpoint is allowed without merging root/www source identities; AIBooru's actual media host is `cdn.aibooru.download`. Requests are bodyless read-only requests. Every adapter-owned redirect, response publication and streaming continuation checks the current authorization/policy scope; public requests do not inherit account headers, cookies, proxy settings or DDOS authentication.

Private source-bound media uses the existing engine adapter through a scoped facade, with manual redirects and authority/installation-path-aware stripping of credentials. Public media uses the pooled guarded anonymous client. Image caches and decoded bytes include a non-secret access namespace; the wrapper retains the application's shared quota, leases, read/write sessions and atomic commits. A real disk regression caught unsafe raw JSON cache keys, now encoded as SHA-256 filenames. Auth/policy changes and disposal reject late results and cached bytes from an old key.

Bound videos are acquired through the guarded Dio into a leased local file before native playback. Transfers and actual file size are bounded, quota ownership is serialized, partial writes cannot become cache hits, and revocation cancels pending work. The optional-cache-disabled path uses an ephemeral lease and deletes the file after the final owner releases it. Ordinary unbound Browse video retains its existing streaming path. Source-bound video requires complete file materialization, with a 100 MiB per-file cap; it does not provide progressive native network streaming. Route closure/rejected preparation never falls back to an unguarded player URL.

Bookmark grids retain stored records and membership counts while excluding inaccessible media. One localized Kurumi indicator groups account-required, ambiguous, unsupported-reader and temporary-failure reasons without titles or URLs. Loading is not a permanent failure. Observed failures are bounded and keyed by actual access plus local record ID; retry remounts only currently permitted visible media. Public Pool/Group reading remains deferred to #156. Local bookmark management and guarded sharing remain available; server mutations and the unguarded native background downloader remain disabled. Both common and Danbooru viewer toolbar paths now omit public Download controls, with an additional leaf guard before download providers are constructed.

The image/video cache namespace includes a process-session ID to prevent old runtime epoch numbers colliding after restart. Device evidence below proves cached use within the same process/session, not cross-restart offline cache reuse. No persistent credential hashes or tokens are introduced.

## Automated verification

Durable local evidence root: `.worktrees/_artifacts/content-architecture/143/`. Each `run_check.py` result records command, working directory, checked HEAD, start/end and exit code.

- Pinned FVM Flutter 3.47.2 / Dart 3.13.2; ordinary concurrency is six physical workers. No SDK/dependency upgrade.
- `./scripts/run_regression_tests.sh` on exact runtime `07c9b6978`: exit 0, 2026-11-07 23:03:51–23:17:01 UTC. **6,597 application tests; 1,671 package/CLI tests; two existing GoRouter skips; 39 PR-policy shell, 20 release-script shell and 76 Python tests.** See `full-regression-07c9b6978.log` and `-result.json`.
- All 91 changed Dart files: `fvm dart format --output=none --set-exit-if-changed`, exit 0, zero changes. See `final-format-07c9b6978*`.
- All changed application/test Dart paths: `fvm flutter analyze --no-pub --no-fatal-infos`, exit 0: **0 errors, 0 warnings, 71 informational findings**. See `final-analysis-07c9b6978*`. The earlier broader-directory analysis had 174 infos; do not describe either run as lint-free.
- Earlier 412 affected app tests and the complete 68-test cache-manager package suite passed; the final complete suite supersedes these intermediate passes. Controlled tests cover redirects/credential stripping, rejected unknown hosts, shared clients, two same-host accounts, stale pending responses, scope disposal, real disk writes/leases, cached image/frame paths, bounded video preparation, route disposal, failure counting/retry, shares and public action guards.
- Initial full run at `8c4de312f` failed 14 old media fixtures because their fake covered only the ordinary Dio path. `2e4f540e7` routes the separate media-override path into the controlled transport, preserving assertions. The five affected fixture files passed 116 tests; the full suite then passed at `2e4f540e7` and again on final `07c9b6978`.

The SDK repeatedly prints `File modified during build. Build must be rerun.` The durable native-hook diagnostic traces this to hooks_runner 1.5.0 treating a libavif output directory without a trailing separator as a file; its fallback modification timestamp changes each pass. The diagnostic's minimal test, hook status, source mtimes and final exit-0 test/build results are retained in `native-hook-warning-diagnostic*`. No SDK/pub-cache edits were made. This message is reported separately from assertion failures. One redundant intermediate disk-cache rerun log was accidentally removed during worker artifact cleanup; it is excluded from evidence. The central disk-cache logs and exact final complete suite remain available.

## Android and live public-source evidence

Normal `lib/main.dart` development APKs were built using `fvm flutter build apk --debug --flavor dev --target lib/main.dart --no-pub`. Final `07c9b6978` APK SHA-256: `b05b9eb035c1998fa6654a57f71337162a9875606f08e7008622a12dbd9f514e`. Build and installed correspondence: `native/normal-main-07c9b6978-build-provenance.json` and `native/installed-07c9b6978-source-provenance.json`. Earlier `8c4de312f` APK is separately identified and never relabeled as the final build.

The campaign exclusively leased `emulator-5554`; all UI control used Maestro MCP. Original app data was backed up and parked before a controlled zero-profile seed was installed. Checks ran at **320dp width and 2x system text**. The fixtures contain four Post records (including one unknown/private explicit-null upstream ID) and one unsupported public Pool, nested under `143 Parent` / `143 Public and unavailable`. Public source metadata and video HEAD were captured separately; these are point-in-time service checks, not account access.

On `8c4de312f`:

1. Normal Android Bookmarks-only import completed with **Created 8**, while Browse still showed no profiles. Imported hierarchy opened; three public thumbnails decoded, and the compact unavailable count was **2**. Its explanation grouped one matching-profile-required and one unsupported-public-reader record without exposing their metadata.
2. Sakuga post 321487's 1,614,000-byte MP4 played with visible frame/time progression, without a saved profile. Paging reached a decoded AIBooru image (184763) and Safebooru image (7294232).
3. After disabling both Wi-Fi and mobile data, reopening video played from cache with visible progression, and the AIBooru image remained visible. Connectivity/settings evidence and screenshots are retained. Network service settings were restored.
4. Importing only the separate credential-free `QA public reader` profile created canonical ID `14300000-0000-4000-8000-000000000001`. Selecting it loaded Safebooru normally; the saved Safebooru image opened under the profile. Deleting only this QA profile through the normal context menu and confirmation returned Browse to **No profiles available**.

On exact final runtime `07c9b6978`:

5. Cold launch again showed no profiles. The nested leaf displayed the same three decoded public previews and unavailable count 2 (`native/final-public-grid.png`). Sakuga video and AIBooru image opened again; public Download controls were absent (`final-public-video-toolbar`, `final-public-video-progress`, `final-public-aibooru`).
6. Wi-Fi and mobile data were disabled again and verified as 0. Reopened cached video progressed from 0 to 7 seconds of 13, with changed decoded frames (`final-offline-video-open.png`, `final-offline-video-progress.png`); paging retained the decoded cached AIBooru image (`final-offline-aibooru.png`). The three original network flags subsequently matched baseline exactly.
7. The reason popup remained bounded and its complete notice could be reached by scrolling at enlarged text (`final-explanation-scrolled.png`); Back dismissed it. The search field was also exercised with the actual Android keyboard visible (`final-keyboard-visible.png`). Opening the explanation while the keyboard remained open was not separately established on-device; targeted widget coverage exercises that inset case plus Escape, count refresh and retries.

The profile creation/removal actions ran on `8c4de312f`. The final runtime differs only by three Download toolbar guards; do not claim those earlier actions were rerun on exact `07c9b6978`. The final device run separately covers cold restart, zero-profile display, public media, offline use and the changed toolbar behavior. No native frame-performance measurement, exhaustive live engine coverage, expired-account login or remote favorite mutation is claimed. Native Bookmarks export was not repeated in this stage; #142 evidence and the final backup regression suites cover that boundary.

## Storage preservation and restoration

Host-only verifiers read copies of actual closed Android Hive archives. `native-verifier/report-profile-present.json` and `report-profile-removed.json` prove five retained records, exact source/upstream identities (including explicit null), stable local IDs, parent/leaf relation and all five original membership dates through profile removal. Native import correctly remaps file IDs 1–5 to local IDs 0–4; comparison uses source identity and then requires the same local mapping after removal. No all-snapshot-byte comparison is claimed across recovery/profile changes. Both reports show no persisted anonymous profiles.

The final `07c9b6978` root-Hive archive is byte-identical to the verified post-removal archive: SHA-256 `908a8e36df8d3acba639c9d9b9200ae3b42cb474fd2b2b3b07f0d350c0e82c08`; see `native/final-hive-byte-comparison.json`. Thus the final media campaign did not alter the verified saved state.

Restoration passed: `native/restore-verifier/archive-result.json` compares all **132 original entries** with identical normalized member set, type, mode and bytes. `restore-result.json` and `restored-state-final-result.json` verify the original APK (SHA-256 `6fe78d249fcf41135d6ddaa175dcd61d365b91b28c59a35f4dbab084ebf9827f`), 31 permission entries, display/settings and original stopped state. `network-restored-final.json` and cleanup checks verify network baseline. `controlled-state-cleanup.json` records removal only of owned QA containers and hash-verified staged fixture files, preserving host backups. MediaStore may retain stale entries for those removed campaign-only files; unrelated external rows were not changed. `emulator-lease-release-final-result.json` records successful release.

## Review and continuation

Independent final review must use a fresh, nonauthor **gpt-6.1-sol / High** context and inspect the complete base-to-candidate delta plus these actual verification limits. Review is pending; this handoff does not clear the stage gate. After approval, continue #156, #140, #141 and #157, then the combined review. Preserve completed #132/#154/#155/#158/#142 and leave active #144 untouched. The GitHub issue remains open until separately authorized publication. No PR, push, develop merge, issue closure or branch deletion is authorized.
