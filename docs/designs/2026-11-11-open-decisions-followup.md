# Follow-up: collection UX, ID tracking, request budgets and media continuity

Baseline: `develop@22348b2fb20049088705ce38f5b261e191b148af`, rechecked on 2026-11-11. This is design/research, not runtime implementation. Continue the existing research branch; do not merge it or create a PR without authorization.

This document refines the [earlier investigation](../handoffs/2026-11-11-ticket-triage.md). It supersedes the earlier caution about using IDs for Realbooru NEW detection and the proposal to merely add a Gelbooru ceiling. The user wants ID-based detection, effective use of the supplied 10 requests/second allowance, UI alternatives for collection sharing and bulk lookup, and immediate reuse of an already visible thumbnail in the Viewer. Other previously proposed corrections were accepted in principle. Viewer icon styling explicitly remains a joint design discussion.

The accompanying `collection-lookup-concepts.html` is a single-file, offline browser study delivered in the chat. Its posts, requests, results, sharing and persistence are synthetic. It illustrates three entry/presentation alternatives per feature, not a production Flutter screen or a pixel-perfect rendering of Kurumi. The substantive contract is below.

## 1. Sharing a viewable collection

### Recommendation: extend Share, not navigation or backup import

Keep one existing **Share** action. For multiple selected Posts, offer **Collection file** beside applicable existing payloads. Selecting it exposes an optional title, the exact scope/count and **Share file** in the same compact Kurumi flow; do not stack a separate wizard. A saved Bookmark Group's context menu can enter the same flow directly. Do not add a permanent Collections destination or a second local collection database.

| Variant | Interaction | Tradeoff |
| --- | --- | --- |
| A — existing Share surface, recommended | Select → Share → Collection file → native share. Optional title and exact count only. | Least navigation and best fit with current workflows. Uses the current timeline order. |
| B — dedicated composer | Selection opens an editable ordered list; remove/reorder before sharing. | Useful for deliberate curation, but duplicates editing controls. File ordering must not modify Bookmark Group ordering. |
| C — Export entry/read-only export preview | Reach the collection through Export, or add temporary viewing of a `.bsexport`. | Reuses export discovery but conflates viewing and importing, and exposes the viewer to broad backup/credential payloads. Not the recommended everyday sharing path. |

A hosted album or URL shortener is not a simpler substitute: it adds a service, availability/privacy ownership and upload lifecycle. Sharing image files works without Boorusama but loses typed source context. Folder sync remains the better existing direction for an ongoing, updating exchange; it is not a replacement for sending one fixed selection. These are different intents, not additional buttons to display on every share sheet.

### Scope and ordering

Selection means exactly the selected Posts, ordered by their position in the current timeline, not checkbox-click order. Online search must never crawl unseen pages to make an implied complete collection. A whole-group entry shows an explicit direct/subtree choice only when meaningful, with the corresponding count. Active filters must be visible in the scope description; do not silently share hidden or unselected content.

Keep the first format Post-only. A saved Pool/Work/Gallery reference is not permission to expand all members: explain unsupported selected Group entries and require an explicit scope correction rather than silently dropping or expanding them. A later mixed-entry format can carry existing typed Group references without changing their semantics.

### Receiving

Open a received file directly into a temporary shared Post timeline. Use the ordinary Header, grid options, selection and Viewer. Default to **File order**; any temporary sort/filter does not rewrite the document. One Save action opens the existing nested Bookmark Group picker. Opening, closing and reading cause no library writes, favorites, NEW counters or sync subscriptions.

Resolve access once per source/account binding. Reuse a compatible profile or an approved anonymous reader; ask once per ambiguous source. Never create profiles automatically or borrow another account after the bound account disappears. Keep unavailable reference identities and positions. Use the established compact unavailable-count explanation rather than a blocking import wizard. Preserve selection and scroll while resolving individual entries asynchronously.

