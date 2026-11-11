# Follow-up: collection UX, ID tracking, request budgets and media continuity

Baseline: `develop@22348b2fb20049088705ce38f5b261e191b148af`, rechecked on 2026-11-11. Design/research only; no application implementation. Continue `maintenance/2026-11-11-ticket-triage`; no PR or develop integration is authorized.

This refines the [earlier investigation](../handoffs/2026-11-11-ticket-triage.md). The user wants ID-based Realbooru NEW detection, effective use of a supplied 10 requests/second Gelbooru allowance, UI alternatives for collection sharing and bulk lookup, and immediate reuse of an already visible thumbnail in the Viewer. Other previously proposed corrections were accepted in principle. Viewer icon styling remains a joint design discussion. Specific new UI and tuning choices below are recommendations, not claimed approvals.

The accompanying `collection-lookup-concepts.html` is delivered in the chat as one offline HTML file with inline CSS/JavaScript. Its posts, requests, sharing and persistence are synthetic. It illustrates three presentation alternatives per feature, not production Flutter or a pixel-perfect rendering of Kurumi.

## 1. Sharing a viewable collection

### Recommended entry: extend Share

Keep the existing **Share** action. For multiple selected Posts, add **Collection file** beside applicable existing payloads. Selecting it exposes an optional title, exact scope/count and **Share file** in the same compact Kurumi flow. A Bookmark Group context-menu action enters that same flow. No permanent Collections destination or second collection database.

| Variant | Interaction | Tradeoff |
| --- | --- | --- |
| A — existing Share surface, recommended | Select → Share → Collection file → native share. Optional title and exact count. | Least navigation; uses current timeline order. |
| B — dedicated composer | Editable ordered list with remove/reorder before sharing. | Useful for deliberate curation, but duplicates controls. File order must not modify saved group order. |
| C — Export entry/read-only export preview | Reach sharing through Export, or temporarily view a `.bsexport`. | Reuses export discovery but conflates viewing and importing and broadens the viewer's backup/credential parsing surface. Not recommended as the everyday path. |

A hosted album adds a service and upload/privacy lifecycle. Sending image files works outside Boorusama but loses typed source context. Folder sync is the appropriate separate direction for ongoing updates, not a replacement for one fixed selection. Do not present all these alternatives as extra controls on every share sheet.

### Scope and receiving

Selection means exactly the selected Posts in current timeline order, not checkbox-click order. Never crawl unseen online pages. A whole-group entry explicitly distinguishes direct/subtree scope when relevant and displays the count; active filters must not silently change what is shared.

Start with Post entries. A selected Pool/Work/Gallery reference is not permission to expand its members. Explain unsupported selected Group entries and require an explicit scope correction, rather than dropping or expanding them silently. A later mixed format can preserve typed Group references.

Open a received file directly into a temporary ordinary timeline, with normal Header, grid controls, selection and Viewer. Default to **File order**; temporary sorting does not rewrite it. Opening/closing/reading performs no library writes, favorite mutations, NEW changes or sync subscription. **Save to Bookmark Group** explicitly opens the existing picker.

Resolve access once per source/account binding using a compatible profile or approved public reader. Ask once per ambiguous source. No automatic profile creation or account borrowing after source loss. Keep unavailable reference identities/positions, with the existing compact unavailable-count explanation. Asynchronous resolution fills positions without reordering them.

### Reviewed payload recommendation: references plus existing snapshot vocabulary

The initial reference-only proposal has a real persistence tradeoff: `PostBookmark` requires a `StoredPostSnapshot` and decoded Post; profile-independent import does not make it a raw-reference-only store [S7]. Do not invent empty Posts or silently introduce a new Bookmark kind to hide this mismatch.

Prefer a strict `.bslink` v2 collection envelope with title and ordered portable references, accompanied by **bounded, share-safe snapshots of already loaded Posts where available**. References remain authoritative; snapshots are untrusted presentation/save hints, not access grants. This supports immediate metadata display, avoids unnecessary detail lookups and lets the existing snapshot-backed Bookmark path save currently inaccessible but valid entries. No media bytes are embedded; this remains not an offline image archive.

