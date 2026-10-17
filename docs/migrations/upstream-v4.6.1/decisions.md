# Upstream v4.6.1 — Decision Log

**Authoritative decision status:** **68 of 68 items approved** (2026-10-16); **none outstanding**. Local implementation was assigned to an agent on 2026-10-16. Integration into shared branches and releases are **not** authorized. This document records only the analysis and explicitly approved future behavior. See the [catalog](boorusama-v4.6.1-decision-catalog.md) and [checklist](boorusama-v4.6.1-decision-checklist.md).

## Decision Record Format

Each completed ID should record:

- **ID / date / status:** `OPEN`, `APPROVED`, `IMPLEMENTED`, or `VERIFIED`.
- **Resolution:** adopt completely / adapt for the fork / retain fork implementation / do not adopt.
- **Target behavior:** observable result and preserved fork features.
- **Data/API:** model, schema and migration implications.
- **Dependencies:** other decision IDs.
- **Verification:** specific regression tests and outcomes.
- **Rationale/sources:** upstream commit and confirmed fork code paths.

Before explicit user approval, a proposal must remain `OPEN`; technical recommendations are not binding. Record any amendment with its date and rationale.

## X01 — Bookmark Hive Field Index / Original Site Post ID

**Status: APPROVED · 2026-10-15 · Implementation pending.**

### Verified Technical Behavior

- Upstream `Post.sitePostId` means the **unchanged, original identifier assigned by the source site, as a string**, independent of the numeric/internal `Post.id`.
- This is important for Sankaku: original IDs may contain letters, whereas the Dart `int` value may be only a synthetic app ID. On conventional numeric-ID sites, `sitePostId` normally equals `post.id.toString()`.
- Upstream uses `sitePostId` for bookmark records and exports, source links, download filenames and optional metadata sidecars.
- The fork already keeps the original Sankaku ID in `SankakuPostData`. Its `StoredPostSnapshot` persists that value via `postSnapshot`; `PostOrigin` identifies the originating site, while `BookmarkIdentity` contains a site-specific stable post key.
- **Storage schema collision:** Fork Hive index **15 = `snapshotSchemaVersion`** (`int`) and index **16 = `postSnapshot`** (map). Upstream uses index **15 = `sitePostId`** (`String?`). Blindly adopting that adapter could misinterpret existing stored data.

### Approved Decision — Retain Fork Schema and Adapt Upstream Behavior

**Resolution:** The fork's existing Hive indices **15 = `snapshotSchemaVersion`** and **16 = `postSnapshot`** must remain unchanged. **Do not** adopt upstream's index-15 field for `sitePostId`. Existing bookmark databases and backups must remain readable.

**Target behavior:** Derive the true site ID for links, exports and filenames from existing post data and snapshots wherever possible. Do not create redundant persistence without demonstrated need. Internal or synthetic numeric IDs must never masquerade as external IDs.

**Implementation constraint:** If X02 revealed a concrete requirement for another persisted value, that would require a **separate** proposal for an unused Hive index and backward-compatible migration; X01 alone grants no such permission. X02 has since explicitly approved a getter **without** a new field.

**Dependency:** X02 is also approved: `sitePostId` is derived without any additional Hive field. X01's fork indices 15 and 16 remain binding.

**Rationale:** Upstream's index assignment collides with an existing fork field of a different type. Reuse already-stored original IDs rather than changing the Hive schema. Approved by the user on 2026-10-15.

### Verification

- Read and write existing fork Hive bookmarks with indices 15/16 intact.
- Preserve a non-numeric Sankaku ID exactly across bookmark → backup/restore → link/export/filename.
- Prevent collisions between equal numeric post IDs on different sites.
- Handle older/upstream-compatible backups and missing or invalid original site IDs safely.

## X02 — Post Identity/Origin versus Upstream sitePostId

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior.

**Target behavior / constraints:** Introduce a common nullable `Post.sitePostId: String?` getter. For numeric boorus, return the genuine original numeric ID as a string. For Sankaku, obtain its potentially alphanumeric ID from `SankakuPostData`. When the genuine ID is unknown, return `null` rather than an artificial fallback. Do not remodel `PostOrigin`, `BookmarkIdentity` or snapshots, or add new Hive fields.

**Verification:** Download `{id}` token, JSON sidecars, links, bookmark save/export and backup/restore; numeric/alphanumeric/missing Sankaku IDs; equal post numbers on two sites.

**Verified upstream usage:** Download `{id}`, JSON sidecars, bookmark save/restore/export and Sankaku links. Prefer a small Core-level source-ID capability instead of a Core→Sankaku dependency. The existing Hive indices 15/16 remain protected under X01. D07 further confirms that download `{id}` must use the **real site ID**, without adding a `{site_post_id}` token. Keep Pixiv's `{illust_id}_p{page}.{extension}` default filename format.

## X04 — Shared Post/Image Cache and Download Lifecycle

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior and intentionally simplify the cache.

**Target behavior / constraints:** Retain the fork's unified, persistent image cache, including URL-MD5 file keys, origin isolation, LRU, quotas, journal, checkpoints and performance fixes. Remove physical `.generation_` files and long-lived image file leases; use the URL hash as the cache filename. Publish unique temporary downloads safely/atomically only after completion. If another valid file already exists for the key, discard the competing result. Delete invalid cache files and redownload. Image sharing uses a separate temporary copy in the existing OS cache directory `boorusama-share` (potentially via `share_plus`); reuse the cleanup at app startup for files older than 24 hours, instead of adding a new service. Preserve the video cache and download observer/lifecycle behavior.

**Verification:** Concurrent cache misses, partial/failed downloads, invalidation, clearing during view/share, eviction races, restart/index/LRU, quotas, cross-site origin isolation, temporary file cleanup and A09.

**Existing fork sharing infrastructure:** `ShareMediaPreparation` already uses `boorusama-share` under app temporary storage, and `cleanupExpiredShareFiles` removes entries older than 24 hours on the next startup. The new approach needs only a cache→share copy instead of a durable cache-file lease; do not add background cleanup or promise OS-wide cache cleanup.

## A01 — Application Bootstrap, Runtime and Dependency Injection

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior.

**Target behavior / constraints:** Adopt upstream's bootstrap/runtime/dependency injection (`BoorusamaBootstrapHost`, production bootstrap, runtime, AppScope and external effects) as the **single primary startup path**, integrating **all** fork services and initialization tasks: profile UUIDs, `ImportRecoveryGate`, `DataMutationCoordinator`, `SearchRefreshLifecycle`, Following, backups, cache, GIF/share cleanup and native channels.

**Verification:** Cold start/retry, preexisting data and profiles, import/restore, Following, cache, Android/Desktop/Web, and A12 headless flows.

## A02 — Kurumi / Material-Cupertino Package Migration

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior.

**Target behavior / constraints:** Adopt the Kurumi/Material-Cupertino migration, `KurumiLikeButton`, `LinearProgressIndicator`, `PulseIndicator`, `PageIndicator` and Kurumi context menus, without a separate redesign. Retain **all** fork actions and long-press, hold-and-drag, and right-click interactions. **After implementation, the agent only writes a short prioritized manual UI acceptance checklist for the user. The user—not the agent—performs these manual checks.** Automated tests and builds remain the agent's responsibility.

**Verification:** A user-facing manual checklist covering post grid/selection/viewer/toolbar, bookmark groups, Pinned Searches/Following, search/tag chips, Danbooru favorites, sharing/GIF, profiles, download actions, desktop hover/right-click/Escape and mobile menus.

**Binding manual acceptance rule:** After UI integration, the agent documents a short checklist of important actually implemented features for user verification. **Do not have the agent perform the manual UI checks.** Automated unit/widget/build verification is still required.

## A03 — Kurumi Stability, Animation and Overflow

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adopt upstream fixes completely where they introduce no regressions.

**Target behavior / constraints:** Adopt upstream Kurumi fixes for menus, focus, Escape, animation, overflow and stability without losing fork actions or selection gestures.

**Verification:** Widget/build checks and user UI acceptance under A02.

## A04 — Responsive Settings Navigation Model

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior.

**Target behavior / constraints:** Adopt upstream responsive Settings navigation (new state model, nested pages, sidebar and minor visual changes). Preserve the existing fork Settings Search, added sections and settings, and especially the **dynamic title size in the app top bar**. Do not force an unrelated fork redesign.

**Verification:** Settings Search and destinations, phone/desktop, resizing while on a nested settings page, Back/Escape navigation and title sizing.

## A05 — Upstream Settings Search Added and Later Reverted

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** do not adopt the reverted feature.

**Target behavior / constraints:** Ignore the short-lived upstream Settings Search feature that was removed again before v4.6.1. Keep only the fork's existing Settings Search. The reason for upstream's revert has not been publicly verified (introduction `408666ef5`, revert `685db1ad5`).