Save must preserve unresolved portable references through the existing unresolved-bookmark path, not invent empty Post snapshots. Where that path requires a snapshot, use a validated reference-preserving record supported by the shared storage contract; do not silently discard unresolved entries. Saving is explicit and transactional. Merely sharing an existing group does not create another group locally.

### File contract

Reuse `.bslink`, its native MIME/file-opening routes and strict reference codecs. Keep v1 unchanged. Add a discriminated v2 collection envelope with optional title and ordered portable Post references. The manifest is a local navigation document, not a new remote `ContentKind.group`. Do not embed a giant JSON payload in a URI.

Reference-only is the first-version recommendation. It avoids exporting tags, account IDs and access-sensitive snapshots, but needs lazy metadata reads. Use existing safe batch lookup where supported and prioritize the visible range; never resolve the whole file eagerly. Optional sanitized snapshot/cover hints are a later performance extension, not necessary for the initial feature. They must never grant media access.

Retain the earlier proposed v2 limits of 2 MiB and 5,000 references, subject to fixture verification, with smaller field limits and bounded native ingress before decoding. These are proposed safeguards, not measured optimal values. v1 keeps its 16 KiB limit. Reject unsafe origins, invalid references and unsupported versions before networking. Preserve the generic-MIME/renamed-file fallback and provide a useful older-app/update message. A collection file is not an offline media archive.

## 2. Bulk Find on Other Profiles

### Recommendation: compact setup, dedicated result page

Reuse **Find on Other Profiles** in single/multiple selection and optionally a Bookmark Group's existing context menu. There is no separate Bulk Find feature name. Group launches show direct/subtree scope explicitly. Online input is the selected/loaded set, never an unannounced complete search crawl.

| Variant | Interaction | Tradeoff |
| --- | --- | --- |
| A — setup dialog + job/result page, recommended | Choose target profiles, start, inspect progress, review by source/profile, explicitly save. | Compact entry without squeezing evidence and mixed failures into a popup. |
| B — inline progress card | Stay in the originating timeline; expand a small progress/result section. | Good for tiny batches, poor for large comparisons and detailed recovery. A minimized job chip from A provides most of its benefit. |
| C — permanent lookup workspace | Dedicated destination with setup, history and resumable jobs. | Useful only for frequent large jobs; requires new navigation and persistence. Defer rather than build speculative job history. |

### Setup and lifecycle

The setup dialog shows the source count and target profiles in saved order. Use existing profile labels/icons and disambiguate duplicate names. Exclude the actual originating profile per source item, not all profiles sharing a site. For mixed selections, show partial eligibility rather than globally excluding a target that is valid for other source items. Unsupported adapters are explained, not represented as zero matches.

Default expensive original downloads for hashing to off, behind an Advanced disclosure. Reuse existing verified MD5 data without downloading. Only supported, explicitly selected targets may run. Do not ask for a destination group before the user knows whether useful results exist.

Snapshot source identities, source order and target access bindings at Start. One route-independent manual Riverpod job owns bounded work. Back/Close minimizes it to a compact return affordance; **Cancel** stops new work and cancels owned in-flight requests where safe. Preserve validated partial results. The job continues only while the app can run; the initial version promises neither Android background execution nor restart recovery. No new persistent job database is needed.

Show source-post progress separately from source×target checks and physical requests. An artwork lookup may serve several Pixiv Pages, so none of these counts are interchangeable. Per-target states include checking, quota wait, login required, complete and failed. Coalesce source queries only within the same full access scope. Cursor-dependent pages remain sequential; independent source/target jobs supply concurrency.

### Results and evidence

Use one result page with **By source / By profile** as a view selector. By source shows the original thumbnail and expandable target matches. By profile provides a normal grid of deduplicated target Posts. Preserve the source→target mapping in job memory for comparison even when several sources resolve to one target.

Distinguish **Exact file**, **Artwork association**, **No match**, **Failed**, **Unsupported**, and **Incomplete/not checked**. A budget stop or optional hash phase not attempted is not proof of absence. A source can have a valid match on one profile and an unfinished check on another; retain per-target status instead of hiding that uncertainty behind an overall green success count.