Reuse the existing Post/engine snapshot schemas and decoders, with a narrow collection-sharing projection. Do not wrap the entire library export or serialize arbitrary runtime objects. In particular, `StoredBookmarkCodec.encodeForTransfer` still retains canonical profile hints, and `StoredPostCodec` serializes media URLs: those methods alone are **not** a public-sharing sanitizer [S7]. The projection must remove all local/account/profile hints, search context, memberships, local IDs, private actor state and credentials; validate source identity and remove nonportable signed/credential-bearing URLs without guessing equivalent unsigned URLs. Preserve engine-owned semantic keys, especially genuine Pixiv Work/Page identity. Unknown custom fields cannot be exported unchecked. Decode and validate the projected snapshot before sending it.

Do not fetch more metadata just to create the file. Permit reference-only entries when safe snapshot data is unavailable, and lazily resolve them with existing authorized readers/batch APIs. Distinguish these cases on Save:

- A valid portable snapshot can be saved through normal source-independent Bookmark storage even if live media is currently inaccessible.
- A bare unresolved reference cannot be saved through today's PostBookmark constructor. Keep it in the document and offer Retry or explicitly **Save available posts (N of M)**; never silently drop it or claim complete saving. No reference-only storage migration is included in this feature.

This replaces the earlier unconditional promise to persist every unresolved bare reference. Full reference-only durable storage would be a separate shared-model decision, not a new hidden collection database.

Keep v1 single-resource `.bslink` reading/writing and its 16 KiB cap unchanged. Proposed initial v2 limits remain 2 MiB and 5,000 references, with field/snapshot limits; the byte cap can be reached sooner when metadata is included. On overflow, ask to reduce scope or explicitly share a references-only file, rather than silently truncating. Enforce native ingress limits before allocation/decoding, reject invalid/unsupported versions and unsafe sources, and retain generic-MIME/renamed-file handling. Never put the manifest into a giant deep-link URI or eagerly resolve all entries.

## 2. Bulk Find on Other Profiles

### Recommended presentation: compact setup, separate job/result page

Reuse **Find on Other Profiles** from single/multiple selection and a group context menu. No separate Bulk Find product name. Group entry shows direct/subtree scope; online input is the selected/loaded set, not an implicit full search crawl.

| Variant | Interaction | Tradeoff |
| --- | --- | --- |
| A — setup dialog + job/result page, recommended | Choose profiles, start, inspect progress, review by source/profile, explicitly save. | Compact entry with enough room for evidence and mixed failures. |
| B — inline progress card | Remain in the source timeline and expand a small result area. | Good for tiny batches; poor for detailed comparison. A minimized job chip from A provides most of its benefit. |
| C — permanent lookup workspace | Dedicated destination with job history and resume. | Useful only for frequent large jobs; adds navigation/persistence. Defer. |

### Setup, lifecycle and progress

Show source count and eligible target profiles in saved order using existing icons/names. Disambiguate equal names. Exclude the actual originating profile per source, not every account on the same host. Mixed input can make a target partially eligible; explain unsupported cases instead of treating them as no matches.

Expensive original downloads for hashing are off by default behind Advanced. Reuse verified hashes already available. Ask for a destination group at Save, not before useful results exist.

Snapshot source identities/order and target access bindings. One route-independent manual Riverpod controller owns bounded work under the existing request coordinator. Back/Close minimizes to a return affordance; **Cancel** stops new work and owned in-flight requests where safe, retaining validated partial results. Initial scope has no restart recovery or promised OS-background execution.

Distinguish progress over source Posts, source×target checks, and physical requests. One Pixiv artwork lookup can serve multiple Pages. Per-target states include checking, quota wait, login required, failed and complete. Cursor-dependent requests remain sequential; independent jobs provide concurrency. Coalesce only within the same full access scope, and never reuse one Pixiv session across unrelated artworks.

### Result review

