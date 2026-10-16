# Upstream v4.6.1 — Decision Log

**Authoritative decision status:** **68 of 68 items approved** (2026-10-16); **none outstanding**. Local implementation was assigned to an agent on 2026-10-16. Integration into shared branches and releases are **not** authorized. This document records only the analysis and explicitly approved future behavior. See the [catalog](boorusama-v4.6.1-entscheidungskatalog.md) and [checklist](boorusama-v4.6.1-checkliste.md).

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

**Status: APPROVED · 2026-10-16 · Implementation pending.** **Resolution:** adapt; activate only after verification.

**Target behavior / constraints:** After targeted **live API tests**, switch the Rule34 post listing endpoint to `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1`. The fork currently uses that host only for details. Preserve profile/site identity, authentication/cookie origin boundaries, parsing, pagination, rate limits and Rule34 Cloudflare/403 recovery. If incompatible, assess the cause instead of forcing an untested host change.

**Dependencies:** N01/N02/N04/N05 and current Rule34 `boorus.yaml` settings.

**Verification:** JSON list/details, pagination/filter/limit, auth/no auth, CORS/redirects, 403 challenge, rate limit/429, content shape, cross-host credentials and cache isolation. Live verification has **not yet been performed**.

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

## P03 – Bildladefehler: Tap-to-Retry nur bei passenden Error-Widgets

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Endgültige Upstream-Variante mit explizitem `ExtendedImageController.reload()` statt früherem flächendeckendem `GestureDetector` verwenden. In Fork-Grid und Post-Viewer gut sichtbaren, fokussierbaren Retry-Button im `ErrorPlaceholder` anbieten; Tippen auf restliche Kachel muss weiterhin den Post öffnen und Selection-/Hold-Gesten respektieren. Der Fork-`ProgressivePostImage` hat eine eigene Kandidaten-/Generations-Loading-Pipeline und muss einen separaten kontrollierten Retry des fehlgeschlagenen Ziel-/Fallback-Requests ermöglichen, ohne ein bereits erfolgreich dekodiertes niedrigeres Bild zu verlieren. Kein automatisches endloses Retry oder unkontrolliertes Disk-Cache-Löschen.

**Daten / Abhängigkeiten:** Keine persistente Migration; `packages/extended_image`-API und Fork-Progressive-Loader/Shared-Cache entsprechend anpassen. X04-Cache-Invarianten erhalten.

**Abnahme / Tests:** Primary/Fallback/Progressive-Fehler, Zielbild-Neuladen mit gehaltenem Placeholder, Retry nach 403/Timeout/invalidierter Datei, Kachel-Tap vs. Retry-Button, Selection/Long-Press, Accessibility/Keyboard und keine dauernde Request-Schleife.