Recommended selection default: preselect verified exact-file matches; require an explicit Include artwork matches choice for source-associated Pixiv results. Show that these may belong to a different Page of the same Work. Ambiguous candidates stay unchecked. This is a proposed product default, not a claim of user approval. Do not add a new similarity-matching algorithm.

Retry only failed checks; explicit Continue extends budget-limited checks. Neither action restarts successful work or duplicates saved results. Reuse existing lookup services and their response validation. A shared Pixiv session must not be reused across unrelated artworks.

### Saving

Save Results asks for a parent location and new group name, then previews:

```text
Chosen name
  Source
  Danbooru
  Gelbooru
  ...nonempty selected target profiles
```

Source includes the complete input, including unmatched/unchecked Posts. Target groups contain reviewed matches only; do not create empty groups just to preserve a progress report. These are ordinary nested Bookmark Groups with no remote favorite mutations. Use normal semantic deduplication, safe snapshot merging and membership dates. Do not promise manually ordered saved groups when their current storage model does not support it; the result view retains source order independently.

Create the hierarchy and memberships under one mutation/rollback boundary. Repeated Save cannot create duplicate trees; an existing equal group name is never overwrite permission. Cancellation offers Save Partial explicitly. After saving, open the new parent in the existing Bookmarks UI. Do not persist the lookup evidence graph as a second collection architecture.

## 3. Realbooru NEW tracking: IDs are the right key

For the user's requirement — detecting newer Posts within one site's ordered result set — ID ordering is sufficient. Do not require upload timestamps to detect NEW and do not fetch detail pages merely to obtain dates. Realbooru's own cheat sheet documents ID sorting in both directions [E1].

The application already stores `highestSeenPostId` and `SearchRefreshService.detectedNewPosts` compares IDs. The present blockers are the thumbnail-only capability rejection, the scanner's missing-createdAt rejection, and a second rejection while building previews. `SearchPostPreview.postCreatedAt` is already nullable, but `RecentSearchPostIdentity.postCreatedAt` is not. This is a focused contract correction, not a replacement tracking architecture [S3–S5].

Use an engine/site-owned refresh plan declaring verified ID ordering. Ordinary supported Realbooru queries are fetched in descending ID order for the initial bounded snapshot. Preserve the original user query; handle an existing compatible sort explicitly rather than blindly appending conflicting metatags. Unsupported/random/updated-order semantics must not be silently presented as new-upload tracking.

First successful refresh establishes the baseline without marking the existing collection NEW. Subsequent distinct matching IDs above the committed high-water mark trigger NEW. Compare only inside the same source, profile, query and revision. Query/profile/policy changes establish a new guarded baseline; late old responses cannot commit. Failed, cancelled or malformed responses cannot advance it.

Use the actual HTML page width (currently 42) rather than the fallback request limit 50 when deciding continuation. A shorter requested limit is not necessarily honored by a fixed-width HTML listing. Validate source continuation and ordering. Do not advertise complete enumeration from one bounded page: retain an `N+`/incomplete count when appropriate. ID-range keyset pagination is an optimization only after the actual site honors it; ID-based NEW detection does not depend on it.

Keep absent upload dates null in previews, feed snapshots, sorting and backups. Use observation/check time for retention and refresh status, never as fabricated `createdAt`. Audit the recent-identity codec and timestamp-derived selectors; version/add fields only where persistence requires it. Legacy date-based records and other engines retain their existing semantics. An ID-only source cannot supply a truthful “last uploaded X ago” label; show last checked where appropriate. IDs from different sites must never become a global chronological sort key.

Known semantics: an old Post newly matching after a tag edit is not a newer upload, and a deleted/reappearing older ID is not NEW. These match the requested upload-order intent. Source dates, exact unseen counts over arbitrarily long gaps, and cross-site chronology are separate problems.

## 4. Gelbooru: use the allowance, remove competing bottlenecks