**Verification:** Fork Settings Search remains fully functional after A04.

## A06 — App Lock: Different Privacy Defaults

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** fully adopt upstream defaults.

**Target behavior / constraints:** Use upstream defaults: Hide App Preview / preview blur = `false`, and lock timeout = **30 seconds**. Respect existing user-saved values during upgrade.

**Verification:** Fresh install and upgrade, saved Settings, PIN/biometric unlocking, app lock and app preview.

## A07 — Debug Logging, Log Persistence and Redaction

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adopt upstream behavior unchanged.

**Target behavior / constraints:** Integrate upstream persistent logging, log viewer, copy/export, existing redaction defaults and other settings **as provided upstream**. Do not bring forward unrelated privacy/redaction changes; a future fork logging work item will build on this. Retain fork diagnostics.

**Verification:** Startup/crash logging, persistence, copy/export, log rotation and existing diagnostic paths.

## A08 — Typed Cloudflare/DDoS Diagnostics

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** fully adopt.

**Target behavior / constraints:** Integrate detailed typed Cloudflare/DDoS challenge, solver status and error events into A07 logging while retaining fork Rule34 recovery.

**Verification:** Successful and failed challenges, redirect/loop protection and legible diagnostics.

## A09 — Android Cache Locations and DocumentsProvider

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior.

**Target behavior / constraints:** Adopt upstream cache-location settings and Android **read-only** DocumentsProvider. Expose only valid, fully saved image/video cache files; never indexes, partial downloads or unrelated private app data. Adapt to the fork's package ID/native channels and **X04's simple hash filenames**. Do not implement a second cache.

**Verification:** File-manager opening/copying, read-only access, MIME identification, Android versions, cache clear/eviction and private-data isolation.

## A10 — Embedded Windows WebView and WebView Platform Support

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream behavior.

**Target behavior / constraints:** Adopt embedded Windows WebView, browser factories, WinHTTP and unsupported-platform fallbacks while preserving existing fork Cloudflare/browser behavior.

**Verification:** Windows login/challenges, Android/iOS/macOS, navigation and unsupported-platform fallback.

## A11 — Localization: Arabic, Indonesian and Other Updates

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adopt all updates, retaining fork additions.

**Target behavior / constraints:** Integrate upstream languages/translations, including Arabic and Indonesian and language-switch fixes, without losing additional fork keys, messages or fallback behavior.

**Verification:** i18n generation, JSON/placeholders, RTL layout, regional variants and custom Following/Bookmarks/Settings strings.

## A12 — Headless Test Harness and Application Flow Tests

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt for the fork.

**Target behavior / constraints:** Integrate upstream headless app harness, fake services and app-flow tests into A01's runtime; retain fork test cases. For A02 visual/gesture verification, the agent writes a manual acceptance checklist **for the user** rather than conducting the user's manual device checks.

**Verification:** Startup, search, bookmarks, downloads, network recovery, fork app flows and deterministic tests.

## A13 — NixOS Package and Development Shell

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** optional, without a support commitment.

**Target behavior / constraints:** Adopt upstream NixOS flake, development shell and packaging changes only insofar as they are maintainable and compatible. Do not create additional official release obligations or maintenance infrastructure.

**Verification:** `nix flake check` where possible; other build systems remain unchanged.

## A14 — Release CI, Native Assets, SDK and Build CLI

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** selectively adopt.

**Target behavior / constraints:** Bring in useful upstream CI, native asset, SDK and build CLI fixes. Preserve fork flavors, split APKs, existing CI/release workflows and Flutter 3.47.2 pin. Do not blindly reintroduce upstream build changes that were reverted.

**Verification:** Android/desktop builds, CLI, CI matrix, release artifacts and A15 signing.

## A15 — APK Signing: Permanent Upstream Key

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** **do not adopt upstream signing credentials**.

**Target behavior / constraints:** Preserve the fork application ID `com.timberpile.boorusama`, flavors, existing release signing certificate/keystore, update manifest and upgrade compatibility. Never install the upstream signing key; adapt any CI signing fixes to the existing fork key.

**Verification:** Compare signing certificate before/after migration; upgrade an installed fork APK; package ID, release files and manifest.

## A16 — Versioning, Changelog and What's New Popup

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt for the fork.

**Target behavior / constraints:** Preserve Timberpile versioning, fork release history and fork changelog. Adopt the upstream fix for a recurring What's New popup. The binding version convention below supersedes older generic release guidance; verify the concrete build number and tag against actual history before release.

**Additional binding version policy (approved 2026-10-16):** Every fork release begins with the **exact upstream `MAJOR.MINOR.PATCH` version actually integrated**, followed by `-timberpile.<N>+<build-number>`. **Reset `N` to 1** when the upstream base changes, and increment `N` for subsequent fork releases based on the same upstream version; do not publish `.0`. The Flutter base build number after `+` must **increase monotonically across all fork releases** and never resets, regardless of the upstream jump. Android split-APK build codes may have ABI offsets; each effective variant must still upgrade its corresponding previous APK. The current release is `4.5.0-timberpile.5+189`, so the first v4.6.1-based release is **`4.6.1-timberpile.1+190` if no later build number has been allocated**. Otherwise select the next usable number from actual release/store history. Synchronize `pubspec.yaml`, top `CHANGELOG.md` heading, `v<version-name>` tag, GitHub updater manifest, `PackageInfo`, Gradle `flutter.versionCode` and flavor/ABI-specific codes. The prior `.agents/skills/prepare-release/SKILL.md` instruction to keep the old base and only increment the suffix **must be updated during implementation**, together with release and updater tests. Keep the fork's release history and What's New fix. This policy does not authorize releasing software or modifying `develop` now.

**Verification:** What's New appears once, upgrades from an older fork, version parsing/comparison, Changelog and update manifest, per-base counter reset and monotonic Android build codes.

## A17 — Formatting, No-op Reverts and Small Cleanups

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** treat routine maintenance without another product decision.

**Target behavior / constraints:** Handle formatting, cleanup and upstream modifications with no net effect or subsequent reverts without changing user-visible behavior. Apply only necessary lint/format corrections, avoid unrelated diffs and never revive removed features.

**Verification:** Analyzer, formatter, diff review and build.

## A18 — Web AVIF Decoder Compatibility

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt for the fork.

**Target behavior / constraints:** Integrate upstream Web and network AVIF decoder fixes while retaining the existing AVIF/ExtendedImage/fork cache pipeline.

**Verification:** AVIF on Web/Android, thumbnail/original, cache hit/miss and fallback.

## N01 — HTTP Retry-After, Rate Limiting and Admission Locks

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream and remove redundant code.

**Target behavior / constraints:** **Retain the fork's `ApiRequestCoordinator`:** centralized per-origin quotas, concurrent in-flight limits, interactive request priority, Following/preload/bulk pacing and 429 cooldowns. **Do not add** upstream's `SlidingWindowRateLimitInterceptor` as another queue. **Adopt** fixes to `packages/retriable` handling `Retry-After` (HTTP-date/seconds, especially 503), configurable retryable codes, proper overall timeout and cancellation. After checking all callers, remove the unused legacy sliding-window interceptor and unnecessary tests; consolidate duplicate parsers. Evaluate upstream pacing policies for Zerochan, Anime-Pictures and E-Shuushuu for `ApiQuotaPolicy`, without blindly replacing already established fork limits.

**Verification:** 429/503 Retry-After and total time budget, concurrent startup/cancellation, no doubled waits, Danbooru/e621/Derpi/Zerochan, Anime-Pictures/E-Shuushuu, interactive versus Following/bulk requests.

**N01 — No Duplicate Rate Limiter:** Upstream's new `SlidingWindowRateLimitInterceptor` cooldown/serialization is mostly covered by the fork's `ApiRequestCoordinator`. Adding one to `defaultDioProvider` or site clients for Zerochan, Anime-Pictures or E-Shuushuu would delay the same request twice. Integrate only relevant `retriable` fixes and site quota policies.

## N02 — Per-Profile Media-Host Overrides

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Adopt profile-specific alternate media host support and its settings UI for images, videos and downloads. Do **not** forward Authorization headers/cookies to replacement hosts without explicit, safe origin rules. Preserve post/site/profile identity and cache isolation.

**Verification:** CDN changes, previews/originals/videos/downloads, proxies, credential leaks and cache behavior.

## N03 — Cloudflare: Do Not Blindly Replay State-Changing Requests

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adopt full replay-safety fix.

**Target behavior / constraints:** Prevent blind retries of mutating requests after a Cloudflare challenge. Only repeat POST/PUT, votes, favorites and comments when idempotency is explicitly guaranteed; respect fork request context and Rule34-specific behavior.

**Verification:** Mutations run at most once, safe GET recovery, cancellation/errors.

## N04 — Cloudflare Detection, Block Pages, Redirects and Challenge UX

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Adopt upstream challenge detection, block-page and captcha confirmation, subdomain redirects, loop prevention and dialog UX while retaining fork Rule34 403 recovery.