One result page offers **By source / By profile**. By source shows the original and expandable target matches. By profile shows deduplicated target Posts in the ordinary grid. Keep the source→target evidence map in job memory, including many-to-one matches.

Separate **Exact file**, **Artwork association**, **No match**, **Failed**, **Unsupported**, and **Incomplete/not checked**. A budget stop or skipped optional hash phase is not proof of absence. A source with one successful match can still have failed/unfinished checks elsewhere; retain those per-target states.

Recommended default: preselect verified exact-file matches; require explicit **Include artwork matches** for Pixiv source associations, which may refer to another Page of the same Work. Ambiguous candidates remain unchecked. This is a proposed product default, not an approved new matching algorithm.

Retry only failed checks. Explicit Continue extends budget-limited checks. Neither restarts successful work. Reuse existing exact/source lookup services and validation rather than launching the single-Post modal repeatedly.

### Save

Save asks for parent location/name and previews an ordinary hierarchy:

```text
Chosen name
  Source
  Danbooru
  Gelbooru
  ...nonempty selected target profiles
```

Source contains the complete input, including unmatched Posts. Target groups contain reviewed matches only; no empty groups merely to preserve progress reports. Use normal semantic deduplication, safe snapshots and membership dates. The in-memory result view retains source order; do not promise a new manually ordered saved-group feature.

Create groups/memberships through one mutation/rollback boundary. Repeated Save cannot duplicate the tree; equal names do not authorize overwrite. Cancellation permits explicit Save Partial. Open the resulting parent in Bookmarks; no remote favorite mutations, persistent lookup graph or second group model.

## 3. Realbooru NEW tracking: use IDs

Within one site's ordered result set, IDs meet the user's NEW requirement. Do not fetch detail pages merely for dates. Realbooru's own cheat sheet documents ID sorting in both directions [E1]. Actual returned-order fixtures remain an acceptance check, not a reason to reject the approach.

The app already stores `highestSeenPostId`, and `SearchRefreshService.detectedNewPosts` compares IDs. The blockers are the thumbnail-only capability rejection, the scanner's createdAt requirement and a second rejection when constructing previews. `SearchPostPreview.postCreatedAt` is nullable; `RecentSearchPostIdentity.postCreatedAt` is not [S3–S5].

Use an engine/site-owned refresh plan declaring ID order. The first successful bounded snapshot establishes a quiet baseline. Later distinct matching IDs above its high-water mark trigger NEW. Preserve source/profile/query/revision isolation and existing commit guards; errors, cancellation or stale responses never advance it. Handle an existing compatible sort explicitly; do not blindly append conflicting metatags or advertise random/updated-order semantics as new uploads.

Continuation must use the actual HTML page width (42 in the inspected parser), not the generic requested limit 50. Do not claim exhaustive counts from one bounded page: retain incomplete/lower-bound counts where appropriate. ID-range keyset pagination requires separate endpoint verification but is not a prerequisite for ID-based NEW.

Keep missing upload dates null. Use observation/check time for retention and last-checked labels, never as fabricated createdAt. Audit identity codecs and timestamp-derived selectors; make persistence changes only where required, retaining old records/other engines. IDs from different sites are not comparable timestamps. An old Post newly matching after a tag edit is not a newer upload and need not become NEW under this contract.

## 4. Gelbooru: replace competing throttles

Treat 10 requests/second as the user's supplied target allowance, not an independently verified universal API/CDN quota [E2]. Share it across the app's Gelbooru profiles; never multiply it by accounts/connections.

Current fallback limits compose: four in-flight API requests, passive 12/minute, and bulk one/1,250 ms. Adding 10/s alone leaves bulk near 0.8/s and passive dispatch averaged at 0.2/s [S6].

Recommended site-specific changes:

- One rolling 10-starts/second budget, paced near one start per 100 ms. No banked idle tokens or wall-clock-boundary double bursts.
- Remove the separate bulk 1,250 ms and passive 12/minute dispatch windows for Gelbooru; make them optional in the existing policy rather than adding another scheduler. Other sites retain their policies.
- Proposed initial bounds: 16 in-flight exchanges, at most 14 noninteractive, leaving admission room for user actions. Revise the existing two-passive-in-flight cap too. These numbers are tuning proposals, not server limits or benchmark results.
- Reuse priorities: interactive/user work wins newly available slots. Unused requests/second remain usable by queued bulk/due automatic/speculative work, subject to admission and safety budgets.
- Retain per-Topic adaptive refresh intervals, due-work rules, lifecycle checks, cancellation and job/page/byte bounds. Faster dispatch is not permission to poll continuously.
- Count API retries, redirects and refresh calls against the relevant logical quota. Keep actual origin/credential boundaries separate; do not assume arbitrary subdomains share trust or a quota.

Throughput depends on latency and useful independent work: sustaining 10/s requires roughly `10 × mean latency in seconds` concurrent requests. A single sequential cursor chain cannot exploit all slots. At high latency the bounded concurrency cap intentionally wins over utilization. Never invent duplicate requests to fill capacity.

Honor Retry-After/coordinated cooldown; reduce pacing on repeated rate limits and recover cautiously. Do not auto-replay unsafe mutations. Measure actual starts, queue causes and useful throughput without credentials/sensitive URLs.

Media requests bypass the API coordinator. Do not apply the account API allowance to CDN images without evidence, or claim that this tuning fixes thumbnail failures [S6].

## 5. Viewer: retain the already displayed frame

Progressive rendering exists: `RawPostDetailsImage` supplies lower media, and `ProgressivePostImage` retains a decoded representation until a higher one decodes [S1]. However, source inspection establishes two gaps:

1. Navigation carries `initialThumbnailUrl`, not the actual decoded grid frame. A visible placeholder/fallback/probe winner can differ from that preferred URL.
2. Staging creates a new provider and CancelToken. Provider equality includes the token and fetchStrategy, so matching URLs do not guarantee decoded-cache reuse. Sequential lower candidates may also wait on a higher rendition before reaching an available low one [S1–S2].

This explains a plausible failure path, not a complete device reproduction. Do not globally remove cancellation from cache identity and accidentally couple unrelated request owners.

### Proposed correction

Pass a short-lived **displayed-preview seed** from the tapped cell through the existing route context: safely retained/cloned decoded pixels, actual rendition, semantic Post identity and access scope. Include the actual placeholder/fallback/format-probe winner. This is presentation state only, not a Post field, backup change or global image cache.

Show it on the first available Viewer frame, with or without Hero. Load sample/original independently; replace only after their first frame decodes. Failure keeps the preview plus working Retry. Explicitly release retained images on promotion, navigation cancellation/disposal and access loss. Revalidate access before painting, retain full-post geometry/zoom/AutoComic/Details state, and do not revive dynamic masonry sizing.

Without a seed, prefer already available compatible decoded/cache representations before waiting on new network variants. Keep fallback probing and adjacent-page preloading bounded. Video keeps its poster until ready; this needs no extra player or new Ugoira Page entries.

Key regression: hold the sample unresolved, open through the real grid/navigation path with a decoded thumbnail, assert preview on first paint and no additional thumbnail HTTP/decode. Cover promotion, target failure/retry, no-Hero, actual fallback/probe winner, equal URLs, rapid disposal and source revocation. Most checks belong in widget/image-provider tests; Android verifies real first paint/transitions.

## 6. Other remaining points

### Fast-scroll thumbnails, Retry and prefetch distance

The full-tile InkWell above the image is the concrete Retry hit-test defect. Put ordinary tile interaction at an appropriate ancestor so the nested retry button owns its tap, preserving selection, long press, quick actions, keyboard and semantics. Do not add a duplicate overlay button.

Preserve typed transport errors. Expected cancellation and intentionally deferred image loading must not become permanent generic failures. Flutter deliberately defers new image work during rapid scrolling [E3]; resume after settling. Bound transient retry/backoff and coordinate host 429/Retry-After rather than starting a tile-wide retry storm. Authentication, not-found and decode failures need appropriate stop/recovery behavior. Rebuilds/visibility changes must not reset budgets indefinitely.