Treat the user's 10 requests/second value as the intended account policy. Public API documentation confirms authentication/throttling but does not establish a universal 10/s quota for every account or CDN [E2]. Never multiply the allowance by creating more profiles or connections.

Current fallback policy permits four in-flight requests, passive 12/minute and explicit bulk one/1,250 ms. Those limits compose, so adding 10/s alone leaves bulk at approximately 0.8/s and passive work at 0.2/s averaged over its minute window. The current coordinator already handles priorities, windows, concurrency, cancellation and cooldown [S6].

Recommended Gelbooru-specific policy:

- One shared API start budget across this app's Gelbooru profiles: at most 10 starts in a rolling second, paced near one start per 100 ms. Do not bank minutes of tokens or burst 10 again at an arbitrary wall-clock second boundary.
- Remove the independent bulk 1,250 ms pacing and passive 12/minute dispatch cap for this known site. Prefer optional class windows in the existing policy, not a second scheduler. Other sites retain their evidenced/fallback policies.
- Start with a bounded maximum of 16 in-flight API exchanges; allow at most 14 noninteractive exchanges so interactive work has admission room. These are proposed starting values to measure, not server limits. Existing two-passive-in-flight restriction must also be revised or it remains a bottleneck.
- Reuse existing priority classes. On every newly available slot, interactive/user work wins over bulk, periodic and speculative work. No permanently reserved requests/second are wasted when the interactive queue is empty. A quota permit does not authorize an otherwise disallowed/inactive request.
- Keep per-Topic adaptive refresh intervals, due-work rules, app lifecycle restrictions, job/page/byte budgets and cancellation. This improves dispatch of useful queued work; it does not continuously poll every Topic at 10 Hz.
- Aggregate starts for all API purposes, including redirects, retries and credential refresh where they hit that quota. Distinguish actual destination origin from logical quota grouping; do not assume arbitrary subdomains share a trusted account or allowance.

Concurrency and rate are different: four independent exchanges with one-second latency cannot sustain more than roughly four completions/second; a single sequential cursor chain cannot be accelerated by raising the cap. In general, sustaining 10/s needs roughly `10 × mean latency in seconds` concurrent useful requests. Use independent jobs to fill the budget, not speculative duplicate pages. At sufficiently high latency, the safety cap intentionally wins over utilization.

Honor Retry-After and coordinated cooldown. Reduce effective pacing on repeated 429/timeouts and cautiously recover; do not auto-replay unsafe favorite mutations. Never use an account swap as recovery. Measure actual starts, queue reason and useful completion throughput with sanitized telemetry before tuning above the proposed concurrency.

Image/CDN requests are marked as media and bypass the API coordinator. Do not apply this account API allowance to thumbnails without evidence. Thumbnail concurrency, cancellation and transient recovery need their own media-path investigation. API throughput work must not be sold as the thumbnail fix.

## 5. Viewer: show pixels we already have

The report is valid as a required behavior, but it is not evidence that progressive rendering is entirely absent. `RawPostDetailsImage` already supplies lower media to `ProgressivePostImage`; that component retains a decoded lower image until a higher candidate decodes [S1].

Two confirmed source mechanisms explain why this does not guarantee immediate reuse:

1. Navigation passes `initialThumbnailUrl`, not the actually displayed decoded frame. The grid may currently show a low placeholder or a successful fallback different from its preferred URL.
2. `_stage` creates a fresh provider and CancelToken. `DioExtendedNetworkImageProvider` includes CancelToken and fetchStrategy in equality, so a same-URL candidate is not necessarily the grid's decoded cache entry. It can re-read bytes and decode again. Lower candidates are also tried sequentially, potentially leaving a cached low representation behind a pending higher one [S1–S2].

These are source-confirmed gaps, not a reproduced complete device diagnosis. Do not globally remove cancellation from provider identity: that can incorrectly share cancellation ownership between consumers.

### Smallest robust correction

