# Plan 01: saved-source resolution, media loading and covers

Read the [lead handoff](../../handoffs/final-rollout-remediation-2026-11-08.md). Owning scope: #143/#156 and the existing engine consumers. Source evidence below was inspected at `4b9e8f6f9fbdd5020e1de87942f4b8a5f683ba5d`; verify local deltas before applying it. No device reproduction is claimed by this plan.

## A. Gelbooru Bookmarks do not attach to a newly added profile

**Observed report:** Gelbooru Bookmarks remain unavailable after adding a matching profile and restarting. **Confirmed mechanism:** `PostOriginResolver.resolve(..., allowProfileHintFallback: false)` restricts candidates to a non-null saved `profileIdHint`. A different new profile UUID cannot match even if the engine/site does. The Bookmark availability projection explicitly uses that mode. This is a sufficient failure path, not proof that the user's exact records carry such a hint.

Inspect together:

- `lib/core/posts/post/src/data/post_origin_resolver.dart` and origin normalization/types.
- `lib/core/bookmarks/src/providers/bookmark_profile_availability.dart`.
- `lib/core/content/content_access_provider.dart` and `viewer_source_access_provider.dart`.
- `pool_bookmark_provider.dart`, saved Group viewer-entry construction and imported snapshot/profile remapping.

### Implementation

1. Reproduce with a saved/imported record carrying a stale UUID, first no profile, then exactly one compatible Gelbooru profile. Inspect redacted engine IDs, canonical site identity, hint-presence and resolution outcome. Separately test no hint, wrong engine hint and a verified site alias. Do not assume all `gelbooru*` engines or arbitrary subdomains are interchangeable.
2. Separate resolving a *new reading context* for a durable Bookmark from validating an already captured operation. For a new read, prefer the still-valid original hinted profile; when absent, permit one exact compatible current profile. If several profiles are compatible, require the existing explicit disambiguation flow rather than picking one arbitrarily. A hint is not a permanent foreign key that forces a user to recreate the old UUID.
3. Use that decision consistently in unavailable counts, local grid, covers, opening, metadata and source binding. Do not make availability say 'viewable' while the image/open path still uses the obsolete hint restriction. Avoid a second independent resolution algorithm.
4. Capture the selected actor when opening an operation/viewer. A later credential/account/source change must not redirect an existing Favorite mutation, download, picker write or open sheet to another actor. Do not globally enable hint fallback on every resolver call.
5. React to profile additions/removal without reimporting or rewriting Bookmark IDs/memberships. Restart must retain the same saved record. Preserve meaningful missing/ambiguous/unsupported/error distinctions.

**Regression gate:** real repository/provider flow for stale hint and no hint; add, delete and recreate compatible profile; two same-site accounts; wrong engine/site/path; live availability change; restart; outstanding operation revoked rather than rebound. Verify Gelbooru on ordinary-main Android using an existing test profile, without logging its credentials.

## B. Pixiv images fail across timelines

**Observed report:** the combined build shows Retry for all Pixiv images while an older installation works. **High-value hypothesis:** the new generic cross-source Referer filtering can remove Pixiv's legitimate engine-defined image Referer when the configured site differs from `www.pixiv.net`, or when a media override is used. Exact failing device URL/config/status still requires evidence.

Relevant source:

- `lib/boorus/pixiv/pixiv_repository.dart`: `extraHttpHeaders` supplies `kPixivImageReferer` for image loading and downloads.
- `packages/booru_clients/lib/src/pixiv/pixiv_constants.dart`: image Referer is distinct from app-api Referer.
- `lib/core/configs/network/src/types/media_request.dart`: cross-source filtering keeps a Referer only if it matches the configured source root; explicit overrides filter it too.
- `lib/core/http/client/src/data/source_media_http_adapter.dart`: the final adapter independently applies a similar rule.
- `lib/core/images/booru_image.dart`, `content_media_dio.dart`, ordinary media-override Dio and actual Pixiv image/download/preload consumers.

### Reproduce and repair the production boundary

1. Compare the ordinary running combined build against the known-good baseline using equivalent profile/network/quality settings. Distinguish API-list success from image GET failure, blocked transport, 403, invalid URL, cancellation and decoder failure. Do not blame Work foundations that are not yet connected without tracing the call path.
2. Record a bounded redacted diagnostic at the final request boundary: engine/source host, destination host, request purpose, bound/unbound/override path, cache hit/miss, status or failure category, cancellation cause and whether required non-secret headers survived. Never print tokens, cookies, full signed URLs, personal tags, account payloads or image bytes.
3. Add a production-path failing test before changing header behavior. Cover supported Pixiv site aliases, actual API versus image host roles, thumbnail/sample/original, and both bound and ordinary timeline paths. Existing Work fixtures default to `www.pixiv.net`; that alone is insufficient alias coverage.
4. Preserve the verified engine-defined image Referer for the exact intended Pixiv media destinations through request resolution and final redirect handling. Reuse the existing engine/media policy seam or make the smallest explicit extension. Do not loosen all cross-host headers or forward API bearer tokens/cookies to CDNs. For custom media-host overrides, preserve the configured request semantics only where explicitly intended; test that case independently.
5. Apply consistent behavior to thumbnails, progressive quality upgrades, viewer preloads, downloads and sharing. Do not patch only the Retry widget or hardcode a new proxy. Cached URLs remain the normal stable URLs/custom keys.

