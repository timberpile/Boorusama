# Boorusama v4.6.1 — Compact Decision Checklist

Pinned comparison: fork `develop d4e1558` versus upstream `v4.6.1 5b04bf6`. **68/68 approved; no open decisions** (2026-10-16). Approvals describe intended behavior, not implemented code. See the [authoritative decision log](decisions.md), [detailed catalog](boorusama-v4.6.1-entscheidungskatalog.md), and [implementation handoff](IMPLEMENTATION_HANDOFF.md) for complete constraints, source commits, conflicts and tests.

**Risk:** Critical = potential data loss or architectural collision; High = substantial functional merge conflict; Medium/Low = targeted fix. Implementation requires verification.

| ID | Topic | Risk | Binding decision summary |
| --- | --- | --- | --- |
| **Cross-cutting data and fork safeguards** | | | |
| `X01` | Bookmark Hive index 15 collision | Critical | **APPROVED.** Retain fork Hive fields 15=snapshotSchemaVersion, 16=postSnapshot; derive genuine site IDs rather than adopting upstream's incompatible index-15 string field. |
| `X02` | Post identity and sitePostId | Critical | **APPROVED.** Provide a nullable genuine Post.sitePostId, including alphanumeric Sankaku and original Pixiv IDs; never confuse synthetic app IDs with site IDs, and preserve fork origin/snapshot/identity. |
| `X03` | Preserve fork backups, UUIDs and Following | Critical | **APPROVED.** Keep fork profiles/UUIDs, backup/import, BookmarkIdentity, post snapshots, nested bookmark/pinned-search folders, Following, refresh and recovery gates; adopt only compatible upstream test seams. |
| `X04` | Shared image cache and download lifecycle | Critical | **APPROVED.** Remove image-cache generations but retain URL-MD5, origin isolation, LRU, quotas, journal/checkpoints and safe parallel writes; copy images to OS temporary space for sharing. |
| **Architecture, platform and Settings** | | | |
| `A01` | Application bootstrap and dependency injection | Critical | **APPROVED.** Use upstream's single bootstrap/runtime and integrate all fork services, recovery gates, profile UUIDs, Following, cache, sharing and native integration without a second startup path. |
| `A02` | Kurumi and Material/Cupertino migration | High | **APPROVED.** Adopt upstream UI components while retaining fork actions, long-press/selection gestures and menus; the agent writes a prioritized manual UI checklist for the user, not performs manual acceptance. |
| `A03` | Kurumi stability and overflow fixes | Medium | **APPROVED.** Adopt upstream focus, Escape, animation, menu, layout/overflow fixes without regressing fork interactions. |
| `A04` | Responsive Settings navigation | High | **APPROVED.** Integrate responsive Settings navigation/state/sidebar while preserving fork Settings Search, categories and dynamic app-toolbar title sizing. |
| `A05` | Reverted upstream Settings Search | Low | **APPROVED.** Do not restore upstream's reverted Settings Search; keep the existing fork feature. |
| `A06` | App-lock defaults | High | **APPROVED.** Use upstream defaults (Hide App Preview=false, timeout=30s), but preserve previously saved user choices. |
| `A07` | Persistent logging and redaction | High | **APPROVED.** Integrate upstream logs, viewer/copy/export and redaction without losing fork diagnostics or changing privacy defaults unexpectedly. |
| `A08` | Cloudflare/DDoS diagnostic events | Medium | **APPROVED.** Integrate typed solver, challenge and error diagnostics into A07 logging while preserving Rule34 recovery. |
| `A09` | Android cache paths and DocumentsProvider | Medium | **APPROVED.** Adopt cache-path settings and read-only DocumentsProvider for valid completed media only, adjusted to fork cache filenames, package ID and native channels. |
| `A10` | Windows embedded WebView | High | **APPROVED.** Adopt WebView/browser factory and unsupported-platform fallbacks compatible with fork challenge/browser behavior. |
| `A11` | Language and localization updates | Low-medium | **APPROVED.** Import Arabic, Indonesian and other upstream localization fixes without losing fork translation keys or fallbacks; UI localization remains multilingual. |
| `A12` | Headless application tests | Medium-high | **APPROVED.** Integrate upstream fake-service/headless app-flow test harness into the unified fork runtime; preserve all fork tests and the user's manual A02 verification boundary. |
| `A13` | NixOS development support | Low | **APPROVED.** Adopt useful NixOS flake/dev-shell changes only when maintainable; no new platform-support commitment. |
| `A14` | Release CI and native builds | High | **APPROVED.** Adopt useful upstream SDK, native asset, build and CI fixes without changing fork flavors, split APKs, signing, pinned Flutter or protected workflows. |
| `A15` | Preserve fork signing identity | Critical | **APPROVED.** Do not adopt upstream signing key; retain com.timberpile.boorusama, production certificate, flavors and upgrade compatibility. |
| `A16` | Fork release versioning and What's New | Medium | **APPROVED.** Base version exactly matches merged upstream; reset timberpile.N to .1 per new upstream version, then increment. Keep +buildNumber monotonic. First v4.6.1 candidate is 4.6.1-timberpile.1+190 if no later build exists. Retain fork changelog and fix repeated What's New. |
| `A17` | Formatting and ineffective reverts | Low | **APPROVED.** Integrate necessary fixes only, avoid unrelated formatting and resurrecting reverted features. |
| `A18` | Web AVIF decoder fixes | Medium | **APPROVED.** Adopt AVIF Web/network compatibility changes while retaining fork cache and media pipeline. |
| **Network and Cloudflare** | | | |
| `N01` | Retry-After and coordinated rate limits | High | **APPROVED.** Keep ApiRequestCoordinator as the sole per-origin admission/priority/429 authority; integrate upstream retries/timeouts/cancellation without a second sliding-window limiter. |
| `N02` | Per-profile media-host overrides | High | **APPROVED.** Adopt image/video/download host overrides with strict cookie, Authorization, cache and source-origin safeguards. |
| `N03` | Do not replay mutating challenge requests | High | **APPROVED.** Never blindly replay POST/PUT/votes/favorites/comments after Cloudflare unless idempotent; preserve Rule34 safeguards. |
| `N04` | Cloudflare challenge handling | High | **APPROVED.** Integrate block-page/captcha recognition, redirects, loop prevention and UI while preserving fork Rule34 403 recovery. |
| `N05` | WebView clearance-cookie bridge | High | **APPROVED.** Adopt Android/iOS/macOS WebView-to-HTTP cookie handling with correct origin, Secure, HttpOnly and native bounds. |
| `N06` | HTTP/2 and gzip | Medium | **APPROVED.** Adopt HTTP/2 flow-control and gzip improvements without regressing fallback transports, priorities or mobile memory use. |
| **Downloads and backups** | | | |
| `D01` | TXT/JSON download sidecars | High | **APPROVED.** Off by default; optional tag-TXT/JSON sidecars with bulk override and safe immutable metadata. Atomic post-completion write, durable independent retry, no secret URLs or sidecar creation for skipped existing media. |
| `D02` | Bulk completion and notification safety | Critical | **APPROVED.** Use final upstream completion logic with serial session checks, tolerant size errors, final stats before cleanup and bounded completion history; preserve fork lifecycle and idempotent recovery. |
| `D03` | Background downloader dependency update | Low-medium | **APPROVED.** After API/native/Cronet checks, update background_downloader Git ref e8ad9f9 to fd67fff9ee4ad4cdf415dc3285289cad9289cefe, remaining at package version 9.6.1. |
| `D04` | Download manager task client and snapshots | Medium | **APPROVED.** Introduce injectable pause/resume/retry/cancel/file access; copy task group lists before updating state and prevent double-closing the stream controller. |
| `D05` | Anime-Pictures bulk downloads | Medium | **APPROVED.** Enable bulk with about 1 req/sec via ApiRequestCoordinator; remove indefinitely cached client links, preserve bounded fork extractor cache and validate expired auth/URLs. |
| `D06` | Zerochan/Asiachan bulk downloads | Medium | **APPROVED.** Enable robust detail-API and HTML fallback, quality selection, request coalescing and ~1.2s pacing via N01. Never silently downgrade explicitly requested Original quality. |
| `D07` | True site IDs in exports and filenames | High | **APPROVED.** Use Post.sitePostId in JSON sidecars and links; change {id} filename token to genuine site ID including Sankaku strings. Retain Pixiv {illust_id}_p{page}.{extension} default; no new token, Hive field or bookmark identity. |
| `D08` | Persistent favorite-tag backup export | Medium | **APPROVED.** Read all favorite tags from repository storage, not an uninitialized UI provider; preserve labels, repo.replaceAll imports and simple clipboard export. |
| **Booru compatibility** | | | |
| `B01` | Sankaku metatags and typed suggestions | Medium-high | **APPROVED.** Adopt Sankaku-native search filters, parsing and typed suggestions within the fork's unified search-options UX, not a duplicate legacy search bar. |
| `B02` | Sankaku date and exclusion handling | Medium | **APPROVED.** Normalize only supported single-date input to API day ranges; preserve explicit ranges/operators and source query, with clear exclusion-limit errors. |
| `B03` | Complete Sankaku tag categories | Medium | **APPROVED.** Handle site-specific Studio 2, Genre 5, Medium 8 and Meta 9 categories plus unknown values; deduplicate by genuine tag identity. |
| `B04` | Sankaku authorization and recovery | High | **APPROVED.** Preserve headers, validate token responses and coalesce safe GET reauthentication; do not automatically replay mutating favorite requests. |
| `B05` | Sankaku search-limit messages | Low | **APPROVED.** Surface comprehensible localized anonymous/account tag-limit errors with fallback for unknown cases. |
| `B06` | Shimmie2 media/favorite behavior | Medium | **APPROVED.** Normalize media formats and load authenticated favorite status only where supported, without blocking post listing or overwriting newer user choices. |
| `B07` | Gelbooru v2 / Rule34 comment voting | Medium-high | **APPROVED.** Integrate Rule34 comment upvotes only, cursor pagination and score/parser fixes under explicit site capabilities and safe mutation handling. |
| `B08` | Gelbooru v2 comment ordering | Medium | **APPROVED.** Expose Newest/Oldest only on supported sites, preserve cookies, reset pagination/cursor and avoid new persisted options. |
| `B09` | Nozomi tag counts and byte ranges | Low-medium | **APPROVED.** Read index size with Accept-Encoding identity, validate Content-Range and 200/206/404/416 responses; throttle counts using ApiRequestCoordinator. |
| `B10` | Rule34 JSON listing endpoint | High | **APPROVED.** Switch to api.rule34.xxx only after live verification; protect pagination, parsing, cookies, Cloudflare and profile/source identity. |
| **Post grid and viewer** | | | |
| `P01` | Two quick actions per thumbnail | High | **APPROVED.** Migrate the existing primary action and default secondary to none. Preserve per-post origin defaultActionButton, mixed feeds, Danbooru banned-state behavior, selection and Series cards. |
| `P02` | Tolerate unknown profile option values | High | **APPROVED.** Do not discard profiles for unknown thumbnail-action or media-host options; preserve UUIDs/data, allow safe fallback and clear import warnings. |
| `P03` | Image-error Retry controls | Medium | **APPROVED.** Use targeted accessible Retry in error widgets, including ProgressivePostImage staged loads, without replacing valid low-res fallbacks or hijacking tile/selection gestures. |
| `P04` | Refresh queue and stale grid results | Medium | **APPROVED.** Keep the fork's pending refresh waiters/page/selection semantics and add guard against publishing superseded fetch results or stale errors. |
| `P05` | Bookmark refresh after mutation | Medium | **APPROVED.** Keep BookmarkViewRefreshGate as the only authoritative listener; do not duplicate upstream's refresh trigger. |
| `P06` | GIF autoplay and quality limit | Low-medium | **APPROVED.** Animate grid GIFs only with autoplay and known original file size >0 and <=5 MiB, otherwise static even at Highest. Retain Danbooru Automatic-versus-manual quality semantics; viewer/download exempt. |
| `P07` | Video poster until first frame | Medium | **APPROVED.** Show thumbnail until actual first rendered frame, protecting source/engine changes from stale signals and providing fallback errors. |
| `P08` | Local cached-video WebView | High | **APPROVED.** Use a local HTML/video file and cleanup, protect video cache files with active-use leases against expiry, LRU or clear; stream on cache miss. |
| `P09` | Zoom pan versus page swipe | High | **APPROVED.** At 1x favor PageView swipes, when zoomed favor pan/pinch. Preserve fork 160dp edge-pull, double tap, original-on-zoom and other zoom features. |
| `P10` | Volume-key viewer navigation | Low-medium | **APPROVED.** Consume volume up/down only when configured and eligible visible non-expanded viewer; handle key lifecycle without repeated navigation or suppressing system volume elsewhere. |
| `P11` | Video time controls and media keys | Low-medium | **APPROVED.** Fix time-display width and handle media play/pause only on active visible video, not image/hidden viewer or text input. |
| `P12` | Hover preview via info badge | High | **APPROVED.** Open hover previews only through a dedicated info badge; preserve long press, right click, selection/drag, click-through safeguards and keyboard access. |
| `P13` | Kurumi post/tag context menus | High | **APPROVED.** Migrate menus while retaining fork favorite, bookmark group, Following, selection, nested menu and dismissal actions with no tap-through. |
| `P14` | Accessible quick action buttons | Medium | **APPROVED.** Ensure visible quick favorite/bookmark buttons support focus and Enter/Space; preserve selection precedence and tile controls. |
| **Search, interaction and desktop** | | | |
| `U01` | Search above the software keyboard | High | **APPROVED.** Keep compact tags, single-term Raw Editor and suggestions usable with keyboard open, narrow screens, changing insets and automatic search. |
| `U02` | Scrollable tall search history sheet | Medium | **APPROVED.** Use scroll-controlled history sheet, preserving search state, keyboard, profile switching and correct query selection. |
| `U03` | Keyboard-operated suggestion list | High | **APPROVED.** Up/Down highlights, Enter selects, Escape clears highlight first; keep focus in the input, use listbox semantics and preserve per-term Raw Editor. |
| `U04` | Keyboard and D-pad navigation | Medium-high | **APPROVED.** Add cross-scope focus movement, keyboard-only focus rings and scroll reveal; touch/mouse unchanged. TV is best-effort only. |
| `U05` | Desktop Tab order and focus panes | Medium | **APPROVED.** Group sidebar, Settings and viewer controls into predictable Tab/Shift-Tab regions, excluding hidden controls and returning focus after dismissal. |
| `U06` | Unified Escape/Back dismissal | Medium-high | **APPROVED.** Close exactly the innermost menu, popover, dialog, search or selection state before routing; preserve modal guards and focus restoration. |
| `U07` | Favorite tags editor on wide screens | Low-medium | **APPROVED.** Use keyboard-safe bottom sheet on phones and scrollable roughly 520px dialog on large screens; preserve chips, validation and advanced settings. |
| `U08` | Deterministic regression tests | Low | **APPROVED.** Update info-badge-hover and bulk-download lifecycle tests with controlled completion rather than fixed sleeps; ship with affected features. |

**Decision key:** adopt completely · adapt to fork · retain fork behavior · do not adopt. The [decision log](decisions.md) overrides any abbreviated summary.

**Implementation boundary:** User authorized local work by an agent on 2026-10-16; changes to `develop`, remote pushes, PRs or releases require separate authorization. The agent prepares an A02 manual acceptance checklist, which the user—not the agent—executes.