**Verification:** 403/429, captcha, challenge redirects, no unnecessary dialog flashes or loops.

## N05 — Clearance Cookies and Native WebView Cookie Bridge

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Integrate the upstream WebView-to-HTTP cookie bridge for Android/iOS/macOS without compromising fork package ID/native channels or cookie origin, Secure and HttpOnly boundaries.

**Verification:** Solved challenges, cookie domain/subdomain scope, Android/iOS/macOS and unsupported platforms.

## N06 — HTTP/2 Window and Automatic Gzip

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Adopt upstream HTTP/2 flow-control window and gzip improvements while keeping fork prioritization, HTTP/1 and platform fallbacks, and mobile memory constraints.

**Verification:** HTTP/2 and HTTP/1, gzip, high concurrency and low-memory devices.

## X03 — Preserve Fork Export/Import, Profile UUIDs and Following

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** retain fork architecture and adapt compatible upstream components.

**Target behavior / constraints:** Preserve the fork's export/import/backup pipeline, stable profile UUIDs, `PostOrigin`/`BookmarkIdentity`, Hive/snapshot compatibility, nested Bookmark/Pinned Search folders and Following feeds, including their exact existing behavior and persisted identity. Do not revert to upstream profiles, flat folders or older feed/backup models; avoid incompatible ID/schema changes.

**Adopt selectively:** Integrate upstream's testable platform, navigation, file-picker, repository-factory and backup-trigger seams from its headless refactoring, consistent with approved A01/A12, without a parallel runtime, repository or backup layer. Do **not** install upstream's additional bookmark library refresh listener: the fork already watches `bookmarkProvider` using `BookmarkViewRefreshGate` to coordinate selection and refresh. Persistent-storage reads for favorite-tag export are separately approved under D08.

**Data/API:** X03 alone requires no new persisted fields/migrations. Retain profile UUIDs, bookmark Hive indices 15/16, post snapshots, nested folders and Following data. X01/X02 and fork import/recovery guarantees remain binding.

**Verification:** Legacy and current full-backup roundtrips with profile UUIDs, bookmark groups/subfolders, Pinned Searches/Following and favorite tags; cold-start/import recovery, profile switch, folder Undo, bookmark selection/refresh and no duplicate refresh; A01/A12 headless flows without data loss.