Capture a short-lived **displayed-preview seed** from the tapped grid cell. It carries a safely retained/cloned decoded frame, its actual rendition, semantic Post identity and full access scope. This is UI presentation state only, not a persisted Post field, new image cache or backup payload. Include actual placeholder/fallback/format-probe winners, not merely the configured preferred thumbnail URL.

Pass it through the existing route context to the initial Viewer occurrence. Render it on the first available Viewer frame, including when Hero animation is disabled. Start sample/original loading independently. Replace the seed only after the higher representation's first frame decodes; on failure keep the seed and a functioning Retry action. Never flash a blank frame between two usable representations.

Own/release the retained image explicitly on promotion, source revocation, route disposal and cancelled navigation. Recheck access before painting; an in-memory frame must not bypass changed account/content policy. Keep full-post geometry stable, contain-fit a cropped preview, and preserve zoom/AutoComic/Details state. Do not revive the abandoned dynamic masonry sizing experiment.

For opening without a seed, prefer an already available compatible decoded/cache candidate before waiting for another network rendition. Keep candidate probing bounded and avoid loading every quality variant at once. Adjacent Viewer pages retain existing bounded preloading; do not add an unbounded preview registry just for this bug. Video uses its poster until ready; no extra video player or Ugoira frame expansion is required.

Essential regression: hold the sample Future unresolved, provide a decoded thumbnail, open the real navigation chain and assert visible preview on the initial frame with zero extra thumbnail HTTP/decode work. Then test promotion, target failure/Retry, no-Hero, fallback/probed images, identical thumbnail/sample URLs, profile loss, rapid route disposal and changed access scope. These tests can predominantly be widget/image-provider tests; Android checks verify actual first paint and transitions.

## 6. Remaining research decisions

### Fast-scroll thumbnail failures and Retry

The full-tile InkWell above the image is a concrete hit-test defect. Move normal tile interaction to an appropriate ancestor so the nested Retry control owns its tap; preserve long press, quick actions, selection, keyboard and semantics. Do not duplicate Retry above the overlay as a workaround.

Preserve typed transport failures end-to-end. Expected cancellation/deferred scroll loading must not become a terminal generic failure. Flutter intentionally defers new image work during fast scrolling [E3]. A genuine deferred load must resume after scrolling settles. Retry transient failures with bounded backoff; coordinate media-host 429/Retry-After instead of having every tile retry at once. Authentication/forbidden/not-found/decode failures need their appropriate stop/recovery behavior, not infinite automatic retries. Visibility/rebuilds must not reset the retry budget.

Actual initial Gelbooru failure status remains unobserved. Capture sanitized status/error class, media host, cancellation reason and request generation in the local reproduction; never raw signed URLs or credentials. Test injected cancellation, timeouts, 429, successful recovery and taps through the real tile wrapper. Fix this before comparing one versus two thumbnail viewports. The larger cache extent builds more content both ahead and behind; it is not automatically direction-aware and may not start downloads during Flutter's high-velocity deferral. Measure visible blank time, request/decode counts and peak memory, not just cacheExtent.

### Rule34 favorite mutations

Keep API credentials and the website write session distinct. Normalize only the known response types (trimmed string or integer 1/2/3) and classify them explicitly. Do not accept arbitrary numeric prefixes or HTML as success. Distinguish missing/expired session from a genuine server failure.

For removal, a 200/302 alone is insufficient. Check the redirect destination/authentication outcome and obtain reliable confirmation through the existing favorite state/read path when the endpoint has no unambiguous acknowledgement. Preserve mutation markers so retries cannot replay an uncertain write. Capture one authorized add/already-added/remove/session-expired round trip locally; there was no authenticated session available for this research, and no mutation was attempted. The exact reported failure is not yet proven.

### Gelbooru Pools and Related

Current official cheat-sheet documentation advertises `pool:` membership search [E4]. It does not prove a complete ordered manifest or count: the documented search has an approximate 50k searchable-members limit. An ordered Pool adapter must obtain real membership order and continuation from the Pool source, not label default ID-sorted search as Pool order. Reuse ContentGroupSource and lazy shared member hydration; do not add a parallel group model. Enable ordering/sorting only for verified contracts and preserve partial/unavailable members.