The initial Gelbooru failure status is still unobserved. Capture sanitized error/status class, host, cancellation reason and generation in local reproduction. Inject failures in tests through the actual tile wrapper. Fix recovery before comparing one versus two thumbnail viewports. Cache extent builds content both ahead/behind and does not override high-velocity image deferral. Measure blank time, requests/decodes and memory, not merely the extent value.

### Rule34 favorite mutations

Website write-session cookies and API credentials are different. Normalize only known response contracts, such as trimmed string/integer 1/2/3; never accept arbitrary numeric prefixes or HTML as success. Distinguish expired/missing login. Removal's HTTP 200/302 alone is not confirmation: inspect authentication/redirect outcome and verify through a reliable read path when acknowledgement is ambiguous. Preserve mutation markers and avoid replaying uncertain writes.

One authorized add/already-added/remove/expired-session round trip is still required locally. No authenticated session was available and no mutation was attempted; the user's exact failure is not proven.

### Gelbooru Pools and Related

Current official documentation confirms `pool:` membership search, including an approximate 50k searchable-members limit [E4]. It does not establish an ordered complete manifest. A shared ContentGroupSource adapter must obtain actual source order/continuation rather than relabel default ID-sorted search as Pool order. Keep unavailable/partial members and enable only verified ordering capabilities.

Related is independent. Historical official discussion says parent/child associations had been removed; current cheat-sheet/DTO fields do not prove their return. Keep it unavailable until a current genuine example and endpoint semantics are demonstrated. Do not synthesize families from similar tags or Danbooru assumptions.

### Pixiv Ugoira

Use the existing metadata/archive/frame DTO path and a bounded frame player within the shared Post media slot, not a new FFmpeg/transcoding dependency or one Post per frame. Pixiv confirms individual frame timing [E5]. Retain the poster during download; play using a monotonic clock/cumulative durations, with only current/ahead decoded frames held. Respect occurrence activity and animation settings.

Cache the validated archive with its timing metadata under existing access-scoped media ownership. Bound compressed/actual inflated bytes, frame count, dimensions and decoded memory. Reject traversal/absolute paths, conflicting names, missing/non-image frames and invalid durations. Benchmark Android resource limits. Do not label the medium archive as original quality, or a saved poster as a saved animation. Conversion/export remains separate from playback.

### Collection upload sorting and Following folder previews

Remove the newest-date fallback for missing oldest-upload metadata. Unknown remains unknown and consistently follows known dates. Verified within-site ID sequence is valid for newer/older navigation, not fabricated timestamps or cross-site chronology. Do not crawl all Pool members for overview sorting; distinguish sampled extrema from authoritative bounds.

Folder mosaics should share Topic cards' effective preview provider. ID tracking will populate Realbooru's normal previews, but disabled/unsupported tracking still needs the fallback. Select up to four candidate Topics in existing order, reuse/cache/coalesce by full profile/query scope, and never scan the whole subtree or write tracking checkpoints merely for covers.

### Credential clipboard export and BASE64 import

Bind sensitive-copy confirmation to the generated artifact, not a later mutable option. Retain size bounds and Android's sensitive clipboard marking, which suppresses previews but is not encryption/access protection [E6]. No credential logs or automatic clipboard reads.

Use one BASE64 entry surface with Paste/Continue and one bounded decoder accepting the legacy prefix or raw BASE64, feeding the existing package validation/preflight/transaction. Check encoded/decoded limits and reject malformed data without writes. Do not add a parallel importer or import automatically on paste.

### e-shuushuu favicon

The app currently uses the Google S2 fallback. The site's HTML was readable via web retrieval, but actual current icon bytes could not be retrieved/decoded in this environment. That is not proof of a site 404. Verify the actual icon declaration/MIME/bytes before adding one shared exact-host mapping; a bundled verified asset is a reasonable alternative consistent with the existing Danbooru asset path. Record provenance. Do not guess a working URL or build a general scraper for this case.