**Begründung / Quellen:** [`afdff42e3`](https://github.com/khoadng/Boorusama/commit/afdff42e344a585439bef34893bc2cbaa8e706df), [`58e4a0607`](https://github.com/khoadng/Boorusama/commit/58e4a06075faa8c07d8129dfdfa19156a4981a50). Der Nutzer bestätigte P03 nach Detailbesprechung am 2026-10-16.

## P04 – Post-Grid: Refresh während laufendem Fetch nicht verlieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** Fork-Race-/Refresh-Queue behalten und gezielt ergänzen.

**Zielzustand / technische Grenzen:** Bestehenden `PostGridController` mit `_refreshPending`, `_pendingMaintainPage`, `_pendingPreserveSelection` und `_queuedRefreshWaiters` unverändert als einzige Refresh-Queue erhalten. Upstreams Latest-Result-Schutz ergänzen: Wenn während des laufenden Fetchs eine neue Suche/ein Refresh/ein Profilwechsel vorgemerkt wird, die veraltete Antwort nicht zwischenzeitlich in den sichtbaren Grid-State übernehmen, sondern danach den neuesten Stand laden und erst dessen Ergebnis veröffentlichen. Fehler veralteter Passes nicht als endgültige UI-Fehler anzeigen, wenn der zuletzt angeforderte Pass erfolgreich war; aber echte letzte Fehler und wartende Future-Aufrufer korrekt behandeln. Keine zusätzliche Upstream-Refresh-Queue oder Selection-Reset einführen.

**Daten / Abhängigkeiten:** Keine Datenmigration; Bezug auf Following Topics, automatische Suchänderungen, Profilwechsel und P05-X03-Bookmark-Library-Gate.

**Abnahme / Tests:** Getaktete, konkurrierende Fetches/Refreshes, alte Antwort nicht gerendert, spätester Query/Profil-Snapshot gewinnt, Fetch-Fehler vor erfolgreichem Folgepass, maintainPage, preserveSelection, Wartende Future, Dispose, Duplicate-Fetches/Loading-State.

**Begründung / Quellen:** [`828ddbdb7`](https://github.com/khoadng/Boorusama/commit/828ddbdb75afd02fe14cf8182774a3ef67c9128f). Der Nutzer bestätigte P04 nach Detailbesprechung am 2026-10-16.

## P08 – WebView-Video aus Cache-Datei und Cleanup-Schutz

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, Video-Cache-Lifetime schützen.

**Zielzustand / technische Grenzen:** Upstreams WebView-Wiedergabe lokaler Cache-Dateien mit kleiner lokaler HTML-Seite, MIME-Erkennung aus `VideoSource`, eingeschränktem lokalen Datei-Zugriff und sicherer serieller Bereinigung alter temporärer WebView-Seiten übernehmen; den bisherigen fehleranfälligen Base64/10-MiB-Fallback vermeiden. Fork-`VideoCacheManager` bislang ohne garantierten Usage-Schutz für aktive Videodateien: während Player/WebView-Dateizugriffes Eviction, Expiration und explizites Cache-Leeren gegen diese Videodatei absichern (kurzlebige, pro Datei referenzierte Nutzung/Lease). Beim Video-/Engine-Wechsel, Error und Dispose freigeben; ggf. zur Löschung vorgemerkte Dateien anschließend bereinigen. Keine Image-Cache-Generations zurückbringen und kein dauerhaftes Leasing über den Wiedergabezeitraum hinaus. Bei beschädigter/fehlender Cache-Datei sauber auf Remote-Streaming zurückfallen, ohne Auth/Cookies an unberechtigte Datei-/Origin-Kontexte zu geben.

**Daten / Abhängigkeiten:** Cache-Lifetime ist separate Video-Cache-Verwaltung (`packages/cache_manager/lib/src/video_cache_manager.dart`), nicht X04-Image-Cache. Lokale `CachedVideoSource` muss gültigen Pfad bekommen; temporäre HTML-Dateien werden verlässlich beim Schließen/Start bereinigt; kein Persistenzschema erforderlich.

**Abnahme / Tests:** Kleine/große/unbekannt große gecachte Videos, WebView Android/iOS/macOS, parallele Player, Cache-Eviction und Clear während Playback, Expiration, Video-/Engine-/Source-Wechsel, lokale Seite und Datei-Race, Stale-Cleanup beim Start, Streaming-Fallback, File-Read-Grenzen.

**Begründung / Quellen:** [`f3d8acaa0`](https://github.com/khoadng/Boorusama/commit/f3d8acaa0a765b6d2957ddd36f68a1aa944fa328), [`0f71409de`](https://github.com/khoadng/Boorusama/commit/0f71409dea3775ae1dd033bcf7fc27bb008888a0). Der Nutzer bestätigte P08 nach Detailbesprechung am 2026-10-16.

## P09 – Kurumi InteractiveViewer: Bild-Pan vs Page-Swipe

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, Fork-Gesten erhalten.

**Zielzustand / technische Grenzen:** Bei unzoomed Bild (Zoom nahe 1x) sollen horizontale/vertikale PageView-Swipes statt `InteractiveViewer`-Panning gewinnen; bei vergrößertem Bild soll Pan/Pinch funktionieren. Upstreams Zoom-abhängiges `panEnabled` und die `ScaleGestureRecognizer.panCausesAcceptance`-Arbitration soweit notwendig integrieren. Vendored Flutter-3.47.2-Widget/Recognizer nur übernehmen, wenn eine kleinere kompatible Lösung am gepinnten Flutter nicht robust ausreicht. Sämtliche Fork-Funktionen erhalten: Double-Tap-Classic/Fit-Cycle, Snap-Zoom-to-Fit, Bildgrenzen, Auto-Comic-Strip, Original-on-Zoom sowie `ZoomEdgePageGesture` mit 160-dp-Edge-Pull, Retry-/Load-More-/Page-Actions. Panning und Page-Swiping nicht gleichzeitig aktivieren oder Pointer-Events doppelt konsumieren.

**Daten / Abhängigkeiten:** Keine Persistenz; A02-Kurumi-Migration und gepinnte Flutter-Version beachten, mögliche vendored Dateien nur gezielt und mit klarer Upgrade-Strategie.

**Abnahme / Tests:** Schneller Flick bei 1x horizontal/vertikal auf Android-Slop, Pinch-Zoom, Pan bei >1x, Edge-Pull/160-dp-Schwelle, geändertes Zoom/Media-Representation während Gesture, Mouse/Touch/Stylus, Rotation, Double-Tap, Original-on-Zoom, Selection und Zoom-Hardwaretest.

**Begründung / Quellen:** [`62e36f7e5`](https://github.com/khoadng/Boorusama/commit/62e36f7e5c7d40a3b5daa383a7c67ca420cb1cd3), [`c6b25213c`](https://github.com/khoadng/Boorusama/commit/c6b25213c3478abedf5c82c41dd9dd92a93a1bbe). Der Nutzer bestätigte P09 nach Detailbesprechung am 2026-10-16.

## P10 – Volume Keys im Post Viewer korrekt konsumieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen (mit aktiviertem Viewer-Gate).

**Zielzustand / technische Grenzen:** Bei eingeschalteter `volumeKeyViewerNavigation`, tatsächlich sichtbarem und nicht expandiertem Post-Viewer, Lauter (+) zur Navigation zum nächsten Post und Leiser (-) zum vorherigen Post verwenden und alle zugehörigen Key-Down-/Repeat-/Up-Ereignisse als verarbeitet (`true`) zurückgeben, auch am ersten oder letzten Post. Bei ausgeschalteter Funktion, verborgenem Viewer und Expand-Mode die Keys unbehandelt (`false`) lassen, damit reguläre Systemlautstärke funktioniert. Navigation selbst nicht ungewollt bei Key-Up/Repeat mehrfach auslösen; bestehende `isKeyPressed`-Down-Gestenerkennung und eventuelle Android-/Hardware-Limits bewahren. Während dieses optionalen Modus gilt Post-Navigation auch bei Videoposts.

**Daten / Abhängigkeiten:** Keine Persistenz-/Schemaänderung, vorhandene Setting/Global-Keyboard-Handler beibehalten.

**Abnahme / Tests:** Key-Down/Repeat/Up, erster/letzter Post, Viewer sichtbar/verborgen, Setting an/aus, Expand-Mode, Video/Bild, Systemlautstärke außerhalb des Viewers, kein doppeltes Navigieren.

**Begründung / Quellen:** [`de755c0d2`](https://github.com/khoadng/Boorusama/commit/de755c0d20570d4c9e2c6d4b718517514178af44). Der Nutzer bestätigte P10 nach Detailbesprechung am 2026-10-16.

## P01 – Zwei Quick Actions auf Post-Thumbnails

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen, Fork-Post-Presentation bewahren.

**Zielzustand / technische Grenzen:** Upstreams zwei pro Profil konfigurierbare Thumbnail-Quick-Actions (primary/secondary; Standard/Favorite je Booru, Bookmark, Download, Artist; optional keine) einschließlich kompakter adaptiver horizontaler/vertikaler Platzierung übernehmen. Primär-/Sekundäraktion sind verschieden; ohne primäre Aktion keine sekundäre. Standardmäßig weiter nur die bisherige primäre Aktion, Sekundäraktion deaktiviert. Bei knappen Kacheln nur Primäraktion anzeigen. Aktionen unten rechts gruppieren, Score unten links; Selection blendet beide aus und hat Vorrang. Auf Series-/Grouped-Post-Karten keine Post-spezifischen Mutationen auf einen beliebigen Einzelpost umbiegen: dafür erst einen klaren geeigneten Aktionsträger definieren.

**Zwingende Fork-Kompatibilität:** Die 2026-09-24 mit [`c00ac614f`](https://github.com/timberpile/Boorusama/commit/c00ac614f8fb5849e57f924b6bfeaaf8a22a057c) eingeführte per-Post-Boundary erhalten: `PostGridItem` ermittelt `PostGridItemAdditions.quickActionButton` anhand der konkreten `post.origin`/`BooruPostPresentation` und übergibt diese als `defaultActionButton` an `DefaultImagePreviewQuickActionButton`. Dieser Button hat **nur bei der gewählten Default-Aktion** Vorrang vor `booruBuilder.quickFavoriteButtonBuilder`, nicht bei explizit gewählten Bookmark/Download/Artist-Actions. Beispiel: `DanbooruPostGridPresentation` liefert `DanbooruQuickFavoriteButton` mit Banned-Status-Abstimmung. Auch bei zwei Actions für jeden einzelnen Post korrekt auflösen; Mixed-Booru-Feed, Bookmark/Following und Custom-Fallbacks dürfen keine global falschen Aktionen zeigen. Direkt übergebene `quickActionButton`-Overrides/Selection-Guards ebenfalls erhalten.

**Daten / Migration:** Bisheriges einzelnes String-Feld `defaultPreviewImageButtonAction` verlustfrei auf `thumbnailActions` (primär, optional sekundär) mappen; alte Import-/Export-Profile und UUIDs erhalten. Unknown/invalid Optionen über den bereits beschlossenen P02-Schutz behandeln; keine versehentliche Zurücksetzung der Nutzerwahl.

**Abnahme / Tests:** Alle Legacy-Actions und ihr Default-Fallback, sitespezifische Default-Aktion in gemischten Feeds, Banned/Unsupported-Post, primär=sekundär/none, Legacy-JSON und Roundtrip, kleine Grid-Größen und großer Text, Selection/Hold-and-Drag, Series-Karten, Score-/Info-Badge-P12-Überlagerungen, Mouse/Touch/TV/Keyboard (P14).

**Quelle:** Upstream [`26ad35202`](https://github.com/khoadng/Boorusama/commit/26ad352026bb4187e399dfab422c76427aca8655). Der Nutzer hat P01 am 2026-10-16 nach Klärung der Fork-spezifischen `defaultActionButton`-Semantik bestätigt.

## U01 – Suche oberhalb Soft-Keyboard bedienbar

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Upstream-Fixes für Suche bei eingeblendeter Soft-Keyboard übernehmen: Search-Overlay innerhalb tatsächlich verfügbarem Platz positionieren (`fitToAvailableSpace` oder gleichwertige adaptive Platzierung), `MediaQuery.viewInsets.bottom` bei Top-/Bottom-Search korrekt einbeziehen und Liste/Inputs scrollbar halten. Die noch geplante kompakte, einheitliche Fork-Suche mit termbezogenem Raw Editor, automatischer Suche und Tag-/Metatag-Vorschlägen darf nicht durch alte Upstream-UI ersetzt werden. Texteingabe, vorhandene Chips und Vorschlagsauswahl bleiben bei 320dp, Landscape, Rotation und großem Text sichtbar; nicht unnötig das Keyboard schließen.

**Daten / Abhängigkeiten:** Gemeinsamer Search-UX-Umbau, B01–B05, U03; Profile-/Search-Session und A02-UI-Komponenten erhalten.

**Abnahme / Tests:** Phone Small/Normal/Landscape; Top- und Bottom-Position; Keyboard offen, 1.5–2× Schrift, Rotation, Suggestion-Auswahl, termbezogener Raw Editor und sichtbare aktive Chips; Upstream Headless-Keyboard-Flow adaptieren.

**Begründung / Upstream-Quellen:** [`a00d41f3a`](https://github.com/khoadng/Boorusama/commit/a00d41f3a7a1e81954e718ab1144183426a1ab89). Nutzer bestätigte U01 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U02 – Search History als Full-Height-Sheet + Tests

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen.

**Zielzustand / technische Grenzen:** Search History auf Telefon als scrollkontrolliertes Bottom Sheet (`isScrollControlled: true`) mit sinnvoll nutzbarer Höhe zeigen; Liste scrollbar, Tastatur/Insets berücksichtigen und auf weitere UI-Navigation responsiv reagieren. Bestehende Filter-/History-/Pinned-Search-/Following- und Suchzustand-Wiederherstellung erhalten, keine eigene History-Datenmigration. Upstreams Flow-Tests adaptieren.

**Daten / Abhängigkeiten:** Fork SearchHistory-Route und SearchProfileSession; U01/U03 sowie neuer Search-UX-Einstieg.

**Abnahme / Tests:** Viele Historieneinträge, Suche/Filter, Auswahl übernimmt Query korrekt, Keyboard/Back/Escape, Route-Return, Sheet bei niedriger Höhe; keine doppelte Search-Action.

**Begründung / Upstream-Quellen:** [`e53cdf3b3`](https://github.com/khoadng/Boorusama/commit/e53cdf3b31560cd4607431381b316b8e29349b11), [`3726d75c7`](https://github.com/khoadng/Boorusama/commit/3726d75c7eb14ea170e06e497b09198f4a9c4c71). Nutzer bestätigte U02 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U03 – Tag-Suggestions per Tastatur fokussieren und hervorheben

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Vorschlagsliste als fokuserhaltende Kurumi-Listbox oder gleichwertigen gemeinsamen Mechanismus anbinden: Up/Down bewegt sichtbares Highlight, Enter wählt aktiven Vorschlag, Escape löscht zunächst nur den Highlight-Zustand, während der Textfokus im Suchfeld bleibt; danach greifen Search-/Layer-Back-Regeln. Das Listen-Highlight ist semantisch markiert und scrollt ins Sichtfeld. Keyboard-Navigation konsistent für Desktop, Hardware-Keyboard/TV und für Raw-Editor des einzelnen Suchbegriffs; keine doppelte Fokusmarkierung um Input/Bar, keine Tastenevents in verdeckte Screens durchlassen. Tag- und Metatag-Einträge des zukünftigen allgemeinen Search-Options-Interface unterstützen.

**Daten / Abhängigkeiten:** B01, geplanter Suchumbau, U01, U04–U06, A02-Kurumi; kein zweiter Search-Controller/Legacy-Chip-Editor.

**Abnahme / Tests:** Vorwärts/rückwärts/reversed Suggestions, Up/Down/Enter/Escape, Auswahlliste bei Filteränderung, Tab/Shift-Tab, Fokus bleibt im Feld, Raw-Query und Single-Term-Editor, mit/ohne Keyboard; Scroll-to-highlight; keine Tastaturaktion an verdeckter Seite.

**Begründung / Upstream-Quellen:** [`f7174bab4`](https://github.com/khoadng/Boorusama/commit/f7174bab405360103c48659b1c5bb72cbcd2bd61), [`e1ad37e1e`](https://github.com/khoadng/Boorusama/commit/e1ad37e1eddbb12106930e2ec983536863b5511b), [`7f5693c84`](https://github.com/khoadng/Boorusama/commit/7f5693c847ea0a88acb1fd12ff05057e0a6e5bb5). Nutzer bestätigte U03 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U04 – TV-Remote- und Tastaturnavigation auf gesamter App

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen; TV Best-Effort.

**Zielzustand / technische Grenzen:** Gemeinsame directional Focus-Navigation (D-Pad/Pfeiltasten), sichtbare Focus-Rings erst bei Keyboard-/Remote-Bedienung, Scroll-to-focused-Item und vernünftige Navigation über FocusScopes/Drawer/Sidebar/Toolbar/Viewer/Dialoge übernehmen. Upstreams `KurumiDirectionalFocusAction`, Ring-/Focus-Utilities, Key-Handling und Test-Harness nur in Fork-kompatibler Form integrieren; Touch-/Mouse-Navigation ungestört lassen und keine unabsichtliche Aktivierung versteckter Controls. TV/Remote zunächst ausdrücklich **Best-Effort**, keine neue offiziell unterstützte TV-Plattform samt Release-/Support-Versprechen.

**Daten / Abhängigkeiten:** A02, P01/P13/P14, U03/U05/U06 und bestehende Fork-Navigation/Panel-Auswahl.

**Abnahme / Tests:** D-Pad+Enter+Back über Start/Browse/Profiles/Search/Settings/Viewer/Dialogs, Focus-Scope-Wechsel, Scroll-Reveal, nicht sichtbar/offstage, Input-Editing vs. Fokus, Touch/Mouse-Wechsel, Ring nur bei Keyboard; autom. Headless-Flows.

**Begründung / Upstream-Quellen:** [`e80eb1210`](https://github.com/khoadng/Boorusama/commit/e80eb1210a2327dfae4eba4866a1e7cfe472dfd8), [`00feb4d99`](https://github.com/khoadng/Boorusama/commit/00feb4d9923b49a931b7b0a24a9ac6f262214cc0), [`1e3b00c3a`](https://github.com/khoadng/Boorusama/commit/1e3b00c3a8e9c9cc43b947bb42501c2e33b30bf0), [`41d0121ce`](https://github.com/khoadng/Boorusama/commit/41d0121cee07c3533042f86e0b256663a9f7134d), [`7895ce70e`](https://github.com/khoadng/Boorusama/commit/7895ce70e7b520ddd8cefe3ef640de3679ee4fde). Nutzer bestätigte U04 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U05 – Desktop Tab-Reihenfolge und Fokusgrenzen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Pane-bezogene Tab-/Shift+Tab-Reihenfolge und FocusTraversalGroup/FocusPane sinnvoll in bestehender Sidebar, Profile-Switcher, Settings-Suche, Suchergebnissen, Browse/Post-Viewer und Dialogen etablieren. Sichtbar-fokussierte Elemente gegenüber Offstage-/Scroll-Bereich priorisieren; bei Keyboard-only Interaktion Ring zeigen, nach Mouse/Touch ausblenden; beim Schließen von Dialog/Popover Fokus an den aufrufenden Control zurückgeben. Flache und verschachtelte Navigationsbereiche nicht als zufällige Focus-Scopes behandeln; aktuelle Fork-Settings-/Sidebar-Architektur erhalten.

**Daten / Abhängigkeiten:** U04/U06, Fork Settings-Suche und responsive Settings-Panes (A04), P14.

**Abnahme / Tests:** Tab/Shift+Tab und Directional Arrows über Pane-Grenzen, lange Settings-Listen, Explore/Viewer sichtbare Controls, Focus Return nach Dialog/Sheet, Dynamic Layout/Routing/Scroll und große Textskalierung.

**Begründung / Upstream-Quellen:** [`a555bbb3d`](https://github.com/khoadng/Boorusama/commit/a555bbb3db20d9b8c29c3c1b7d87c2b0d8546d20), [`e95a71f85`](https://github.com/khoadng/Boorusama/commit/e95a71f85d7982a797a89b0879a42e1c55d46253), [`5f57df699`](https://github.com/khoadng/Boorusama/commit/5f57df699e940fb8256aa74bdac46d2979246141), [`58254b441`](https://github.com/khoadng/Boorusama/commit/58254b441040ec4c6187018a46c4366511e3e7f0), [`84286ddc1`](https://github.com/khoadng/Boorusama/commit/84286ddc1e3da8e7cae71783c5e21641015635ae), [`d7041c4d4`](https://github.com/khoadng/Boorusama/commit/d7041c4d42b3470c45ab4ed29bbe1e3e73093aa8), [`f31f551be`](https://github.com/khoadng/Boorusama/commit/f31f551bedd31b2c75fcddf354e682b07bae5e69). Nutzer bestätigte U05 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U06 – Escape-Handling, Menu Selection und Layer-Hierarchie

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Mit einem Fork-kompatiblen `KurumiDismissible`/BackHandler oder gleichwertig eine einzige ordentliche Keyboard-Escape/Android-Back-Präzedenz für ineinanderliegende Layer aufbauen: zuerst aktives Submenü/Popup/Popover, dann Dialog/Sheet, dann Search-Editing-/Suggestion-State, anschließend aktive Selection, zuletzt Route/Screen; tatsächliche Router-/PopScope-/Modal-Grenzen (inklusive nicht dismissbarer oder Dirty-Form-State) respektieren. Nur eine Ebene pro Tastendruck schließen; Fokus bei Schließen auf Auslöser zurückgeben und Key-Events nicht an verdeckte Seiten durchreichen. Fork-Kontextmenüs, MultiSelection- und Tap-through-Schutz erhalten, mit P13-A02-Kurumi abstimmen.

**Daten / Abhängigkeiten:** U03–U05, P13, bestehende Fork-Router und `CustomContextMenuOverlay`-/`KurumiContextMenuPageController`-Erweiterungen.

**Abnahme / Tests:** Verschachteltes Submenü/Popover in Dialog/Sheet, Escape/Android Back, Selection+Search, non-dismissable Dialog, Routing mehrfacher Navigators, kein doppelt konsumiertes Escape, Focus-Return, kein Tap-through auf Post.

**Begründung / Upstream-Quellen:** [`3ff8b054e`](https://github.com/khoadng/Boorusama/commit/3ff8b054e558c77fd94a0419b33526d7e6d9c829), [`b925a581b`](https://github.com/khoadng/Boorusama/commit/b925a581bd361ca710d27a3e95c1eb315f9be62f), [`2d6d9f6e6`](https://github.com/khoadng/Boorusama/commit/2d6d9f6e6dacf60a52f8d0b62e7d27b8318b707c), [`76a8485de`](https://github.com/khoadng/Boorusama/commit/76a8485de122438d3f70c74de5c69bd1c8ea8987). Nutzer bestätigte U06 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U07 – Favorite Tags auf großen Screens im Dialog statt Sheet

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen (Fork-Labels bewahren).

**Zielzustand / technische Grenzen:** Favorite-Tag-Editor auf Phones wie bisher als Bottom Sheet mit Keyboard/Inset-Schutz und ab größerem Kurumi-Screen-Breakpoint als zentrierten Dialog mit ca. 520px Maximalbreite anzeigen. Inhalt unabhängig von Keyboardhöhe und erweiterten Optionen scrollbar machen, Add/Edit/Raw-Query und sämtliche vorhandenen Fork-Label-Optionen/Warnungen/Aktionen ohne Funktionsverlust bewahren. Konsistent mit Fork-Breakpoints und anderen Einstellungenmodals gestalten.

**Daten / Abhängigkeiten:** Fork Favorite-Tag-Management und Label-Verwaltung, U01/U04/U06.

**Abnahme / Tests:** Phone/Tablet/Desktop, Keyboard offen/zu, großer Text, wechselnde Advanced-Options und Label-Chips, fehlerhafte/duplizierte Tags, Submit/Cancel/Escape und State-Restoration.

**Begründung / Upstream-Quellen:** [`20e750618`](https://github.com/khoadng/Boorusama/commit/20e750618847bbb0a84391cca0b2440667ab18e7). Nutzer bestätigte U07 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## U08 – Regressionstests und Flakiness-Fixes nachziehen

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** test-only, zusammen mit Feature-Übernahme.

**Zielzustand / technische Grenzen:** Upstreams Testabsichten (Info-Badge-Hover nach P12 und Bulk-Dry-Run-/Session-Status nach D02) übernehmen, jedoch an aktuelle Fork-Widgets, APIs und bestehende kontrollierte Clock-/Completion-Signale anpassen statt unkontrollierte feste Sleeps oder flakey Polling-Schleifen zu duplizieren. Keine eigenständige UI-/Produktlogik und keine neue Persistenz durch U08; Tests erst zusammen mit den betreffenden Migrationsänderungen aktualisieren.

**Daten / Abhängigkeiten:** P12, D02, Fork-Regressionstests und Runner/Headless-Flows (A12).

**Abnahme / Tests:** Hover öffnet Preview nur über Info-Badge, schließen via Keyboard/Maus/Selection; Bulk Dry Run/Resume/Status ohne wall-clock-race, idempotente Session-Lifecycle-Tests und kontrollierte Futures/Events.

**Begründung / Upstream-Quellen:** [`71b41b8a0`](https://github.com/khoadng/Boorusama/commit/71b41b8a0f5574975f1cae673ac9cedde5b594ed). Nutzer bestätigte U08 ausdrücklich am 2026-10-16; es ist ein Planungsbeschluss ohne Code-Implementierung.

## D01 – Download Sidecars: TXT-Tags und JSON-Metadaten

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Optionales Download-Sidecar neben der tatsächlich gespeicherten Mediendatei (`<media>.txt` mit einem Tag pro Zeile oder `<media>.json` mit Tags, unverfälschter Herkunft/Site-ID sofern verfügbar, öffentlichen Quelllinks, tatsächlicher Qualität und tatsächlichem Dateinamen) implementieren. Globales Format `off` als Default; pro Bulk-Download-Task ein optionaler Override (Default/Off/TXT/JSON). Keine zusätzliche profilbezogene Einstellung. Einzel-, Bookmark- und Bulk-Downloads sowie Cache-Direktkopien über denselben sicheren, beobachtbaren Completion-Pfad integrieren. Sidecar-Daten als unveränderlichen Post-/Task-Snapshot vor dem Transfer einfrieren, damit Retry/Background-Recovery nicht auf UI-Provider angewiesen sind. Dateien ausschließlich nach bestätigter Transfer-Fertigstellung atomar publizieren; deduplizierte Tags sortiert ausgeben, vorhandene fremde/abweichende Sidecars nicht überschreiben, Konflikt als eigenständig reparierbaren Fehler anzeigen. Sidecar-Fehler dürfen die abgeschlossene Mediendatei nicht erneut herunterladen oder zerstören. Bei `skip if exists` eine vorhandene Mediendatei mitsamt Sidecar unverändert überspringen, auch wenn das Sidecar fehlt. Sensible Cookies/Auth-Header, signierte oder lokale API-/Datei-URLs nicht exportieren. Upstream-Storage/Callbacks/Recovery an Fork-Download-/Observer-/Lifecyclesystem anpassen. D07 bestimmt verbindlich die echte Site-Post-ID für Sidecar/JSON.

**Daten / Abhängigkeiten:** Erfordert voraussichtlich zusätzliche nullable Sidecar-Konfiguration in globalen Settings, Bulk-Task-/Download-Record-Snapshots und additive SQLite-Migration (Upstream Version 2); existierende DB-Records bleiben gültig. Sidecar-Status/Journaling muss Crash/Reboot/Retry ohne doppelte Abschluss-Events (D02) tragen. Keine Änderung am bestehenden Bookmark-/Post-Hive-Schema. Keine erneute lokale Media-Downloadaktion durch bloßen Sidecar-Retry.

**Abnahme / Tests:** Default Off, TXT/JSON, Einzel/Bookmark/Bulk/Video-Cache-Kopie, Skip-if-exists mit/ohne Sidecar, Sidecar-Kollision, readonly/scoped storage, disk full, Crash vor/nach Download/Sidecar-Write, Headless Background-Callback, Recovery nach Restart, Retry nur Sidecar, 0/mehrere Tags, UTF-8/Zeilenumbrüche, URL-/Credential-Redaction und Post-Origin-Identität.

**Begründung / Quellen:** [`86a16a20e`](https://github.com/khoadng/Boorusama/commit/86a16a20ee1327740316005b7946b8264fa70a19). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D03 – Background Downloader Plugin-Update

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** Plugin-Commit nach Verifikation übernehmen.

**Zielzustand / technische Grenzen:** Upstream wechselt beim git-basierten `khoadng/background_downloader` mit unveränderter Package-Version `9.6.1` von `e8ad9f9` auf `fd67fff9ee4ad4cdf415dc3285289cad9289cefe`. Commit-Diff/Native-/API-Kompatibilität vor Übernahme prüfen. Nur bei erfolgreicher Prüfung `pubspec_overrides.yaml` und Lockfile konsistent auf den neueren Commit aktualisieren; keinesfalls alte Fork-Callbacks, Cronet-Transport/Resumption, Android-Dateirechte oder Persistenzabläufe ersetzen. Mit D01, D02 und D04 als gemeinsamer Lifecycle-Integrationstest prüfen; bei Inkompatibilität dokumentiert beim alten Pin bleiben bis zur Lösung.

**Daten / Abhängigkeiten:** Abhängigkeit/Lockfile-Git-Pin, keine geplante eigene Datenmigration. Platform-Plugin-/Native-Build-Verhalten gesondert prüfen.

**Abnahme / Tests:** Android foreground/background, App-Neustart, Pause/Resume, Retry/Cancel, Notifications, Cronet, Cache-/Sidecar-Completion, Task-IDs, Android build und iOS/Desktop soweit unterstützt.

**Begründung / Quellen:** [`669b8019f`](https://github.com/khoadng/Boorusama/commit/669b8019f80eaf8d0f40e268bbf8a29dc0808ddf). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D04 – Download-Manager: injizierbarer Task-Client und Snapshot-Fix

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** vollständig übernehmen, Fork-Lifecycle bewahren.

**Zielzustand / technische Grenzen:** Den injizierbaren `DownloadTaskClient` für Pause/Resume/Retry/Cancel, Resumability sowie Pfad- und Dateigrößenabfragen nach Upstream-Konzept übernehmen, damit Download-Manager-Widgets und Notifier testbar sind; tatsächliches Enqueueing bleibt beim bestehenden Fork-Download-Service. Bei Task-Updates die existierende Gruppenliste vor Mutation kopieren (`[...?totalTasks[group]]`), statt alte State-Snapshots mutieren zu lassen. Doppeltes Schließen desselben Broadcast-StreamControllers abstellen: ein Provider besitzt/entsorgt den Controller; nach Upstream-Konzept optional zentraler `DownloadTaskEventIngress` veröffentlicht Ereignisse sowohl im Snapshot als auch im Stream. Fork-Retry-/Headers-/DDOS-/Notification-/Download-Activity-Integration bleibt erhalten.

**Daten / Abhängigkeiten:** Neue schmale Provider-/Task-Interface-Schicht ohne Datenbankänderung, vorhandene Task-IDs und Notification-/State-Strukturen behalten. D02 und D03 berücksichtigen.

**Abnahme / Tests:** Drei oder mehr Updates derselben Task erzeugen unveränderliche frühere Snapshots und vollständige Listener-Events, Dispose ohne double-close, Task-Ingress-Snapshot und Stream identisch, Retry/Cancel/Pause/Resume mit Fake-Client und Auth-/Bypass-Headern, parallele Updates/Grouped Tasks, FileSize-Ausfälle.

**Begründung / Quellen:** [`bd2e22c22`](https://github.com/khoadng/Boorusama/commit/bd2e22c221bcfb1a8c8c0675afbab6763a3102c9), [`90657ee4e`](https://github.com/khoadng/Boorusama/commit/90657ee4ed73f9a4bf7f2277ed1750e2f8b5d4ff). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D05 – Anime-Pictures Bulk Download und Request-Pacing

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Bulk Downloads für Anime-Pictures aktivieren, einschließlich Site-Capability und mehrseitiger Aufträge. Upstream-Konservativpacing (etwa 1 Request/Sekunde über den relevanten API-/Download-Link-Host) ausschließlich über unseren bestehenden `ApiRequestCoordinator`/sitebezogene N01-Quota abbilden, keinen zweiten `SlidingWindowRateLimitInterceptor` installieren. Den unbefristeten `_downloadUrlCache` aus `AnimePicturesClient` entfernen, da URLs/Session-Cookies veralten; den Fork-`AnimePicturesDownloadFileUrlExtractor` mit begrenztem 5-Minuten-Cache beibehalten, aber Sessionwechsel, Retry nach Auth-Fehler und Links mit begrenzter Gültigkeit verifizieren. Ein Retry soll frische signierte URLs/Cookies beziehen können. Identität/Profil-/Following-Boundaries, bestehende Bulk-Auftrags-Persistenz und Download-UI nicht regressieren.

**Daten / Abhängigkeiten:** Site-Capability/Generated Booru-Config anpassen (Generator-Output nur nach Änderungen an Source-YAML neu erzeugen); N01-Quota priorisierte Request-Pacing/Retry-After, D02/D04 Download-Lifecycle. Keine zusätzliche eigenständige Rate-Limit-Schicht.

**Abnahme / Tests:** Bulk über mehrere Seiten, rate/429/Retry-After, Link-Expire/Session-Wechsel, Parallel-Profile, Download-Cookie-Handling, vorhandene Cache-Treffer, Cancel/Pause/Resume, Seiten-Cursor und Result-Recovery.

**Begründung / Quellen:** [`c5b79488c`](https://github.com/khoadng/Boorusama/commit/c5b79488c8d90b624cb17e8452d3b17e099be88f). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D06 – Zerochan Bulk Download und URL-Auflösung

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen.

**Zielzustand / technische Grenzen:** Explizite Sperre für Zerochan-Bulk-Downloads entfernen, sobald URL-Auflösung stabil integriert und getestet ist. API-Detail liefert vorzugsweise explizite `full`/`large`/`medium`/`small`-URLs und Dateigröße/Format; wenn Full fehlt oder JSON defekt ist, gezielt die Post-HTML-Seite lesen; Asiachan-Detail-API zuverlässig durch HTML-Fallback ersetzen. Quellen/Hosts validieren und Fehler/Redirects, 404/410 und temporäre Auth-/Rate-Limits unterscheiden. Pro Post `Preview`, `Sample`, `Original` klar unterstützen; **wenn `Original` explizit angefordert ist, niemals stillschweigend Preview/Sample als Original ausgeben**, sondern nicht auflösbar melden. Dedup gleichzeitiger URL-Requests und kurzer 5-Minuten-Cache analog Upstream übernehmen. Pacing konservativ ca. 1 Request/1,2 Sek über Fork-`ApiRequestCoordinator`, ohne neue Sliding-Window-Interceptor-Schicht; Fork-FileName-/Metadata-/Observer-/Bulk-Lifecycle erhalten.

**Daten / Abhängigkeiten:** Erweiterte nullable Zerochan-DTO-Felder und PostData-/Adapter-Mapping, neuer Download-URL-Extractor und Source-Capabilities, Quality-basierte Single-Download-Action; N01/N03 und D02/D04 beachten. Cache nur bei gültigen URLs und an Site/Profile geknüpft.

**Abnahme / Tests:** Zerochan + Asiachan API/HTML-Responses, fehlende Original-URL, 404/410, falsche HTML-Seite/Metatags, explicit original vs. degraded variant, Preview/Sample, Redirect/Authentication/429, per-Post-Parallel-Fetch, Cache/Expiry, Dateiname/Extension/Size und Bulk Skip/Retries.

**Begründung / Quellen:** [`50980b8da`](https://github.com/khoadng/Boorusama/commit/50980b8da1368aa39a44051c78dee12dd4dff2ce). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D08 – Favorite Tags direkt aus Storage exportieren

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** übernehmen.

**Zielzustand / technische Grenzen:** Für Favorite-Tag-Backups statt möglicherweise uninitialisiertem UI-State `ref.read(favoriteTagsProvider)` das persistente Repository über `await ref.read(favoriteTagRepoProvider.future)` und `await repo.getAll()` verwenden. Dies gilt auch für alle anderen relevanten vollständigen Backup-/Export-Flows, die derzeit direkt einen UI-Provider-Snapshot benutzen, und für Revision-/Auto-Backups. Bestehende Import-Semantik `repo.replaceAll(tags)` samt `ref.invalidate(favoriteTagsProvider)`, Versionsgrenzen und Label-/Raw-Query-Repräsentation erhalten. Explizite 'Export simple to clipboard'-UI-Funktion bleibt separat erhalten und darf nicht mit dem Full-Backup-Format verwechselt werden.

**Daten / Abhängigkeiten:** Keine Backupschema-/Persistenzmigration allein wegen D08. X03-Profile-/Import-/Recovery-Invarianten und A12 Headless-Tests berücksichtigen.

**Abnahme / Tests:** Kaltstart Full-Backup ohne Öffnen der Favorite-Tag-Page, zuvor nicht initialisiertes UI-State, mehrere Labels/Raw-Query/Unicode, Auto-/Server-/File-/Clipboard-Backup, vollständiger Roundtrip ohne doppelte Tags, Import ersetzt Tags unverändert; Provider-Invalidation nach Import.

**Begründung / Quellen:** [`f93bdf0dd`](https://github.com/khoadng/Boorusama/commit/f93bdf0dd42c5eb0e8165d9070310a2aebfa32c1). Vom Nutzer am 2026-10-16 bestätigt; D07 ist inzwischen ebenfalls entschieden.

## D07 – Quellseitige Post-IDs in Exporten statt nur int IDs

**Status: ENTSCHIEDEN · 2026-10-16 · Umsetzung ausstehend.** **Beschlussart:** angepasst übernehmen; Upstreams neue `{id}`-Semantik im Fork übernehmen.

**Zielzustand / technische Grenzen:** Den unter X02 beschlossenen `Post.sitePostId: String?`-Getter für die **tatsächliche ursprüngliche ID auf der Quellwebsite** bereitstellen. Bei üblichen numerischen Boorus die wirkliche Post-ID als String, bei Sankaku die numerische oder alphanumerische Original-ID aus `SankakuPostData`, bei Pixiv die ursprüngliche `illustId` statt des synthetischen, seitenbezogenen `Post.id`. Unbekannte Original-ID bleibt `null`: niemals eine generierte interne ID als echte Site-ID ausgeben. Herkunft per vorhandener Post-/Codec-Fähigkeit ableiten, ohne Core→Sankaku/Pixiv-Kopplung.

**Download-Dateinamen:** Den bestehenden Dateinamen-Token `{id}` von `post.id.toString()` auf die originale `post.sitePostId` umstellen, genauso wie Upstream. **Keinen zusätzlichen `{site_post_id}`-Token einführen.** Die bisherige Dateinamens-Rückwärtskompatibilität ist laut Nutzer nicht erforderlich, weil die Downloadfunktion im Fork kaum genutzt wurde. **Pixivs eigene Standardvorlage `{illust_id}_p{page}.{extension}` bleibt unverändert**, damit mehrere Seiten desselben Artworks eindeutige Namen erhalten. Benutzerdefinierte Pixiv-Vorlagen nur mit `{id}` können kollidieren; vorhandene Skip-/Dateikonfliktregeln müssen Überschreibungen verhindern. Ist die Site-ID unbekannt und die Vorlage braucht `{id}`, einen sicheren explizit nicht als Site-ID dargestellten Fallback-Namen verwenden oder eine verständliche Fehlermeldung liefern; niemals synthetische `Post.id` als echte ID einsetzen.

**Exports / Datenmigration:** D01-JSON-Sidecars, externe Post-Links und andere externe Metadaten, die die ursprüngliche Post-ID ausgeben, verwenden `post.sitePostId`. Das Bookmark-Backup v5 enthält die echte Sankaku-ID bereits im vollständigen `snapshot.custom.sankakuId`; Importer v4/v5, `StoredPostSnapshot`, `PostOrigin`, `BookmarkIdentity`, Profil-UUIDs, Bookmark-Gruppen und Following-Identitäten bleiben unverändert. Kein zusätzliches `Bookmark.sitePostId`, kein neuer Hive-Feldindex, kein Backup-Versionssprung; insbesondere Fork-Hive-Index 15=`snapshotSchemaVersion`, 16=`postSnapshot` erhalten (Upstream-Kollision auf Index 15 vermeiden).

**Abnahme / Tests:** `Post.sitePostId` für numerische/Alphanumerik/fehlende Site-IDs und Pixiv; `{id}`-Dateinamen bei Danbooru, Gelbooru, Sankaku, Pixiv inklusive korrekt unveränderter Pixiv-Standardnamen mehrseitiger Artworks; benutzerdefinierte Pixiv-`{id}`-Vorlagen und sichere Datei-Kollisionen; keine ungültigen generischen Namen, wenn ID fehlt; Links und D01-JSON-Sidecars liefern echte statt synthetische ID; bestehende Hive-Felder 15/16, Backup-/Restore-Versionen 4/5 und `BookmarkIdentity` durch Roundtrip ohne Datenverlust; gleiche numerische IDs verschiedener Booru-Installationen bleiben getrennt.

**Begründung / Quellen:** Upstream [`216eb6e6d`](https://github.com/khoadng/Boorusama/commit/216eb6e6d43cef2581a110b66a8f1482d110e7b9). Nutzer bestätigte nach expliziter Klärung der Auswirkungen auf Pixiv und des mangelnden Rückwärtskompatibilitätsbedarfs am 2026-10-16, `{id}` direkt auf die echte Site-ID umzustellen. Das ist eine Planungsentscheidung und **keine Freigabe zur Code-Implementierung**.

## Weitere Entscheidungen

**68/68 Themen ENTSCHIEDEN, 0 OFFEN.** Alle 68 Entscheidungen sind beschlossen. Die Entscheidungen sind **Planungsbeschlüsse, noch keine implementierte Software**. Der Nutzer hat am 2026-10-16 die lokale Umsetzung des vollständigen Plans durch einen Agenten beauftragt (siehe [IMPLEMENTATION_HANDOFF.md](IMPLEMENTATION_HANDOFF.md)); Remote-Push, Integration in `develop`, PR und Veröffentlichung benötigen separate Freigabe. U08 ist als Testpflege gemeinsam mit den betroffenen Features beschlossen.