Related is independent. Old Gelbooru material and DTO parent fields do not prove current Gelbooru.com support. Historical official forum material states parent/child associations had been removed, and the current cheat sheet does not establish their return. Keep Related unavailable until a current genuine example and request semantics are demonstrated; do not synthesize families from similar tags or import Danbooru parent IDs.

### Pixiv Ugoira

The existing client and DTO already provide an archive URL and individually timed frames. Pixiv confirms per-frame timing as part of Ugoira [E5]. Prefer direct, bounded frame playback inside the existing Post media slot over introducing an FFmpeg/transcoding dependency. A single Ugoira remains one Post with existing actions, not one Page/Post per animation frame.

Resolve metadata only when relevant, retain the poster while downloading, validate the archive/frame manifest and decode only a small ahead/current window. Seek using cumulative frame durations and a monotonic playback clock, not one independent timer per frame. Stop/pause when the occurrence is inactive; respect animated-image autoplay preferences. Cache the validated archive with timing metadata because the ZIP alone does not describe playback. Reuse access-scoped transport and media cache; no neighboring-animation download storm.

Bound compressed bytes, declared and actual inflated bytes, frame count, dimensions and decoded-memory use. Reject traversal/absolute paths, duplicate/conflicting names, missing frames, invalid durations and non-image payloads. Benchmark limits on Android rather than claiming that all frames fit in RAM. Do not label `zipUrlMedium` as an original-quality archive. Existing download/share controls must state the actual payload; a poster is not a saved animation, and conversion/export is separate scope.

### Collection upload sorting

Remove the newest-date fallback for missing oldest-upload metadata. Unknown stays unknown and sorts consistently after known values. Within a site, verified ID ordering can legitimately implement newer/older sequence behavior; it must not be converted into a timestamp or used across unrelated sites. Do not fetch every member of every saved Pool to make an overview sort complete. Use verified bounded metadata and keep any partial extrema distinguished from authoritative bounds.

### Following folder previews

Use the same effective preview provider for Topic cards and folder mosaics. ID-based Realbooru tracking will populate normal previews after a refresh, but unsupported queries and tracking-disabled Topics still need the shared fallback. Pick up to four candidate Topics from existing organization order, reuse cached results and coalesce requests by complete profile/query scope. No whole-subtree network scan and no fake tracking checkpoint writes just to populate a cover.

### Clipboard export and BASE64 import

Credential copy requires explicit confirmation bound to the generated artifact, not a mutable UI toggle. Keep the size limit and mark sensitive clipboard data on Android. Android's sensitive flag suppresses previews; it does not encrypt or add access protection [E6]. Explain this instead of promising secure clipboard transport. Avoid credential logs, previews or automatic clipboard reads.

Import BASE64 uses one text-entry surface with Paste and Continue, one bounded decoder for legacy prefix and raw BASE64, then the existing package validation/preflight/transaction. Validate encoded and decoded size; reject malformed/non-package data without modifying the library. Do not add a second importer or silently import on paste.

### e-shuushuu favicon

The app currently falls back to Google S2. This research could read the site's HTML through web retrieval but could not retrieve/decode the actual current icon bytes; that is a tooling limitation, not proof of a site 404. Do not guess a working icon URL. Verify the page's actual icon declaration and returned MIME/bytes, then use one exact-host mapping shared by all profile/source icons. A bundled verified site asset is a reasonable alternative consistent with the existing Danbooru asset path; record provenance. Do not build a general scraper or alter all hosts' favicon behavior for this one site.

### Viewer icon styling and already accepted items

No shadow/circle treatment is selected here. Compare actual screenshots together before changing glyph contrast, the custom-painted Info icon, touch targets or video overlays. Dark/bright image regions and enlarged accessibility settings matter. The withdrawn Selection Manager report stays withdrawn. Overlay lifecycle, persistent folder-access hint removal and other previously accepted scoped fixes retain their earlier specifications; this follow-up does not implement them or expand their scope.

