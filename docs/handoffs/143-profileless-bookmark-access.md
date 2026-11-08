# #143 Profileless Bookmark access: local handoff

**Status:** implementation, complete regression, final-candidate Android checks and independent Sol High final re-review passed locally. The original emulator state is restored and its lease released. The local stage gate permits #156. No publication or integration is authorized.

## Candidate and scope

- Issue: [#143](https://github.com/timberpile/Boorusama/issues/143).
- Branch: `feature/143-profileless-bookmark-access`.
- Base: `73b63f5fef412800d6106dd78cf5dc3848d28784`, preserving reviewed #142 and completed #155/#158.
- Frozen runtime: `8ecc0a5f909cbd9614c2b57c4b8a0ee8ab89a47f`.
- Remediation commits: `181fd582ce0351150c2b0926f87ed5b8451ddc80` (saved download actor), `8fa261521e7a8fb9d3f8ad3cc2abeae0f2b6fb26` (guarded streaming, local identity and safe renditions), `f2943402674f1dff6d801166f45780302930d6f0` (revoked media teardown), `8ecc0a5f909cbd9614c2b57c4b8a0ee8ab89a47f` (late stream errors and video failure ownership).
- Specification: approved contract, stage `04-profileless-access.md`, review protocol and issue snapshot retained with `.worktrees/content-architecture-reference` and local evidence. The user's later instruction requires actual **GPT-6.1 Sol High** for every independent review after #158, overriding older Astra selections.

## Behavior and boundaries

Existing exact/compatible profiles remain preferred, with ambiguity and removed originating profiles handled explicitly. A bound viewer cannot borrow another account after revocation. Public viewers pin their anonymous actor even if a compatible profile appears later. Public contexts are transient; conversion/persistence paths reject them, favorites repositories return empty, and source bindings retain the local Bookmark ID separately from upstream IDs.

Anonymous read is restricted to exact built-in HTTPS source roots and explicit API/media destinations for Danbooru, Gelbooru V2 and Moebooru installations. No suffix wildcard, imported custom installation, localhost or arbitrary imported CDN grants access. Sakuga's configured root-to-www API endpoint is allowed without merging root/www source identities; AIBooru's actual media host is `cdn.aibooru.download`. Requests are bodyless read-only requests. Every adapter-owned redirect, response publication and streaming continuation checks the current authorization/policy scope; public requests do not inherit account headers, cookies, proxy settings or DDOS authentication.

Private source-bound media uses the existing engine adapter through a scoped facade, with manual redirects and authority/installation-path-aware stripping of credentials. Public media uses the pooled guarded anonymous client. Image caches and decoded bytes include a non-secret access namespace; the wrapper retains the application's shared quota, leases, read/write sessions and atomic commits. A real disk regression caught unsafe raw JSON cache keys, now encoded as SHA-256 filenames. Auth/policy changes and disposal reject late results and cached bytes from an old key.

Bound videos use the guarded Dio and an optional leased cache for eligible small files. Large or unknown-size files, cache-disabled playback and cache acquisition failures use a bounded guarded loopback stream. The native player receives a route-local capability URL and no upstream account headers. GET/HEAD, range reads, redirects, streamed chunks and revocation remain behind the existing guarded transport; disconnect/disposal cancel owned requests. No failure falls back to the unguarded upstream URL. The optional 100 MiB cache item limit does not determine playability. Native stream errors reach terminal UI and unavailable state even after player initialization; a decoded poster cannot clear a video failure. Ordinary unbound Browse playback retains its existing path. Guarded native streaming is not implemented on Web; no Web acceptance is claimed.

Bookmark grids retain stored records and membership counts while excluding inaccessible media. One localized Kurumi indicator groups account-required, ambiguous, unsupported-reader and temporary-failure reasons without titles or URLs. Loading is not a permanent failure. Observed failures are bounded and keyed by actual access plus local record ID; retry remounts only currently permitted visible media. Public Pool/Group reading remains deferred to #156. Local bookmark management and guarded sharing remain available; server mutations and the unguarded native background downloader remain disabled. Common/Danbooru toolbars, actual grid context menus and single/multi-selection actions omit public Download. Leaf guards also deny public or revoked actors before native work. Saved downloads strictly retain the originating profile through permission/extractor/scheduling awaits and never borrow another account after removal.

The image/video cache namespace includes a process-session ID to prevent old runtime epoch numbers colliding after restart. Device evidence below proves cached use within the same process/session, not cross-restart offline cache reuse. No persistent credential hashes or tokens are introduced.

## Review findings and remediation state

### F1 — Public Bookmark actions could bypass the guarded download boundary

The actual public grid context menu and selection actions could reconstruct credential-free auth without the anonymous scope and reach the native/background downloader. Remediation now gates native Download on resolved permitted actors, prevents the public Bookmark actions from choosing the native path, and retains a fail-closed leaf guard before download providers are created. Source-bound permission/extraction/header work remains tied to the captured access actor.

Focused download/action tests passed on intermediate remediation candidates, including the stored Bookmark and selection boundaries. The frozen candidate's complete suite passed; native context/selection checks passed; independent final re-review approved the fix.

### F2 — A removed originating profile could be replaced by another account

Bookmark download projection now resolves strictly against the saved source/profile binding. Missing or revoked origins are not re-resolved using the generic compatible-profile fallback. The operation retains an access-current check across asynchronous preparation and before scheduling. A bound download may not borrow another profile's credentials, extractor, or settings.

Targeted actor-resolution, stale-operation, download scheduling, and source-header regressions were added. They are included in the frozen candidate's passing complete suite; independent final re-review approved the fix.

### F3 — Optional cache limits must not determine video playability

The reviewed implementation made playback depend on full local materialization and the optional cache's 100 MiB per-file/quota limits. The remediation changes that design: eligible small files may still use the existing guarded cache and lease; large or unknown-size files, cache-disabled playback, and cache acquisition failures use a bounded guarded loopback stream. Native players receive only the route-local URL and no upstream account headers. Upstream reads, redirects, response metadata, body limits/backpressure, cancellation, authorization revocation, and route disposal remain behind the existing guarded Dio boundary. There is no fallback to a native request to the original upstream URL. Ordinary unbound Browse playback retains its existing path.

Host socket tests cover range handling, redirect rejection, size/cache variations, in-flight revocation, request concurrency, and teardown. Lifecycle widget tests cover source replacement/disposal and failure publication. A focused lifecycle/stream/image run passed 25 tests; the frozen candidate also passed the complete suite below. A host test that accepts a declared large response does not prove Android playback/decode of large media. Android has exercised public video with optional video caching disabled; `native-remediation/8ecc-video-cacheoff-progress.png` shows playback at 0:05 of 0:13 with a changed frame. Cache-enabled native playback and same-session offline reopening also passed on this candidate (details below).

The web implementation intentionally reports guarded native streaming as unsupported, matching the existing platform limitation; no Web acceptance is claimed.

### F4 — Grid failure state must use the exact local Bookmark record

The grid's `CurrentBooruConfigScope` now receives the retained stored record identity via `storedBookmarkForPost`, preserving the selected local occurrence when an imported `postId: null` record collides with a known semantic Post ID or has no semantic index entry. Regression coverage mounts the production Bookmark group browser with known and retained records in separate groups and checks the actual tile scope. Companion tests cover terminal failure attribution, unrelated known-row success, and no-match retained records.

The focused image/bookmark regressions and frozen candidate's complete suite passed. Reopening the Bookmarks leaf after profile deletion reconfirmed the unavailable count of two on the final APK.

### F5 — A forbidden primary rendition must not hide safe alternatives

Public image presentation now filters candidate renditions through the existing `allowsMedia` policy. When the selected primary is forbidden, image and progressive viewer paths promote a permitted fallback/lower/intermediate rendition. If none is permitted, they display a terminal unavailable state with `unavailableEngine`; the rejected URL is not fetched or used for cache access. Failure reporting accepts a reason while preserving `refreshFailed` as the default, and retry removes only temporary failures. Missing, revoked, or still-loading access does not publish a permanent media failure.

Controlled image-gate tests exercise decoded safe renditions and the all-forbidden terminal state, checking request/cache isolation. Targeted image, failure-state, and real-grid tests passed, and the frozen candidate's complete suite passed. Independent final re-review approved the fix.

## Automated verification

Durable evidence: `.worktrees/_artifacts/content-architecture/143/`. Result files record command, cwd, checked HEAD, start/end and exit code.

- FVM Flutter 3.47.2 / Dart 3.13.2; six physical workers. No SDK/dependency upgrades.
- `./scripts/run_regression_tests.sh` on clean, unchanged `8ecc0a5f9`: exit 0, **6,621 application tests; 1,671 package/CLI tests; two existing GoRouter skips; 39 PR-policy shell checks; 20 release-script checks; 76 Python tests**. `full-regression-8ecc0a5f9.log` / `-result.json`, 2026-11-08 00:40:34–00:55:31 UTC. No runtime/test edits occurred during this pass.
- All 104 changed Dart files: `fvm dart format --output=none --set-exit-if-changed`, exit 0, zero changes (`format-8ecc0a5f9*`).
- All changed Dart paths: `fvm flutter analyze --no-pub --no-fatal-infos`, exit 0, **0 errors, 0 warnings, 106 informational findings** (`analysis-8ecc0a5f9*`). This is not lint-free.
- Focused final video and adjacent image/failure suites: 45 passed (`guarded-stream-formatted*`); complete frozen pass supersedes targeted results.
- Controlled tests cover exact public source trust, redirect/header stripping, pooled contexts, same-host accounts, stale results/revocation, actual disk cache leases, body/range streaming, native lifecycle, public action projection, strict download actors, local-record failure attribution and safe fallback decoding. Declared-large host range responses do not prove Android decoding of large media.
- The complete `8fa261521` run failed five old fixture/teardown checks, corrected before final verification. `f29434026` full run exited 0 but runtime/tests changed during execution; `full-regression-f29434026-evidence-limit.json` explicitly excludes it as final-candidate evidence.

The repeated SDK message `File modified during build. Build must be rerun.` was traced to hooks_runner 1.5.0 classifying a libavif output directory without a trailing separator as a file and falling back to a changing timestamp. Hook diagnostics, source mtimes and actual exit-0 test/build results are retained (`native-hook-warning-diagnostic*`). No SDK/pub-cache edits were made. An intermittent Dart VM finalizer diagnostic is retained separately from assertions. One redundant intermediate disk-cache log was accidentally removed during worker cleanup; it is excluded, while central disk and final full-suite logs remain.

## Android and live public-source evidence

Campaign: `native-remediation/`, exclusively leased `emulator-5554`, all UI control via Maestro MCP. Original data was backed up and parked before an isolated zero-profile QA seed. Checks ran at **320dp width and 2x system text**. No real account credentials, favorites or records were used.

The normal APK was built using `fvm flutter build apk --debug --flavor dev -t lib/main.dart --no-pub` on clean frozen `8ecc0a5f9`. Build and installed SHA-256 both equal `6211cabdb32908c395bc6cdb2a140da853583af46e442a3bd0eaeaa9a4e6fa71`. See `android-build-8ecc0a5f9*`, `native-remediation/normal-main-8ecc0a5f9-build-provenance.json` and `installed-8ecc0a5f9-source-provenance.json`.

The Bookmarks-only import created eight records on the separately identified `8fa261521` APK; final `8ecc` was installed in place without clearing QA data. The final APK verified:

1. Browse shows **No profiles available**. The nested leaf renders all three public thumbnails with **Unavailable: 2** (`8ecc-public-grid.png`). Sources: Safebooru Post 7294232, AIBooru Post 184763, Sakuga Post 321487; an unknown/private explicit-null Post and unsupported Pool remain stored.
2. Single-selection overflow and two-item bulk actions offer no Download. With **Open Post Menu on Long Press** enabled and asserted, the actual per-post context menu contains Select and no Download (`8ecc-single-selection-menu`, `8ecc-multi-selection-menu`, `8ecc-actual-public-context`).
3. **Enable Video Cache** was asserted false. Sakuga playback reached **0:05 / 0:13** with changed decoded frames, demonstrating native guarded streaming when the optional cache is disabled (`8ecc-video-cacheoff-progress`). Paging reached the adjacent decoded AIBooru image (`8ecc-mixed-image`). Public viewer Download is absent.
4. A separate credential-free QA profile import reports **Created 1**. Selecting it and reopening the leaf preserves the unavailable count. Deleting only that QA profile through the normal menu and confirmation returns Browse to no profiles. Reopening the full nested hierarchy again shows three public tiles and **Unavailable: 2** (`8ecc-profile-import`, `8ecc-profile-present-grid`, `8ecc-profile-removed-grid`). Storage comparisons below prove identity/date preservation.
5. Video cache was asserted true; playback again reached 0:05 (`8ecc-video-cacheon-progress`). Wi-Fi and mobile data were disabled and verified as zero. Reopening the cached video reached **0:06 / 0:13**, with a changed frame and the native **Network unavailable** banner (`8ecc-video-offline-progress`); cached public thumbnails remain visible (`8ecc-offline-grid`). Network flags were restored exactly (`offline-cycle-retry.json`). The first offline attempt opened the sort menu because its tile tap was misplaced; it is recorded as a failed UI attempt and supplies no playback evidence.

These are point-in-time public service checks. No native performance measurement, 200 MiB Android decode, exhaustive engine coverage, Web acceptance, expired-account login, or remote mutation is claimed. Cache evidence establishes reuse within a retained process/session, not across restart or all-context disposal. Earlier `8c`/`07c` campaigns separately covered reason popup scrolling/Back, search with Android keyboard, live source metadata and native import; their APKs are not relabeled as final. Current widget suites cover reason categories, retry, narrow layout, text scale and keyboard insets. Native export was not repeated; #142 and final backup suites cover that boundary.

## Storage preservation and restoration

Host verifiers read copies of actual closed Android Hive archives. `native-remediation/report-8ecc-profile-present.json` and `report-8ecc-profile-removed.json` each passed one test. They prove one canonical QA profile then zero profiles, zero persisted anonymous profiles, the same five local IDs, parent/leaf graph, memberships and all five original dates. The capture SHA-256 values are `42d83f733849dd4090f9701cdb091714009e59f3bb6e2bb9a0b7fcc0c2770acd` and `af29bfe09d412d0cb45295935173a410f0f96b46db8226177b82a024349a6987`.

Source-to-local-ID mapping is Safebooru 7294232 → 0, AIBooru 184763 → 1, Sakuga 321487 → 2, retained private/null → 3, AIBooru Pool 150 → 4. File IDs 1–5 were correctly remapped during import. All five remain members of leaf `14300000-0000-4000-8000-000000000003`, under parent `14300000-0000-4000-8000-000000000002`. Their dates in that order are 2021/2022/2023/2024/2025-02-03T04:05:06Z. No byte-identical whole-store claim across profile changes is made.

Fresh-campaign restoration passed. `native-remediation/restore-verifier/archive-result.json` compares all **132 original entries** with identical normalized member set, type, mode and bytes. `restore-result.json` and `restored-state-final-result.json` confirm the original APK SHA-256 `6fe78d249fcf41135d6ddaa175dcd61d365b91b28c59a35f4dbab084ebf9827f`, all 31 permission entries, settings, display and original stopped state. `offline-cycle-retry.json` and `controlled-state-cleanup.json` prove network baseline restoration and removal only of owned QA containers and hash-verified fixture files. Host backups remain retained. MediaStore may retain stale entries for removed campaign-only files; unrelated external rows were not changed. `emulator-lease-release-final-result.json` records exit-0 release of the exact lease.

## Review and continuation

Initial independent **GPT-6.1 Sol High** review (`sol-high-final-review.md`) returned CHANGES REQUIRED with F1–F5. The remediations above have passing full-suite and final native evidence. Fresh nonauthor **gpt-6.1-sol / High** final re-review approved `e8f55e9839a4d344f2f7fcaabaa945809ded4589` with no new confirmed findings and all F1–F5 resolved. See `sol-high-final-rereview.md`. The reviewer independently ran 61 focused tests, checked the clean tree and runtime equivalence, and reused the unchanged complete pass. The reviewer inspected recorded native/provenance/restoration evidence but did not independently repeat device actions. Existing native decoder-error propagation remains an explicit unverified limitation; relay-owned failures and image decode failures are covered. This final documentation-only update changes no runtime/test inputs. Device restoration is verified and the local stage gate is clear for #156.

After approval continue #156, #140, #141 and #157, then combined review. Preserve completed stages and leave active #144 untouched. The issue remains open until separately authorized publication. No PR, push, merge into develop, issue closure or branch deletion is authorized.