**Rationale/sources:** Upstream [`a3278c5d2`](https://github.com/khoadng/Boorusama/commit/a3278c5d2ecc3672fea63c68fb21c81a1db2bb07) refactors backup/bookmark test dependencies; [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8) adds refresh already covered by the fork; [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1) relates to D08. User approved on 2026-10-15.

## D02 — Bulk Download Finalization and Notifications

**Status: APPROVED · 2026-10-15 · Implementation pending.** **Resolution:** adapt upstream; preserve fork lifecycle guards.

**Target behavior / constraints:** Use the **final** upstream implementation, not the temporarily reverted timer-based version. Mark completed download records complete even if file-size resolution fails (size then unknown, log failure), and run session completion checks. Serialize concurrent checks per session with the future-based `_completionChecks` lock. Do not finalize or clean up an already completed session twice; save final statistics before deleting task/record data. Keep up to **100** recently completed sessions in an in-memory `completedSessions` download-activity list, so transient UI changes do not swallow completion notifications. Show 100% for finished activities and avoid duplicate completion notices. Do not replace the fork's notifier/session lifecycle guards and observers with the simpler upstream equivalents.

**Recovery / limitations:** The in-memory completed list is **not** a persistent notification log. Investigate crash/restart and cleanup failure windows, especially when `completed` is stored before `updateStatisticsAndCleanup` finishes. Ensure recoverable/idempotent behavior without losing stats or repeating notifications. Do not claim unverified transaction-level guarantees.

**Data/API:** Keep the existing persisted bulk/task repositories and fork lifecycle state. `completedSessions` is initially only derived runtime state. Justify and review any further persisted fields or migrations separately.

**Verification:** Concurrent completed events, out-of-order/replayed events, overlapping finalization, file-size resolver exceptions, correct totals, cleanup failure/retry, cold start/resume, visible completion notices after removal from active lists, at most one completion alert, 100-entry bound and lifecycle disposal. Combine upstream and fork tests.

**Rationale/sources:** Upstream [`ebdfb05d9`](https://github.com/khoadng/Boorusama/commit/ebdfb05d9bec5be5c6fd6dd3e5460cea8ce1e1a1) temporarily reverts the earlier deterministic path; [`54b19cd4c`](https://github.com/khoadng/Boorusama/commit/54b19cd4cf77b3a75579a2b27aeccc1b1dc56ef5) restores serialized completion, failure tolerance and notification history. The fork still has the earlier deterministic path plus custom lifecycle guards. Approved 2026-10-15.

## B01 — Sankaku Metatags, Syntax Highlighting and Typed Suggestions

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt for the fork.

**Target behavior / constraints:** Integrate Sankaku metatag definitions (including `rating`, `date`, `order`, `user`, `pool` and `fav`), parsing, typed autocomplete and safe source value mappings. Highlight metatag prefixes, but put the UI within the planned cross-site search-options interface. **Do not build a second, older upstream search bar.** Raw syntax and site capabilities remain behind the shared abstraction.

**Dependencies:** Planned unified Search UX, B02 and current fork search state.

**Verification:** Ordinary versus metatag suggestions, `fav`/`user`/`pool`, highlighting, raw query, empty/alias/unknown values, new Search UX and existing tag-chip/search behavior.

**Rationale/sources:** Verified upstream v4.6.1 commits [`2569eaeeb`](https://github.com/khoadng/Boorusama/commit/2569eaeeb6ea01ea35386ffc8bab858dcbd1d75d), [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9). User approved the complete B01–B10 batch on 2026-10-16.

## B02 — Normalize Sankaku Exclusion and Date Filters

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt with site-specific adaptation.

**Target behavior / constraints:** Present Sankaku exclusion restrictions intelligibly. For Sankaku **only**, convert a valid standalone `date:YYYYMMDD` or `date:YYYY-MM-DD` token to the API-supported single-day range. Never rewrite explicit ranges, operators, invalid dates or the visible Raw query indiscriminately; normalize at the site-specific query composer/adapter boundary.

**Dependencies:** B01/B05; the common Search composer must not apply Sankaku rules to other sites.

**Verification:** Exclusion limit/error codes, valid/invalid dates, day/year rollover, leap day, explicit range and visible versus transmitted query.

**Rationale/sources:** Verified upstream commits [`18216f412`](https://github.com/khoadng/Boorusama/commit/18216f4123586634f0756e7d5b20673638711766), [`6ad672075`](https://github.com/khoadng/Boorusama/commit/6ad672075306e5621a4dde519ad124da0b19f8cb). B01–B10 batch approved 2026-10-16.

## B03 — Preserve All Sankaku Tag Categories and Remove Duplicates

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Correctly map all known Sankaku categories including Studio (2), Genre (5), Medium (8) and Meta (9), which do **not** follow the generic fork `TagCategory.fromLegacyId` assumptions (particularly category 5). Preserve unknown categories instead of silently dropping them; deduplicate repeated API tags consistently by genuine ID or name+category, and use more useful post counts. Retain fork `PostRecord`/`PostOrigin`/snapshot/bookmark data formats; expose richer detailed tags without a persisted schema change if possible.

**Dependencies:** X01–X03 and fork tag models; do not overwrite fork post models with upstream structures.

**Verification:** Categories 0/1/2/3/4/5/8/9/unknown, duplicate names/IDs/counts, tag colors/filtering, snapshot roundtrips and older data.

**Rationale/sources:** Verified upstream commits [`d0fde834a`](https://github.com/khoadng/Boorusama/commit/d0fde834a413658bb50db150636c481c88a88222), [`396ae059e`](https://github.com/khoadng/Boorusama/commit/396ae059e9e5576aa0172df7fabf823963c03e92). B01–B10 approved 2026-10-16.

## B04 — Sankaku Authentication: API Headers, Invalid Credentials, Session Recovery

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Preserve existing Dio options/interceptors/headers when merging Sankaku API headers. Strictly validate login responses before saving tokens. On a clearly expired/invalid token, retry safe **GET** requests at most once after controlled reauthentication; coalesce concurrent re-logins per client; invalidate only the token actually rejected, respecting client/profile isolation. **Never blindly retry mutating Favorites/POST/DELETE.** Show the error and allow fresh login for subsequent user actions. If automatic reauth fails, use existing profile login UI. Never log tokens/credentials.

**Dependencies:** N01/N03/N04/N05, existing fork profile/credential model and cross-origin credential protections.

**Verification:** Invalid login credentials/token shapes, 401/API auth errors, parallel GETs, repeated rejection, profile switches, header/cookie retention, favorites without double mutation, cancellation, rate limiting and credential redaction.

**Rationale/sources:** Verified upstream commits [`829ec71fb`](https://github.com/khoadng/Boorusama/commit/829ec71fbaedbc60fff7d98fe1b40c494a130ebe), [`6ad691a6d`](https://github.com/khoadng/Boorusama/commit/6ad691a6de23d8a44c46d02bf3640997dbb618f4), [`6762d00f2`](https://github.com/khoadng/Boorusama/commit/6762d00f2e4ac6efc99bf969bd15a335f6767437), [`8757eb295`](https://github.com/khoadng/Boorusama/commit/8757eb2953d41716bc7c8fb3a028b71fb3f03e2c). B01–B10 approved 2026-10-16.

## B05 — Explain Sankaku Search Limits

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt fully within fork error UI.

**Target behavior / constraints:** Convert Sankaku codes for anonymous/account tag limits into clear, localized error messages attached to the fork error layer. Keep the existing fallback for unknown server errors.

**Dependencies:** B02 and existing error translator/i18n.

**Verification:** Anonymous/account limits, exclusion limits covered by B02, localized strings, unknown errors and retry.

**Rationale/sources:** Verified upstream commit [`5b495f1ad`](https://github.com/khoadng/Boorusama/commit/5b495f1adec13643ee83307bb2b68eb0272766b2). B01–B10 approved 2026-10-16.

## B06 — Shimmie2 Media Formats and Favorite Fallback

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Normalize media extensions from `ext` fields, filenames and file URLs (lowercase, no leading period). Add server-provided Favorite status where an extension supports it and the user is authenticated, but retrieve it optionally/asynchronously after normal post loading. The timeline must not block on slow/failed Favorite endpoints or missing login. Merge late results with already completed user actions and the current Favorite cache rather than overwriting them; treat errors as soft failures and surface known authentication problems meaningfully.

**Dependencies:** Fork Favorite repository/cache and Shimmie2 capabilities.

**Verification:** Media extensions/URL forms, missing extensions, GraphQL/REST, batches of 100 IDs, Favorite lookup with/without login, error/timeout and a Favorite mutation during in-flight lookup.

**Rationale/sources:** Verified upstream commits [`2d4f8484b`](https://github.com/khoadng/Boorusama/commit/2d4f8484ba62db8e5c5386825934b1bcc30455cf), [`d79ef1fcc`](https://github.com/khoadng/Boorusama/commit/d79ef1fcc9f59b07933e76681b6c033e12327460). B01–B10 approved 2026-10-16.

## B07 — Gelbooru v2: Comment Upvotes and Cursor Pagination

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Integrate upstream Gelbooru v2 comment-page keys, Rule34 HTML comment/score parsing and cursor pagination into fork Comment/Post models. Upstream supports **comment upvotes only, no downvotes**—do not add a fictional downvote action. Show voting only under an explicit site capability and a valid user session. Treat a mutating GET upvote as a **mutation** despite the HTTP method, and never replay it automatically after challenge/retry; display auth and operational errors. Other Gelbooru v2 sites retain their current comment fetch behavior.

**Dependencies:** N03/N04, B08, fork comment/selection UI and site capabilities.

**Verification:** Rule34 HTML/script scores, comments/quotes, cursor forward/end, repeats and sort changes, login/no login, score/action errors, post-ID mapping, no duplicate votes during Cloudflare 403.

**Rationale/sources:** Verified upstream commit [`f459e9922`](https://github.com/khoadng/Boorusama/commit/f459e99220e4ac5b449c033d1d60a0b672ea2b58). B01–B10 approved 2026-10-16.

## B08 — Gelbooru v2: Comment Sorting

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt together with B07.

**Target behavior / constraints:** Offer `Newest`/`Oldest` sorting only on sites whose explicit comment capabilities support it (upstream: Rule34). For Rule34 use the `comments_direction` cookie and merge it safely with existing session cookies. Remember the choice only within the current comments view, without another persisted profile setting. Fully reset pagination/cursor on sort switch; hide options for unsupported sites.

**Dependencies:** B07 and site feature/sort capabilities.

**Verification:** Newest/Oldest, cookie isolation, cursor reset, rapid switches with late requests, single-page results and reload.

**Rationale/sources:** Verified upstream commit [`43619dd49`](https://github.com/khoadng/Boorusama/commit/43619dd495d5cb79425845521f0a0e0de030670d). B01–B10 approved 2026-10-16.

## B09 — Nozomi Tag Counts and HTTP Range Encoding

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Determine Nozomi tag counts from post-index file sizes rather than search buckets. Use targeted byte-range requests with `Accept-Encoding: identity`, correctly handling 200/206/404/416 responses, `Content-Range` and cache/fallback paths. Throttle concurrent count lookups through the fork's `ApiRequestCoordinator` so tag autocomplete and Following do not generate excessive host requests.

**Dependencies:** N01, fork Nozomi client/rate policy.

**Verification:** File bytes divided by four, partial/full responses, missing Content-Range, 404/416/zero, Range+gzip, cache, quotas/429, concurrent suggestions and cancellation.

**Rationale/sources:** Verified upstream commits [`7880a020f`](https://github.com/khoadng/Boorusama/commit/7880a020fc7ba968351ee5256d3685c347d4eca0), [`5a4498f78`](https://github.com/khoadng/Boorusama/commit/5a4498f78dbce67aa43c0d3d01c4fc8d31784a23). B01–B10 approved 2026-10-16.

## B10 — Rule34 JSON Post API at api.rule34.xxx

**Status: APPROVED · 2026-10-16 · Activated after targeted live verification on 2026-10-17.** **Resolution:** adapt; activate only after verification.

**Target behavior / constraints:** After targeted **live API tests**, switch the Rule34 post listing endpoint to `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1`. The fork already uses that host for details. Preserve profile/site identity, authentication/cookie origin boundaries, parsing, pagination, rate limits and Rule34 Cloudflare/403 recovery. If incompatible, assess the cause instead of forcing an untested host change.

**Dependencies:** N01/N02/N04/N05 and current Rule34 `boorus.yaml` settings.

**Verification:** JSON list/details, pagination/filter/limit, auth/no auth, CORS/redirects, 403 challenge, rate limit/429, content shape, cross-host credentials and cache isolation. Targeted authenticated host and Android client checks passed on 2026-10-17, after fixing Dio's null representation of a bodyless empty listing. Android native cookie fixtures also passed. See [the remediation report](REVIEW_REMEDIATION.md) for exact coverage and remaining limits: successful CAPTCHA solving, browser CORS execution, a real 429 and live cross-profile cache isolation are not claimed.

**Rationale/sources:** Verified upstream commit [`5972548ec`](https://github.com/khoadng/Boorusama/commit/5972548ecd6e32622b8476776490251d61d6a099). B01–B10 approved 2026-10-16.

## P02 — Preserve Profiles with Unknown Thumbnail Actions or Media Host Rules

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Tolerantly parse unknown/invalid optional thumbnail action values and media-host overrides without rejecting the entire profile. During import/restore, present understandable validation warnings. Always preserve existing profile UUIDs and unrelated data. Retain uninterpretable future option values in source data if technically safe for forward compatibility; otherwise fall back **only** for that affected option, with a documented warning.

**Data/dependencies:** No changes to profile UUIDs or identity. Coordinate P01's now-approved thumbnail action migration and N02 media-host rules with this fallback/warning model.

**Verification:** Old/new profile JSON, unknown action, missing/malformed host/type, duplicate quick actions, restore without profile loss and visible import warnings.

**Rationale/upstream source:** [`1d8c879f4`](https://github.com/khoadng/Boorusama/commit/1d8c879f406d54df86c25d334ace0ada98846886). Approved explicitly on 2026-10-16; P01 was subsequently approved as well.

## P05 — Refresh Bookmark Library After Bookmark Mutation

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** retain the fork implementation.

**Target behavior / constraints:** Do **not** install a second upstream bookmark listener. The fork already observes `bookmarkProvider` and coordinates visibility/selection updates through `BookmarkViewRefreshGate`. Keep this as the sole authoritative refresh path, adding only useful upstream regression tests.

**Data/dependencies:** No API or data migration. This overlaps the binding X03 safeguard.

**Verification:** Add/remove bookmarks, Undo, group switch, sort, filter, details overlay, stable selection and exactly one visible refresh per mutation.

**Rationale/upstream source:** [`3f4ce2bd4`](https://github.com/khoadng/Boorusama/commit/3f4ce2bd4f0f94c116b2262fa9418809710278a8). Approved on 2026-10-16.

## P06 — GIF Autoplay Respects Quality Settings

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Respect the grid GIF autoplay setting at all quality levels, including `original`: with autoplay off, load only static previews; with autoplay on, load animated grid GIF variants only within the **5 MiB original-file-size threshold** specified below. Otherwise show a static thumbnail. Smaller static GIF thumbnails are **not** guaranteed low-resolution *animated* GIF variants. Danbooru often supplies static 180/360/720 thumbnails and an animated original. Do not invent unavailable animated previews. Explicit post viewers retain their own quality/playback rules.

**Data/dependencies:** Keep fork-specific Danbooru variant URL resolution and generic thumbnail resolver; no persisted data migration.

**Verification:** Danbooru and other boorus; Automatic/Low/High/Highest/Original × autoplay/static, sample present/missing, URL/aspect ratio, original sizes zero/unknown/exactly 5 MiB/5 MiB+1 byte, animated samples unable to bypass the threshold, no extra HEAD/GET probing and unaffected explicit viewer/download paths.

**Additional binding safeguard (approved by user 2026-10-16):** Across **all post-grid and timeline surfaces**, automatically request an animated GIF **only when autoplay is enabled and the genuine original GIF size is known, strictly positive and ≤ 5 MiB (5 × 1024 × 1024 bytes)**. For larger, absent, invalid or zero-defaulted lengths, request a **static** image, even when quality is manually set to `Highest`. Animated `sample` variants are also subject to the conservative *original-size* limit: Danbooru `VariantDto` contains sample URLs/dimensions/extensions but **no per-sample byte length**. Do not allow an unbounded sample GIF to bypass the guard. For a sufficiently small original GIF, retain the already selected animated sample/original source per the quality policy; do **not** force Highest to Original. `post.fileSize` comes from Danbooru `PostDto.file_size`; `fileSize <= 0` means **unknown**, not approved for animation. Do **not** issue HEAD probes or separate original downloads solely for length checks; use existing API metadata. On other boorus, enforce this criterion where the reported length can reliably be identified as the original GIF's size. This applies only to automatic grid/timeline animation, **not** the explicit post viewer, manual original view or downloads. It limits large file transfers but does **not** guarantee low decoder/CPU cost.

**Verified GIF quality behavior (2026-10-16):** In `lib/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart`, **manually selected Highest** resolves ordinary/large Danbooru grid tiles to `PostQualityType.sample`, which can contain **animated GIF data** (observed by the user). The GIF branch uses raw `settings.imageQuality`. By contrast, **Automatic**, even at the largest grid size, uses the static `720x720` variant path instead of applying `resolvedImageQuality`; the generic resolver would map `GridSize.large` to Highest. Therefore, do **not** equate Automatic/Large GIFs with manually chosen Highest. **Target behavior:** autoplay on plus Highest may keep using animated samples **only below the 5 MiB limit**; autoplay off means static even at Highest. Preserve automatic grid-size quality tiers; P06 does **not** authorize a new animation policy for Automatic/Large. **Upstream v4.6.1 limitation:** [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663) fixes the generic GIF resolver and primarily the Danbooru Original case when autoplay is off; the Danbooru Highest branch still requires the fork's additional guard. Cover both paths in tests.

**Rationale/upstream source:** [`e4d645630`](https://github.com/khoadng/Boorusama/commit/e4d6456309c93f050b3a5d311ea4e2a60e0a7663). User confirmed P06 and the subsequent 5 MiB protection on 2026-10-16.

## P07 — Keep Video Thumbnail Until First Rendered Frame

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Keep the video thumbnail/poster visible until the first frame is **actually rendered**, then transition smoothly to the player. Reset first-frame state at every source or playback-engine switch and ignore obsolete asynchronous signals using a generation/source identifier. If the first-frame signal fails, show a visible error or fallback, not an indefinitely hidden player. Preserve fork video viewer, cache, Hero transitions and thumbnails.

**Data/dependencies:** First-frame signaling for supported `BooruPlayer` engines; runtime state only, no migration.

**Verification:** Slow initialization, cached versus streamed media, MPV/MediaKit/video_player/WebView, rapid URL switches, first-frame/player errors, dispose/reinitialize, overlays and transitions.

**Rationale/upstream source:** [`2003c0c1e`](https://github.com/khoadng/Boorusama/commit/2003c0c1eb2cf6b3ef0939b33adf1b575fcae8f9). Approved on 2026-10-16.

## P11 — Video Controls: Time Overflow and Media Play/Pause Keys

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt with fork player compatibility.

**Target behavior / constraints:** Do not constrain video time labels to a fixed 40 px width; allow a flexible layout with sensible minimum. Route hardware MediaPlay/MediaPause/MediaToggle only to the current visible/focused video post. Never unexpectedly start playback for image posts, hidden players or a focused text field. Preserve existing player engines and viewer shortcuts.

**Data/dependencies:** No persistence. Check U04/U05/U06 keyboard-shortcut interactions.

**Verification:** Long durations/narrow screens, text scaling, MediaPlay/MediaPause/MediaPlayPause, image vs video, focus/page changes and supported engines.

**Rationale/upstream sources:** [`c65a81074`](https://github.com/khoadng/Boorusama/commit/c65a81074f123eed5efbe368a8a44985dd8340cf), [`72bafb43d`](https://github.com/khoadng/Boorusama/commit/72bafb43d3e5063749ce663277201b01ea644a54). Approved on 2026-10-16.

## P12 — Hover Preview Opens Only from Info Badge; Preserve Long Press

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Open hover previews through a dedicated **Info badge** rather than on hover over the whole thumbnail. Show the badge appropriately for pointer hover/focused keyboard navigation. Adopt pointer hit-test and gesture fixes for long press, right click and hold-and-drag. Selection has priority over the Preview badge; dismiss hover previews cleanly on keyboard input. Coordinate badge placement with the approved P01 two-action layout and Series-group tiles. Avoid cluttering the thumbnail with permanent overlays.

**Data/dependencies:** UI only; no new persisted fields. Respect existing `tooltipDisplayMode`.

**Verification:** Desktop hover/info-badge click, touch long press, right click, hold-and-drag selection, Keyboard/Escape/text input, compact grid tiles, Series cards and disabled tooltip setting.

**Rationale/upstream sources:** [`e04b3bfd1`](https://github.com/khoadng/Boorusama/commit/e04b3bfd186e8b5b88ab704189e23178ae26d098), [`5da94c1df`](https://github.com/khoadng/Boorusama/commit/5da94c1dfa6a39ef34c21c6ba1d171267ee06928), [`5feaa3dcf`](https://github.com/khoadng/Boorusama/commit/5feaa3dcf0a5069afab3f95594b3935fe08f7150). Approved on 2026-10-16.

## P13 — Migrate Post/Tag Context Menus to Kurumi

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt alongside A02.

**Target behavior / constraints:** Unify post and tag context menus using Kurumi, preserving consistent keyboard, right-click, long-press, Back/Escape and visual behavior. Retain **every** fork menu action: favorites, bookmarks, Following, group operations, submenus, context-versus-selection priority and existing tap-through/dismiss safeguards. Do not mechanically replace the fork's `KurumiContextMenuPageController` and `CustomContextMenuOverlay` customizations with upstream's broad migration. Implement compatible functionality in one menu component.

**Data/dependencies:** No persistence; coordinate with A02 and use the anchor dependency fix only at a compatible lockfile revision.

**Verification:** Post/Tag/Grid/Selection, long press, right click, nested submenus, Escape/Back, focus return, outside click, RTL, compact layouts, tag cloud and overlay stacking.

**Rationale/upstream sources:** [`8ca15fcff`](https://github.com/khoadng/Boorusama/commit/8ca15fcff2e461488bc4ced314700196d421deb5), [`1e480b775`](https://github.com/khoadng/Boorusama/commit/1e480b7751a359931c53057e86a42ff56a1c6672). Approved on 2026-10-16.

## P14 — Keyboard Focus on Quick Favorite/Bookmark Buttons

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt while coordinating P01/A02.

**Target behavior / constraints:** Give visible Quick Favorite/Bookmark and other thumbnail actions accessible semantics, focused states and Enter/Space activation. With up to two actions, offer predictable order and arrow/Tab navigation without hijacking tile open, grid selection, scroll or hold-and-drag gestures. Hidden buttons must not be focusable.

**Data/dependencies:** No schema changes. Depends on the now-approved P01 layout and A02 focus/Kurumi changes.

**Verification:** Keyboard/TV focus, Enter/Space/Arrow/Tab, recycled scrolling items, selection, hidden/disabled actions, small tiles and clear focus indication.

**Rationale/upstream source:** [`d1047aa89`](https://github.com/khoadng/Boorusama/commit/d1047aa890c64b3baa575e0ca16f50b4724e6826). Approved on 2026-10-16.

## P03 — Retry Failed Images Using Targeted Error Controls

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Use the final upstream fix calling `ExtendedImageController.reload()` rather than the earlier full-surface `GestureDetector`. Show a conspicuous, focusable Retry button within `ErrorPlaceholder` in the fork grid and post viewer. Tapping elsewhere on a tile must still open the post and respect selection/hold gestures. The fork's `ProgressivePostImage` uses its own staged candidate/loading-generation pipeline and must permit a controlled retry of the failed target/fallback request **without discarding a successfully decoded lower-resolution image**. Avoid endless automated retries or uncontrolled disk-cache deletion.

**Data/dependencies:** No persisted migration; adapt `packages/extended_image` API, fork progressive image loader and shared cache while preserving X04 invariants.

**Verification:** Primary/fallback/progressive failures, reload target while holding visible placeholder, retry after 403/timeout/corrupt cache, tile tap vs Retry, selection/long press, accessibility/keyboard, no infinite request loop.

**Rationale/sources:** [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df), [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50). Approved after technical discussion on 2026-10-16.

## P04 — Preserve Grid Refresh Requests During Fetches

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** retain fork refresh queue/race safety and supplement it.

**Target behavior / constraints:** Keep the existing `PostGridController` with `_refreshPending`, `_pendingMaintainPage`, `_pendingPreserveSelection` and `_queuedRefreshWaiters` as the **one and only refresh queue**. Add upstream's latest-result protection: when a new search, refresh or profile change arrives while a fetch runs, do not publish the obsolete result even transiently. Instead fetch the latest requested state and publish its result. Do not surface obsolete errors as final UI failures if the latest pass succeeded, but still handle actual final errors and all awaiting Future callers correctly. Do not add another upstream queue or reset selection.

**Data/dependencies:** No migration; related to Following Topics, automatic search edits, profile switching and P05/X03 bookmark refresh gate.

**Verification:** Controlled concurrent fetch/refresh, old response never rendered, latest query/profile snapshot wins, failure before successful follow-up, maintainPage/preserveSelection flags, pending Futures, dispose, duplicate fetches and loading state.

**Rationale/source:** [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f). Approved after discussion 2026-10-16.

## P08 — WebView Video Playback from Cached File and Cleanup Protection

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt; protect active video-cache lifetime.

**Target behavior / constraints:** Adopt upstream's WebView playback of local cached video via a small local HTML document, MIME derived from `VideoSource`, restricted local file access and safe serialized cleanup of prior temporary WebView pages. Avoid the unreliable existing Base64/10 MiB fallback. The fork's `VideoCacheManager` does not currently guarantee active-file protection: prevent eviction, expiration and explicit cache clearing from deleting the video while player/WebView is reading it, using a short-lived per-file usage lease/refcount. Release the lease on video/engine changes, errors and dispose; then remove any deferred deletions. Do **not** revive image cache generations or keep video leases beyond active playback. If the cached video file is missing/corrupted, fall back to remote streaming cleanly without leaking auth/cookies into unauthorized local-file or origin contexts.

**Data/dependencies:** Usage protection belongs in video cache (`packages/cache_manager/lib/src/video_cache_manager.dart`), separately from X04's image cache. `CachedVideoSource` must have a valid local path, and temporary HTML pages should be cleaned reliably on close/restart; no persisted schema change required.

**Verification:** Small/large/unknown-size cached video, WebView on Android/iOS/macOS, concurrent players, evict/clear while playing, expiration, source/engine changes, local HTML/file races, stale startup cleanup, remote fallback and file-read restrictions.

**Rationale/sources:** [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0). Approved after discussion 2026-10-16.

## P09 — Kurumi InteractiveViewer: Image Pan vs Page Swipe

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt; preserve fork gestures.

**Target behavior / constraints:** With an unzoomed image (near 1×), horizontal/vertical PageView swipes should win over `InteractiveViewer` panning; after zooming, allow pan/pinch. Integrate upstream's zoom-dependent `panEnabled` and `ScaleGestureRecognizer.panCausesAcceptance` arbitration as required. Vendor Flutter 3.47.2 recognizer/widget code only if a smaller compatible solution does not work reliably with the pinned SDK. Preserve **all** fork behavior: classic double-tap/fit cycle, snap zoom-to-fit, image boundaries, automatic comic strip, original-on-zoom and `ZoomEdgePageGesture` with **160dp edge pull** and Retry/LoadMore/Page actions. Never enable pan and page swipe simultaneously or consume pointer events twice.

**Data/dependencies:** No persistence. Coordinate with A02 Kurumi changes and pinned Flutter. Any vendored code requires a narrow justified scope and upgrade strategy.

**Verification:** Fast horizontal/vertical flick at 1× under Android gesture slop, pinch zoom, pan beyond 1×, 160dp edge threshold, zoom/media presentation changes mid-gesture, mouse/touch/stylus, rotation, double tap, original-on-zoom, selection and hardware zoom tests.

**Rationale/sources:** [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3), [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe). Approved after discussion 2026-10-16.

## P10 — Consume Volume Keys Correctly in the Post Viewer

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt with eligible viewer gating.

**Target behavior / constraints:** When `volumeKeyViewerNavigation` is enabled and the post viewer is visible and not in expanded mode, Volume Up (+) navigates to the **next** post, and Volume Down (-) to the **previous**. Return handled (`true`) for related Down/Repeat/Up events, including at the first/last post. When disabled, viewer hidden or expanded, return unhandled (`false`) so normal system volume control works. Do not unintentionally navigate more than once due to Repeat/Up events. Preserve existing `isKeyPressed` down detection and Android/hardware limits. This opt-in mode also navigates between video posts.

**Data/dependencies:** No persisted schema changes; retain existing setting/global keyboard handler.

**Verification:** Down/Repeat/Up, first/last post, viewer visible/hidden, toggle on/off, expanded mode, video/image, system volume outside viewer and no double navigation.

**Rationale/source:** [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44). Approved after discussion 2026-10-16.

## P01 — Two Quick Actions on Post Thumbnails

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt; retain origin-specific fork post presentation.

**Target behavior / constraints:** Adopt upstream's two per-profile configurable thumbnail quick actions (primary/secondary: site-default/favorite, bookmark, download, artist or None), with adaptive compact horizontal/vertical placement. Primary/secondary must be distinct; secondary is disabled when primary is None. Preserve the prior single primary choice by default, set secondary None. On cramped tiles display only primary. Group actions bottom right and score bottom left; selection hides both and wins. For grouped/Series cards, do not apply a post-specific mutation to an arbitrary single member; first determine a clear, appropriate action target.

**Mandatory fork compatibility:** Preserve the per-post boundary introduced on 2026-09-24 in [`c00ac614f`](https://github.com/timberpile/Boorusama/commit/c00ac614f8fb5849e57f924b6bfeaaf8a22a057c): `PostGridItem` resolves `PostGridItemAdditions.quickActionButton` using the **concrete `post.origin`/`BooruPostPresentation`**, and passes it as `defaultActionButton` to `DefaultImagePreviewQuickActionButton`. This override takes precedence over `booruBuilder.quickFavoriteButtonBuilder` **only for the selected Default action**, not for explicit Bookmark/Download/Artist choices. `DanbooruPostGridPresentation` provides `DanbooruQuickFavoriteButton` with Banned post behavior. Resolve this correctly for **each post**, even with two actions, in mixed-booru feeds, bookmarks, Following and custom fallbacks; do not render favorite controls for the selected profile on unrelated posts. Preserve explicit `quickActionButton` overrides and selection guards.

**Data/migration:** Migrate legacy single string setting `defaultPreviewImageButtonAction` losslessly to `thumbnailActions` (primary, optional secondary), retaining existing profile exports/imports and UUIDs. Use P02 tolerance for unknown/invalid choices and never silently reset valid settings.

**Verification:** Legacy actions/default fallback, site-default in mixed feeds, banned/unsupported posts, equal primary-secondary/None cases, legacy JSON roundtrip, tiny tiles/large text, selection/hold-and-drag, Series cards, score/Info badge overlap under P12, pointer/touch/TV/keyboard P14.

**Source:** Upstream [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655). User approved P01 after clarifying the fork-specific `defaultActionButton` semantics on 2026-10-16.

## U01 — Keep Search Usable Above the Software Keyboard

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Adopt upstream search fixes when the soft keyboard is visible. Fit the suggestion overlay within available space (`fitToAvailableSpace` or equivalent adaptive placement), honor `MediaQuery.viewInsets.bottom` for top-/bottom-positioned search, and keep results/input scrollable. Do not replace the planned compact unified fork Search UI, its per-term Raw Editor, automatic search and tag/metatag suggestions with the legacy upstream search bar. Keep entered text, selected chips and suggestions visible at 320dp, in landscape, after rotation and with large text, without unnecessarily dismissing the keyboard.

**Data/dependencies:** Unified Search UX redesign, B01–B05 and U03; retain existing profile/search sessions and A02 UI components.

**Verification:** Phone small/normal/landscape, top/bottom position, keyboard open, 1.5–2× text scaling, rotation, suggestion selection, per-term Raw Editor, visible selected chips and adapted upstream headless keyboard tests.

**Rationale/upstream source:** [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89). User approved U01 on 2026-10-16. This is a decision, not proof of implementation.

## U02 — Search History as a Full-Height Sheet and Tests

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt.

**Target behavior / constraints:** Present mobile Search History in a scroll-controlled bottom sheet (`isScrollControlled: true`) with useful available height. Keep history scrolling, keyboard/safe-inset handling and responsive navigation. Preserve existing search history, filters, Pinned Searches, Following and search state restoration without a separate history migration. Adapt upstream flow tests.

**Data/dependencies:** Fork SearchHistory route and SearchProfileSession, U01/U03 and new Search UX entry.

**Verification:** Many history entries, search/filter, correct query selection, keyboard/Back/Escape, returning from route, limited viewport height and no duplicate search action.

**Rationale/upstream sources:** [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11), [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71). Approved 2026-10-16.

## U03 — Keyboard Highlight and Selection for Tag Suggestions

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Use a focus-preserving Kurumi Listbox or equivalent shared mechanism for suggestions: Up/Down changes visible highlight, Enter inserts the selected entry, Escape initially clears the highlight without removing focus from the search input. Subsequent Escape/Back follows Search and layer rules. Mark highlighted list items accessibly and scroll them into view. Use consistent keyboard behavior on desktop, hardware keyboards/TV and the single-term Raw Editor. Do not draw duplicate focus rings around the input/search bar or route keys to hidden screens. Support ordinary tags and metatags exposed through the planned shared Search Options interface.

**Data/dependencies:** B01, Search redesign, U01/U04–U06 and A02 Kurumi; no duplicate search controller or old chip editor.

**Verification:** Forward/reverse suggestion navigation, Up/Down/Enter/Escape, list after filter change, Tab/Shift-Tab, input focus retained, Raw query and single-term editor, with/without soft keyboard, scroll to highlighted entry and no key leakage to background pages.

**Rationale/upstream sources:** [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61), [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b), [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5). Approved 2026-10-16.

## U04 — App-Wide D-Pad and Keyboard Navigation

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt; TV is best effort.

**Target behavior / constraints:** Integrate directional focus navigation (D-pad/arrow keys), focus rings visible only when a keyboard/remote is actively used, scroll-to-focused-item, and sensible traversal across FocusScopes, drawers, sidebars, toolbars, viewers and dialogs. Adopt upstream `KurumiDirectionalFocusAction`, focus-ring utilities, key handling and test harness in a fork-compatible way. Preserve touch/mouse operation and prevent activation of hidden controls. TV/remote remains explicitly **best effort**, not a newly supported official TV platform with support/release obligations.

**Data/dependencies:** A02, P01/P13/P14, U03/U05/U06 and existing fork navigation and panel choices.

**Verification:** D-pad/Enter/Back across start/browse/profiles/search/settings/viewer/dialogs, crossing focus scopes, scroll reveal, offstage controls, text editing versus navigation focus, pointer/keyboard switching and ring only in keyboard mode; headless flows.

**Rationale/upstream sources:** [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8), [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0), [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0), [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d), [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde). Approved 2026-10-16.

## U05 — Desktop Tab Order and Focus Boundaries

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Establish pane-specific Tab/Shift-Tab order and `FocusTraversalGroup`/`FocusPane` for the current sidebar, profile switcher, Settings Search, search results, browse/viewer and dialogs. Prioritize **visible** focus targets over offstage or scrolled-out content. Show focus rings when using a keyboard, hide them after mouse/touch input and return focus to the trigger after closing a dialog/popover. Avoid unintended focus scopes that interrupt flat/nested navigation; preserve the current fork Settings/sidebar architecture.

**Data/dependencies:** U04/U06, fork Settings Search and responsive Settings panes (A04), P14.

**Verification:** Tab/Shift-Tab and directional arrows across pane boundaries, long settings lists, visible controls in Explore/Viewer, focus return after dialog/sheet, dynamic layout/routing/scroll and large text.

**Rationale/upstream sources:** [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20), [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253), [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141), [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0), [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae), [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8), [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69). Approved 2026-10-16.

## U06 — Escape Handling, Menu Selection and Layer Hierarchy

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Use a fork-compatible `KurumiDismissible`/BackHandler or equivalent to establish one predictable Escape/Android Back precedence for nested layers: **innermost active submenu/popup/popover first, dialog/sheet second, search editing/suggestion state next, active selection next, route/screen last**. Respect actual Router/PopScope/modal boundaries, including non-dismissible or dirty forms. Close exactly one layer per keypress, return focus to the opener and do not pass keys to hidden pages. Preserve fork context menus, multiselection and no-tap-through safeguards; coordinate with P13/A02 Kurumi.

**Data/dependencies:** U03–U05, P13 and existing fork routers plus `CustomContextMenuOverlay`/`KurumiContextMenuPageController` extensions.

**Verification:** Nested submenu/popover within dialog/sheet, Escape/Android Back, Selection plus Search, nondismissible dialog, multiple nested Navigators, no double handling, focus return and no click-through on posts.

**Rationale/upstream sources:** [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829), [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f), [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c), [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987). Approved 2026-10-16.

## U07 — Favorite Tags Editor as Dialog on Large Screens

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt while preserving fork labels.

**Target behavior / constraints:** Keep the Favorite Tags editor as a keyboard-inset-safe bottom sheet on phones, and use a centered **max-width 520px** dialog at larger Kurumi screen breakpoints. Make contents scrollable regardless of keyboard height or advanced options. Preserve Add/Edit/Raw Query and all fork label options, warnings and actions. Follow fork responsive breakpoints and existing Settings modals.

**Data/dependencies:** Fork favorite-tag and label management, U01/U04/U06.

**Verification:** Phone/tablet/desktop, keyboard open/closed, large text, changing advanced options and label chips, invalid/duplicate tags, Submit/Cancel/Escape and restoration.

**Rationale/upstream source:** [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7). Approved 2026-10-16.

## U08 — Update Regression Tests and Remove Timing Flakiness

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** test-only with related feature migrations.

**Target behavior / constraints:** Adopt the intent of upstream tests (Info-badge hover after P12 and bulk dry-run/session state after D02), but adapt to current fork widgets/APIs and deterministic clocks/completion signals rather than copying fixed sleeps or flaky polling loops. U08 introduces no standalone UI/product behavior or new storage. Update tests alongside their respective feature changes.

**Data/dependencies:** P12/D02, fork regression suite and runner/headless flows (A12).

**Verification:** Hover preview opens only via Info badge and closes on keyboard/mouse/selection; bulk dry run/resume/status free of wall-clock races; idempotent session-lifecycle tests and controlled Futures/events.

**Rationale/upstream source:** [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed). Approved 2026-10-16.

## D01 — Download Sidecars: TXT Tags and JSON Metadata

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Implement optional sidecars next to the **actual saved media filename**: `<media>.txt` with one tag per line, or `<media>.json` containing tags, genuine site/post ID where available, safe public source URLs, actual quality and filename. Provide a **global Off default** and an optional per-bulk-download-task override (Default/Off/TXT/JSON), but no extra profile setting. Integrate individual, bookmark and bulk downloads plus direct media cache copies via the same safe, observable completion path. Freeze an immutable post/task metadata snapshot **before** transfer so retry and background recovery do not depend on UI providers. Publish sidecars atomically **only after confirmed transfer completion**; deduplicate/sort tags, never overwrite unrelated or different existing sidecars, and surface conflicts as separately recoverable failures. A sidecar failure must not redownload or corrupt successfully stored media. With `skip if exists`, leave an existing media file and its sidecar untouched even if the sidecar is missing. Never export secret cookies, auth headers, signed download URLs, local API endpoints or local file URLs. Adapt upstream storage/background callbacks/recovery to fork lifecycle/observer logic. D07 defines the genuine site ID used in JSON metadata.

**Data/dependencies:** Likely additional nullable sidecar configuration in global Settings, bulk task/record snapshots and an additive SQLite migration (upstream schema version 2), while preserving all existing rows. Sidecar journal/state must survive crash/reboot/retry without duplicating D02 completion events. No changes to the existing bookmark/post Hive schema. Sidecar-only retry must not enqueue another media download.

**Verification:** Default Off, TXT/JSON, single/bookmark/bulk/video-cache media, skipped existing files with/without sidecar, conflicting metadata, read-only/scoped storage, disk full, crash before/after media or sidecar write, background isolate callbacks, restart recovery, metadata-only retry, zero/multiple tags, UTF-8/newlines, URL/credential redaction and origin identity.

**Rationale/sources:** Upstream [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19). Approved 2026-10-16; D07 was subsequently finalized.

## D03 — Background Downloader Plugin Update

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt pinned plugin commit after verification.

**Target behavior / constraints:** Upstream changes the Git-pinned `khoadng/background_downloader` dependency from `e8ad9f9` to `fd67fff9ee4ad4cdf415dc3285289cad9289cefe` **without changing package version 9.6.1**. Inspect commit differences and native/API compatibility before adopting. Only with a successful result, update `pubspec_overrides.yaml` and the lockfile consistently. Do not replace fork callbacks, Cronet transport/resume, Android filesystem permissions or persistence. Test jointly with D01, D02 and D04. If the new pin is incompatible, document the blocker and retain the old pin pending a fix.

**Data/dependencies:** Git dependency/lockfile update, no dedicated DB migration. Check native platform/build behavior separately.

**Verification:** Android foreground/background, app restart, pause/resume, retry/cancel, notifications, Cronet, media cache/sidecar completion, task IDs, Android builds and iOS/desktop where supported.

**Rationale/source:** [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf). Approved 2026-10-16.

## D04 — Download Manager: Injectable Task Client and Snapshot Fix

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** fully adopt while retaining fork lifecycle behavior.

**Target behavior / constraints:** Introduce injectable `DownloadTaskClient` operations for pause/resume/retry/cancel, resume eligibility, file path and size queries, following upstream's testability boundary; actual enqueuing remains with the fork download service. Copy the prior task-group list **before** mutating (`[...?totalTasks[group]]`), so old state snapshots remain immutable. Prevent closing one broadcast StreamController twice: a single provider owns and disposes the controller. If useful, add upstream's central `DownloadTaskEventIngress` that publishes both to the retained snapshot and stream. Preserve fork retry/headers/DDoS/notifications/DownloadActivity integration.

**Data/dependencies:** Narrow provider/interface layer without database changes; retain task IDs and notification/state structures. Coordinate with D02/D03.

**Verification:** Three or more updates to the same task produce immutable previous snapshots and complete listener events; disposal without double close; stream and snapshot ingress consistency; retry/cancel/pause/resume via a fake client including auth and bypass headers; concurrent and grouped tasks; file size errors.

**Rationale/sources:** [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9), [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff). Approved 2026-10-16.

## D05 — Anime-Pictures Bulk Downloads and Request Pacing

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Enable Anime-Pictures bulk downloading and multi-page tasks through the site's capability configuration. Represent upstream's conservative pacing (about **one request per second** per relevant API/download-link origin) **only** in the fork's `ApiRequestCoordinator` and site-specific N01 quota; never install another `SlidingWindowRateLimitInterceptor`. Remove the indefinite `_downloadUrlCache` from `AnimePicturesClient` because links/session cookies can expire. Retain the fork's bounded five-minute `AnimePicturesDownloadFileUrlExtractor` cache, but verify login changes, retries after auth failures and short-lived link behavior. Retrying must be able to obtain fresh signed URLs/cookies. Preserve profile and Following identity boundaries, bulk task persistence and download UI.

**Data/dependencies:** Adjust site capability and generated booru config (regenerate generated files only after changing source YAML), N01 quotas/Retry-After and D02/D04 lifecycle. No additional parallel rate-limit layer.

**Verification:** Multi-page bulk jobs, 429 and Retry-After, expired download link or session switch, concurrent profiles, cookie handling, cached link hits, cancel/pause/resume, pagination cursor and recovery.

**Rationale/source:** [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f). Approved 2026-10-16.

## D06 — Zerochan Bulk Downloads and URL Resolution

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt.

**Target behavior / constraints:** Remove the explicit Zerochan bulk-download disablement **after** stable URL extraction has been integrated and verified. Prefer explicit `full`/`large`/`medium`/`small` URLs, file size and format from the post detail API. If the original URL is missing or JSON malformed, request the specific post's HTML page. Use the HTML path reliably for Asiachan's broken detail API. Validate source/host URLs and distinguish 404/410, redirects, transient auth failures and rate limits. Provide `Preview`, `Sample` and `Original` per post; **when Original is explicitly selected, never silently save Preview or Sample in its place**—report unresolved original instead. Coalesce duplicate concurrent resolution requests and use a short five-minute cache. Apply conservative pacing (~one request per **1.2 seconds**) via the fork's `ApiRequestCoordinator`, with no parallel sliding-window interceptor; preserve fork filename/metadata/observer/bulk lifecycle.

**Data/dependencies:** Extend nullable Zerochan DTO fields and post/adapter mapping; add site download URL extractor and capabilities, quality-aware single-download action. Coordinate N01/N03 and D02/D04. Cache only valid URLs and keep site/profile contexts separate.

**Verification:** Zerochan and Asiachan API/HTML responses, missing original URL, 404/410, wrong HTML/metatags, explicit Original versus degraded variants, Preview/Sample, redirect/auth/429, simultaneous resolution of one post, cache expiry, filename/extension/size and bulk skip/retry.

**Rationale/source:** [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce). Approved 2026-10-16.

## D08 — Export Favorite Tags Directly from Storage

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adopt.

**Target behavior / constraints:** For full Favorite Tag backups, replace reads from potentially uninitialized UI state (`ref.read(favoriteTagsProvider)`) with persistent storage access via `await ref.read(favoriteTagRepoProvider.future)` and `await repo.getAll()`. Extend the principle to other full backups and export paths that incorrectly take incomplete UI provider snapshots, including revision/automatic backups. Preserve current import semantics `repo.replaceAll(tags)` and `ref.invalidate(favoriteTagsProvider)`, supported backup versions and label/raw-query serialization. Keep the separate explicit "Export (simple) to clipboard" action distinct from the full-backup format.

**Data/dependencies:** D08 alone needs no backup schema or persistence migration. Preserve X03 identity/import/recovery and A12 headless tests.

**Verification:** Cold-start full backup without opening Favorite Tags, uninitialized UI state, multiple labels/raw query/Unicode, automatic/server/file/clipboard backups, full roundtrip without duplicate tags, replace-all on import and provider invalidation.

**Rationale/source:** [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1). Approved 2026-10-16.

## D07 — Preserve Original Site Post IDs in Exports Instead of Only Numeric IDs

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt; use upstream's new `{id}` filename semantics in the fork.

**Target behavior / constraints:** Provide the X02-approved `Post.sitePostId: String?` getter for the **true original ID on the source website**. For conventional numeric boorus, return the genuine post number as a string; for Sankaku return the original numeric/alphanumeric `SankakuPostData` ID; for Pixiv return the original `illustId`, not the synthetic page-specific `Post.id`. When unknown, return `null`; **never** pass off a synthesized internal ID as a real site ID. Derive source ID via existing post/codec capability with no direct Core→Sankaku/Pixiv dependency.

**Download filenames:** Change the existing `{id}` filename token from `post.id.toString()` to genuine `post.sitePostId`, as upstream does. **Do not add** a second `{site_post_id}` token. Backward compatibility of download filename templates is not a current requirement because the fork's download feature has hardly been used. **Keep Pixiv's own default `{illust_id}_p{page}.{extension}` template unchanged** so different pages of one artwork get distinct names. Custom Pixiv formats containing only `{id}` can collide; existing file skip/conflict rules must prevent unintended overwrites. For missing genuine IDs when the format uses `{id}`, choose a safe fallback filename explicitly **not presented as the site ID**, or display an intelligible failure. Never output synthetic `Post.id` as the genuine ID.

**Exports/data migration:** D01 JSON sidecars, external post links and other export metadata referring to original site IDs should use `post.sitePostId`. Current v5 bookmark backups already include the real Sankaku ID in `snapshot.custom.sankakuId`. Keep import v4/v5, `StoredPostSnapshot`, `PostOrigin`, `BookmarkIdentity`, profile UUIDs, bookmark groups and Following identity unchanged. No extra `Bookmark.sitePostId`, new Hive index or backup version bump. In particular preserve fork index 15=`snapshotSchemaVersion` and 16=`postSnapshot`; do not copy upstream's conflicting index-15 field.

**Verification:** Numeric/alphanumeric/missing IDs and Pixiv; filename `{id}` on Danbooru/Gelbooru/Sankaku/Pixiv including Pixiv's unchanged multi-page default, custom Pixiv `{id}` conflicts, safe filenames for unknown IDs, real IDs in links and D01 JSON sidecars, unchanged Hive 15/16 and backup v4/v5 roundtrips, and isolated identical numeric post IDs across different site installations.

**Rationale/source:** Upstream [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9). The user expressly chose to switch `{id}` to the true site ID on 2026-10-16 after reviewing Pixiv behavior and the lack of download filename backward-compatibility needs. This is a planning decision, **not** authorization to implement in any unrelated branch.

## Remaining Decisions

**All 68/68 decisions APPROVED; 0 OPEN.** Every migration decision is finalized. These are **planned behaviors, not implemented software**. On 2026-10-16 the user commissioned local agent implementation of the complete plan (see [`IMPLEMENTATION_HANDOFF.md`](IMPLEMENTATION_HANDOFF.md)); remote pushes, integration into `develop`, PRs and release publication require separate permission. U08 is approved as test-only work alongside related features.