**Regression gate:** actual BooruImage/request adapter sees the required non-secret image header, no unrelated credentials; redirected foreign host remains safe; actual image decode succeeds; API auth/rotation still works; rejected transport and genuine decode failure are distinguishable in Debug Logs. Repeat authenticated Android reads after restart and in Search, Explore, Favorites and Bookmarks.

## C. Source favicon must not depend on a saved profile

**Confirmed mechanism:** `lib/core/widgets/website_logo.dart` immediately renders a globe when `contentAccessRequiredProvider` is true and the access key has no profile ID. This prevents even valid anonymous Realbooru from attempting the actual source favicon, including an existing cache hit.

1. Trace `ConfigAwareWebsiteLogo` and the source identity used by Bookmark cards. Resolve the known source's favicon independently of whether the user retained a profile or account. Do not substitute the currently selected unrelated profile icon.
2. Reuse the ordinary favicon cache and existing known-source asset/URL resolver. A cached favicon should work offline. For a network miss use a bounded anonymous request to the validated known source, without inheriting credentials. Unknown imported arbitrary URLs remain untrusted; do not probe arbitrary hosts merely because a file mentions them.
3. Keep fallback only for an actual missing/unavailable icon, not as the normal anonymous-mode appearance. Respect disabled automatic media loading, and avoid a new favicon request for every rebuild.

**Tests:** Realbooru before/after profile deletion, startup without that profile, recreation, offline cached favicon, failed icon request and unknown host. Verify the top-left badge represents the actual source.

## D. Do not render fake empty mosaic members

**Confirmed mechanism:** `_BookmarkGroupCoverState` fills all four positions and uses a bookmark glyph for unused slots. A two-member local group therefore appears to have two failed/empty members.

In `lib/core/bookmarks/src/widgets/bookmark_local_group_card.dart`, distinguish an unused slot from a failed real candidate. Unused slots are transparent/empty, without bookmark icon, spinner, Retry or accessibility item. Retain the established stable 2x2 geometry rather than stretching/reflowing the successful images. A fully empty group may retain one appropriate group-level empty treatment; do not fabricate four content items.

A genuine unavailable member may still show bounded failure feedback and participate in fallback selection. Preserve mixed Post/Pool allocation, static GIF/video-poster rules, title hit targets and fixed non-scrollable geometry.

**Tests:** 0/1/2/3/4 usable records, mixed Post/Group covers, one true failure versus one absent slot, overscroll, and a change in group membership. Two saved Posts must not produce two decorative bookmark placeholders.

## E. Danbooru Series covers and offline variants

**Confirmed boundaries, not proof of the user's cache contents:** `BookmarkPoolCoverImage` requires `coverUrl`, a current access profile, and equality between saved `coverPolicy` and the current policy fingerprint before building `BooruImage`. The fingerprint includes blacklist and visibility settings. A difference can suppress the image before disk lookup. `PoolBookmarkCover` stores URLs/variants, not bytes; initial Summary-only drafts may have no cover. Legacy cover hydration can also request the server.

Inspect `bookmark_pool_card.dart`, `pool_bookmark_provider.dart`, `pool_bookmark_cover.dart`, stored Group codecs/projections, and the existing thumbnail resolver. Separate these cases in diagnostics: no descriptor, no current context, policy mismatch, exact rendition missing, transport failure and decoding failure.

1. Reuse existing saved cover metadata and normal URL-cache bytes without a successful Pool API request. Optional metadata enrichment must not block a usable local descriptor. Preserve the descriptor across a transient refresh failure.
2. Distinguish current user filtering from temporary absence of server preference information. Evaluate available saved cover evidence against current local rules where possible; do not treat a transient fingerprint mismatch as a need to fetch the entire Pool. Do not bypass an explicitly changed local blacklist. Reuse existing snapshot facts, or persist the minimal selected-cover visibility evidence needed by the existing descriptor path; do not copy every Pool member or create another policy/cache identity system.
3. Metadata storage is not a promise that every rendition was downloaded. If neither the requested nor a compatible known rendition is cached, show an honest offline/unavailable cover state. No cache scan, reverse-hash migration or cache deletion.
4. Implement previous combined-review C1: for a real cover candidate, try a bounded set of already cached compatible renditions, including a cached sample when the selected thumbnail is absent. Do not download an original just to fill a small mosaic. Ensure custom terminal `errorWidget` does not short-circuit the fallback chain.
5. Implement C2: the cache probe and renderer must use the same resolved media request/custom key after host overrides. Invalidate eligibility when those settings change. Preserve bounded cover candidates/backoff and explicit retry.

**Tests:** saved Series with cached thumbnail and no network; sample-only cache; rewritten-host cache; temporary remote blacklist outage; actual local visibility change; old descriptor and coverless draft; correct retry/recovery; no per-member crawl. Use controlled source fixtures while Danbooru is down, and record real-site acceptance separately when service is usable.

All changes in this plan require the relevant content/media/bookmark tests, package consumers if affected, and inclusion in the final combined regression. None authorize a new cache namespace or removal of captured-action protection.