### Deferred/accepted scope

Viewer icon circles/shadows remain undecided. Compare real bright/dark media backgrounds together, including the custom Info glyph, contrast and touch targets. No visual treatment is selected here. The Selection Manager gap report remains withdrawn. Overlay initial-hide lifecycle, persistent folder-access hint removal and other accepted corrections retain their earlier scope; none is implemented by this documentation.

## Verification and remaining empirical gates

Source inspection and primary documentation checks used the pinned baseline. The HTML study was exercised in Chromium with in-memory HTML loading: share/receive/save, composer reorder/remove, export entry, target setup, result/profile views, cancellation classification, minimize/resume and repeat-save guard. Width checks passed at 320/390/740/1100 px; 150% text passed at 390 px. JavaScript syntax/execution checks passed, and screenshots were inspected. The browser blocks `file:` navigation in this environment, so automation used `set_content`; the file itself has no external asset/build/server dependency. These checks validate the study, not the Flutter implementation or real network/persistence behavior.

No Flutter/Dart tests, app build, Android/Maestro run, live throughput benchmark, authenticated favorite mutation or Ugoira playback test was performed. No independent subagents ran: discovery exposed no launcher. Review was by the same assistant. Container Git networking was unavailable; design documentation was published through the GitHub connector, without a local repository/worktree implementation.

Concrete remaining gates: fast-scroll transport/first-paint reproduction; authorized Rule34 round trips; Gelbooru Pool order/continuation; Realbooru actual returned-order fixtures; Android Ugoira limits; collection snapshot sanitization/native ingress; native clipboard/file handoff; actual favicon bytes. These must not be reported as already verified.

## Source map

[S1] [PostDetailsImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/post_details_image.dart), [ProgressivePostImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/progressive_post_image.dart), [navigation](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/routes/route_utils.dart).

[S2] [Provider identity](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/extended_image/lib/src/dio_extended_image_provider.dart), [grid rendition selection](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart).

[S3] [FollowingTopic](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/types/following_topic.dart), [preview/identity dates](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/types/search_post_preview.dart).

[S4] [Refresh service](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/services/search_refresh_service.dart), [scanner](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/refresh/chronological_search_scanner.dart).

[S5] [Fetch policy](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/refresh/search_refresh_fetch_policy.dart), [Realbooru parser](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart).

[S6] [Quota policy](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_quota_policy.dart), [coordinator](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_request_coordinator.dart), [classes](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_request_context.dart), [media bypass](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/coordinated_dio.dart).

[S7] [PostBookmark](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/bookmarks/src/types/post_bookmark.dart), [StoredBookmarkCodec](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/bookmarks/src/data/stored_bookmark_codec.dart), [StoredPostCodec](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/post/src/data/stored_post_codec.dart). Existing lookup/collection paths and remaining source references are in the [earlier handoff](../handoffs/2026-11-11-ticket-triage.md) and its individual investigations.

[E1] [Realbooru cheat sheet](https://realbooru.com/index.php?page=help&topic=cheatsheet).

[E2] [Gelbooru API documentation](https://gelbooru.com/index.php?page=wiki&s=view&id=18780). The specific 10/s target is user-supplied, not independently verified as universal.

[E3] [Flutter ScrollAwareImageProvider](https://api.flutter.dev/flutter/widgets/ScrollAwareImageProvider-class.html).

[E4] [Gelbooru current cheat sheet](https://gelbooru.com/index.php?page=wiki&s=view&id=26263); [historical parent/child discussion](https://gelbooru.com/index.php?page=forum&s=view&id=1939) is not current endpoint validation.

[E5] [Pixiv Ugoira](https://www.pixiv.help/hc/en-us/articles/235584628-What-are-Ugoira).

[E6] [Android ClipDescription](https://developer.android.com/reference/android/content/ClipDescription#EXTRA_IS_SENSITIVE) and [copy/paste guidance](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste).