## Verification and outstanding evidence

Source inspection and primary documentation checks were completed against the pinned baseline. The browser study was exercised in Chromium via in-memory HTML loading: share/receive/save, composer reorder/remove, export entry, target setup, results, profile view, cancellation classification, minimize/resume and repeat-save guard. Layout checks passed at 320, 390, 740 and 1100 px and at 150% text at 390 px. JavaScript execution produced no page errors. Screenshots were inspected. The sandbox browser blocks `file:` navigation, so the automation used `set_content`; the artifact itself has inline CSS/JS and no network/build/server dependency.

No Flutter/Dart suite, app build, Android/Maestro run, live throughput benchmark, authenticated favorite mutation or Ugoira playback test was performed. Browser-study checks do not verify the Flutter implementation. No independent subagents ran: capability discovery exposed no subagent launcher. Review was performed by the same assistant. Git access through the container was unavailable; only design documentation was published through the GitHub connector, not app code or a local-worktree implementation.

Remaining empirical gates are concrete: the fast-scroll transport error and first-paint reproduction, authorized Rule34 round trips, actual Gelbooru Pool order/continuation, Realbooru returned-order fixtures, Android Ugoira resource behavior, native clipboard/file handoff, and the favicon bytes. These are not unresolved architecture choices or grounds to fabricate successful validation.

## Sources

[S1] [PostDetailsImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/post_details_image.dart), [ProgressivePostImage](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/widgets/progressive_post_image.dart), [navigation context](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/details/src/routes/route_utils.dart).

[S2] [Image provider identity](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/extended_image/lib/src/dio_extended_image_provider.dart), [grid media selection](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart).

[S3] [FollowingTopic](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/types/following_topic.dart), [preview/identity timestamps](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/types/search_post_preview.dart).

[S4] [Refresh service](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/services/search_refresh_service.dart), [scanner](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/refresh/chronological_search_scanner.dart).

[S5] [Fetch policy](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/search/following_topics/src/refresh/search_refresh_fetch_policy.dart), [Realbooru parser](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/packages/booru_clients/lib/src/gelbooru_v2/parsers/rb_parsers.dart).

[S6] [Quota policy](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_quota_policy.dart), [coordinator](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_request_coordinator.dart), [request classes](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/api_request_context.dart), [media bypass](https://github.com/timberpile/Boorusama/blob/22348b2fb20049088705ce38f5b261e191b148af/lib/core/http/client/src/coordination/coordinated_dio.dart).

Collection/lookup reuse and other existing paths are pinned in the [portable collection](2026-11-11-portable-post-collection.md), [bulk lookup](2026-11-11-bulk-cross-profile-collections.md) and other linked investigations in the earlier handoff.

[E1] [Realbooru cheat sheet](https://realbooru.com/index.php?page=help&topic=cheatsheet).

[E2] [Gelbooru API documentation](https://gelbooru.com/index.php?page=wiki&s=view&id=18780). The specific 10/s allowance is supplied by the user, not independently verified as a universal limit.

[E3] [Flutter ScrollAwareImageProvider](https://api.flutter.dev/flutter/widgets/ScrollAwareImageProvider-class.html) and [resolution behavior](https://api.flutter.dev/flutter/widgets/ScrollAwareImageProvider/resolveStreamForKey.html).

[E4] [Gelbooru current cheat sheet](https://gelbooru.com/index.php?page=wiki&s=view&id=26263). [Historical parent/child discussion](https://gelbooru.com/index.php?page=forum&s=view&id=1939) is historical evidence only, not current endpoint validation.

[E5] [Pixiv: What are Ugoira?](https://www.pixiv.help/hc/en-us/articles/235584628-What-are-Ugoira).

[E6] [Android ClipDescription API](https://developer.android.com/reference/android/content/ClipDescription#EXTRA_IS_SENSITIVE) and [copy/paste guidance](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste).
