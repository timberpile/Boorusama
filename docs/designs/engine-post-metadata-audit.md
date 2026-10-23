# Post Metadata Coverage Audit and Implementation Specification

**Issue:** [#77 – Audit and Complete Engine Metadata Support](https://github.com/timberpile/Boorusama/issues/77)  
**Baseline:** `develop` at `4129eae5d6b4d3947c7d2d878b49e7db9830a97c` (2026-10-23)  
**Status:** Research and implementation guidance; no runtime changes or live-device verification in this document.  
**Scope:** The eleven user-approved fields in the post details experience, across every engine and officially registered site.

## 1. Decision and evidence rules

Danbooru is the **reference for consistent presentation**, not proof that every site provides every field. The approved baseline is:

1. Post ID
2. Content rating
3. **Original** media size (bytes)
4. **Original** resolution (width × height)
5. Original file format
6. Upload/publication date
7. Uploader
8. Favorite count
9. Score
10. Comment count
11. Post description

**Mandatory behavior:** Hide any unavailable, unverified, invalid, or semantically inapplicable field everywhere in post details (including file tiles, statistics, headers, and collapsed summaries). A genuine, source-confirmed numeric **0 must remain visible**; do not use `?? 0` or `> 0` as a substitute for availability of counts. A failed/unfinished asynchronous lookup is not a count of zero.

Field definitions:

| Field | Correct meaning / constraint |
| --- | --- |
| ID | **Source-visible post/work identifier** (`Post.sitePostId`), not the app's synthetic grid/persistence key; do not display invalid placeholder 0 |
| Rating | Source's *content/safety* classification, mapped explicitly to `Rating`; do not confuse stars, numerical user ratings, or Hydrus custom ratings with NSFW levels |
| Original size | Byte length of the original file, not sample, thumbnail, or encoded video alternative; avoid full-body downloads to discover it |
| Original resolution | Dimensions of the actual original media/page; do not present page-0 artwork dimensions as verified for every Pixiv page |
| File format | Original resource extension/MIME; avoid made-up `jpg` defaults and sample/video-preview formats |
| Upload date | Source post's publication/upload time; not modification, rating, indexing, or Hydrus local import date |
| Uploader | Uploading account, not artist tag/source creator; display name if available, resolving a verified account ID only when worthwhile |
| Favorite count | Aggregate server-side favorites/faves; Pixiv `total_bookmarks` is a **distinct Bookmarks metric** (requires labeling decision); a current-user favorite flag is not a count |
| Score | Comparable site-provided post score/vote total; favorites, star ratings, Bayesian ratings, and view counts are **not** substitute scores |
| Comment count | Server-provided total or authoritative count endpoint; `has_comments`, last comment date, and partial comment pages cannot supply exact totals |
| Description | Authored post/illustration caption/body. Artist commentary, tag wiki, generic site boilerplate, title, and pool description are different entities |

**Evidence notation:** "DTO" means the repository client declares/parses a field. "Post" means an integration actually transfers it into common or typed runtime data. "UI" means the existing details builder presents it. **DTO presence is not proof every registered host or authenticated response supplies it.** All findings below are static inspection of the pinned commit; web documentation is supporting evidence only. Exact host variants and permissions need fixture/live validation.

## 2. Authoritative implementation surfaces

- Registry/site inventory: `packages/booru_clients/boorus.yaml`. This lists engine sites, optional presets, and site-specific API/HTML overrides.
- API/HTML shape: `packages/booru_clients/lib/src/<engine>/types/` or `post_*_dto.dart` plus clients/parsers.
- Runtime mapping: `lib/boorus/<engine>/posts/parser.dart`; for Danbooru, `lib/boorus/danbooru/posts/post/src/converter.dart`.
- Engine data and persistence: each `lib/boorus/<engine>/posts/post_data.dart` and `post_codec.dart` (Danbooru has its own `posts/post/src/` layout).
- Shared runtime: `lib/core/posts/post/src/types/{post.dart,post_core_data.dart,post_record.dart,booru_post_data.dart}`.
- Common snapshots: `lib/core/posts/post/src/data/stored_post_codec.dart`; see `docs/post_architecture.md`.
- Rendering: `lib/core/posts/details_parts/src/file_details/{file_details_section.dart,default_file_details_section.dart}`, `lib/core/posts/details_parts/src/simple_post_stats_tile.dart`, and engine `posts/widgets.dart`/details builders.
- Specific detail fetch: `lib/boorus/gelbooru_v2/posts/full_post_loader.dart`, `lib/boorus/gelbooru_v2/posts/providers.dart`, per-engine `posts/providers.dart`; do not add per-grid-item metadata fetches.

### Confirmed shared bugs / design gaps

- `PostCoreData` and `PostRecord` have mandatory `int score`, `int fileSize`, `double width/height`, `String format`. Most parsers collapse missing values to 0 or fabricated defaults; there is no reliable general-purpose **known vs unknown** detail contract. Core has no favorite count, comment count or description.
- `FileDetailsSection` always renders `post.id` and a rating, even if the ID is synthetic or the rating is `unknown`. It unconditionally renders file format (including empty), hides size with `>0`, and builds a collapsed subtitle from potentially unknown placeholders.
- `SimplePostStatsTile` requires non-null integers and always shows all three metrics. Existing Danbooru, Philomena and Szurubooru consumers pass fallback zero for loading/missing values.
- Several engines have fields in their DTOs that are discarded during `dto -> record -> Post` conversion. UI-only updates would not fix those.
- The common snapshot schema is **version 1**, and typed engine codecs have separate versions. Unversioned changes to required saved fields or arbitrary engine changes can silently break bookmarks/Following, especially mixed-origin posts.

### Recommended implementation shape (proposal, not existing code)

Keep `Post` as the single runtime object. Add a small **nullable post-detail facts/availability contract** attached to `PostCoreData` or a compatible common presentation accessor, containing at least verified original size/dimensions/format, score, favorite count, comment count, description and any other fields whose presence cannot be represented by existing getters. Values must be nullable or carry an explicit verified-presence flag **independently of their value**. Avoid converting every consumer of `PostRecord.score` or `Post.width` to nullable solely for the detail UI: their current fallback representations support existing sorting, layout and media code.

Suggested normalized accessor names: `displayId` (derived from `sitePostId`), `ratingOrNull`, `originalByteSize`, `originalWidth`, `originalHeight`, `originalFormat`, `uploadedAt`, `uploaderDisplayName`, `favoriteCount`, `score`, `commentCount`, `description`. Use existing core fields directly where they already preserve availability, and avoid storing redundant facts without purpose. Specifically preserve raw nullable DTO score/counts **before** `?? 0` fallback. Keep existing `PostMetadata` reserved for pagination/search origin; do not reuse its name for new facts.

Make the chosen contract persist through `StoredPostCodec` with a backward-readable common schema evolution and, if needed, versioned engine codecs. **Old v1 snapshots have ambiguous zeros**: do not retroactively assert a zero came from the source; retain useful media and known nonzero values conservatively and allow optional detail refresh. Do not make old bookmarks unreadable or drop existing custom payloads. Include backward/forward/unknown-engine tests. Consider derived type-safe engine adapters when a field is already stored in `BooruPostData`, but do not force every engine into an identical data class.

## 3. Full engine-by-engine audit

Each entry lists fields actually present in the inspected client and/or parser, then the actionable gaps. All claims about future responses require a fixture against the specific site; **unknown is a valid final result** when a reliable source field does not exist.

### 3.1 Danbooru — reference

**Registered hosts:** danbooru.donmai.us, donmai.moe, safebooru.donmai.us, aibooru.online, testbooru.donmai.us.

**Source:** `packages/booru_clients/lib/src/danbooru/types/post_dto.dart`; `lib/boorus/danbooru/posts/post/src/converter.dart`. Post DTO includes ID, rating, `file_size`, `image_width/height`, `file_ext`, `created_at`, `uploader_id`, `fav_count`, `score`. Existing uploader view resolves user via `danbooruCreatorProvider` (`posts/details/src/widgets/danbooru_file_details.dart`).

**Gaps:** Absent rating is incorrectly defaulted to sensitive (`dto.rating ?? 's'`); format defaults to fabricated `jpg`; missing counts and size collapse to zero. Comment count is fetched separately using `danbooruCommentCountProvider` but `DanbooruPostStatsTile` renders 0 while pending/error. Danbooru post JSON has `last_commented_at`, **not** a generic total comment count. The existing artist commentary section is **not** a post description and should remain distinct. Preserve existing uploader and comment-count fetch caching.

### 3.2 Gelbooru 0.2.5

**Host:** gelbooru.com.

**Source:** `packages/booru_clients/lib/src/gelbooru/types/post_dto.dart`; `lib/boorus/gelbooru/posts/parser.dart`.

**Present:** ID, rating, original dimensions, original URL/format candidate, upload date, owner/uploader, score; DTO already parses `comment_count` and `title`.

**Gaps:** `fileSize: 0` hard-coded; numeric `comment_count` is discarded in favor of a boolean. No verified favorite count/description field in current DTO; `title` is not automatically a description. Confirm original format against actual original URL/MIME and any site-specific accessible detail API. Add stats selectively once provenance is known.

### 3.3 Gelbooru 0.1.x

**Host:** illusioncards.booru.org.

**Source:** `packages/booru_clients/lib/src/gelbooru_v1/post_v1_dto.dart`; `lib/boorus/gelbooru_v1/posts/parser.dart`.

**Present:** Thumbnail HTML yields ID, tags, optional rating and score. File URL is currently generated by string substitution; format comes from that inferred URL.

**Gaps:** Original bytes, dimensions, date, uploader, favorites, comment count and description are not available in the **current thumbnail DTO**. Do not assert an inferred thumbnail-derived URL is an authenticated original or invent missing values. Investigate a reliable individual-post HTML endpoint *on open only*; if unavailable, hide respective rows.

### 3.4 Gelbooru 0.2 and site overrides

**Hosts:** rule34.xxx, hypnohub.net, realbooru.com, bbooru.com, xbooru.com, tbib.org, safebooru.org.

**Source:** `packages/booru_clients/lib/src/gelbooru_v2/post_v2_dto.dart`, `parsers/{gel_parsers.dart,r34_parsers.dart,rb_parsers.dart}`; `lib/boorus/gelbooru_v2/posts/{parser.dart,full_post_loader.dart,providers.dart}`.

**Present:** Common JSON/XML DTO includes ID, rating, dimensions, dates, owner, score and **`comment_count` already parsed**. Conversion discards the numeric comment count and sets `fileSize: 0`. Site API and HTML capabilities differ materially.

**Host verification checkpoints:** Rule34 has separate API host/overrides for posts and post details and HTML comment behavior; Safebooru uses XML posts; HypnoHub uses HTML details; **Realbooru** has thumbnail-only HTML listings and a single-post HTML parser. Validate rule34, safebooru.org, hypnohub.net and realbooru independently, then remaining listed hosts; no blanket assumption that one host's API fields exist elsewhere.

**Realbooru known gap:** `parseRbPostHtml` reads `#image`/video player source and calls it both sample and original, and does not capture original resolution/bytes; #76 owns that media-original fix. It extracts an upload-like `change` field which is currently **not mapped to `createdAt`**, and often omits rating. Reuse #76 results and validate whether its timestamp is actually an upload time. **Preserve** `GelbooruV2FullPostLoader`: only the opened unresolved post triggers detail fetching; thumbnail metadata does not justify bulk original requests.

### 3.5 Moebooru

**Hosts:** konachan.com, konachan.net, yande.re, sakugabooru.com.

**Source:** `packages/booru_clients/lib/src/moebooru/types/post_dto.dart`; `lib/boorus/moebooru/posts/parser.dart`.

**Present:** ID, rating, `file_size`, original dimensions, upload epoch, author/uploader, score and original file URL; DTO has `file_ext`, separate JPEG/sample bytes/dimensions and `last_commented_at`.

**Gaps:** Parser derives format from URL instead of using explicit `file_ext`; no reliable numeric favorite/comment count in existing post DTO. An existing authenticated favorites-user loader (`lib/boorus/moebooru/post_details/src/favorite_loader.dart`) operates **on open**; do not claim a total unless its result is complete and the site/auth allows it. Last-comment timestamp is not comment count. No post description field found in inspected DTO.

### 3.6 e621

**Hosts:** e621.net, e926.net.

**Source:** `packages/booru_clients/lib/src/e621/types/post_dto.dart`; `lib/boorus/e621/posts/{parser.dart,post_data.dart,widgets.dart}`.

**Present:** All baseline fields except comment count already reach common/typed Post in some form: original file size/dimensions/ext, date, uploader, rating, favorite count, score, description. **`comment_count` is parsed by the DTO but dropped** at conversion.

**Gaps:** Make comment count persistent/displayable and add stats for known score/faves/comments; retain and show description without mistaking it for artist biography (currently rendered in an `ArtistSection` commentary component). Preserve rich categorized tags, source URLs and video alternates. Do not confuse downloaded/transcoded video sample size with original bytes. Null vs zero lost in existing `E621PostData` int/string fallbacks.

### 3.7 Philomena

**Hosts:** derpibooru.org, ponybooru.org.

**Source:** `packages/booru_clients/lib/src/philomena/types/image_dto.dart`; `lib/boorus/philomena/posts/{parser.dart,post_data.dart,widgets.dart}`.

**Present:** ID, original bytes, dimensions, format, upload date, uploader, faves, score, comment count, description already map through Post/typed data. Stats and description sections exist.

**Gaps:** `rating: Rating.general` is **hard-coded** although the inspected image DTO does not expose a universal content rating field. Do not treat score/stars as a safety rating; establish a site-specific trustworthy content-rating mapping, otherwise hide Rating. Stats currently substitute 0 on missing data and description fallback hides source-null distinction. Verify whether width/height/size are original or representation-specific on each host.

### 3.8 Sankaku

**Hosts:** chan.sankakucomplex.com, beta.sankakucomplex.com, sankakucomplex.com, sankaku.app, idol.sankakucomplex.com, www.idolcomplex.com, idolcomplex.com.

**Source:** `packages/booru_clients/lib/src/sankaku/types/post_dto.dart`; `lib/boorus/sankaku/posts/{parser.dart,post_data.dart,widgets.dart}`.

**Present:** Rating, original bytes/dimensions, media type, upload epoch, uploader name, favorite count, score; DTO provides **`comment_count`**, currently discarded. Some source IDs are **strings**: parser synthesizes `Post.id` but keeps genuine ID in `SankakuPostData.sitePostId`.

**Gaps:** Details ID tile must render/copy `post.sitePostId`, never synthetic `post.id`. Carry verified comment count and display known stats. Avoid displaying `uploaderId: 0` as a valid user ID; author identity can be string. Check restrictions/rate limits/response variability by host and account; do not assume Channel and Idol URLs share semantics or public visibility.

### 3.9 Szurubooru

**Host:** User-configured/self-hosted.

**Source:** `packages/booru_clients/lib/src/szurubooru/types/post_dto.dart` and [Szurubooru API](https://github.com/rr-/szurubooru/blob/master/doc/API.md); `lib/boorus/szurubooru/posts/{parser.dart,post_data.dart,post_codec.dart,widgets.dart}`.

**Present:** ID, safety rating, bytes, original canvas dimensions, created date, uploader, favorites, score, comments all available in post JSON and mapped; statistics UI already exists.

**Gaps:** Format currently derived from content URL extension, although DTO exposes `mimeType` and `type`. Preserve nullable numeric availability from source into UI/typed codec; currently all missing counts turn into zero. No baseline post description is established; do not borrow pool description or note text.

### 3.10 Shimmie2

**Host:** rule34.paheal.net (site-specific extensions); other user-hosted installations may vary.

**Source:** `packages/booru_clients/lib/src/shimmie2/types/post_dto.dart`; `lib/boorus/shimmie2/posts/{parser.dart,post_data.dart,widgets.dart}`.

**Present:** XML path can provide ID, dimensions, rating, date, uploader, score; optional GraphQL path provides filesize, format/MIME, `favorites`, `numeric_score`, a comments list, `title`, `tooltip`, votes and other extension fields. Typed data stores favorites/comments; no statistics UI presently.

**Gaps:** Preserve numeric favorites and score, display counts only when a GraphQL field actually exists. Count `comments.length` **only if the response is explicitly complete**, not merely a partial embedded comments list. `title` and `tooltip` are not an automatic post description; decide from real host fixtures. Treat plain XML and extension-rich GraphQL as separate capability paths; no forced GraphQL request for unsupported installations.

### 3.11 Pixiv (experimental)

**Host:** pixiv.net (authenticated, limited integration; see #59).

**Source:** `packages/booru_clients/lib/src/pixiv/types/pixiv_illust_dto.dart`; `lib/boorus/pixiv/posts/{parser.dart,post_data.dart,widgets.dart}` and `pixiv_builder.dart`.

**Present:** Genuine work/illustration ID, rating synthesized cautiously from `x_restrict` and `sanity_level`, original URL/format, artwork creation date, artist/uploader identity, `total_bookmarks`, `total_view`, **caption/title in DTO**. App creates **synthetic per-page `Post.id`**; genuine work ID is available through `PixivPostData.sitePostId`.

**Gaps:** Display genuine work ID (possibly page index separately), never synthetic ID. Caption/title are discarded and absent from details. `total_bookmarks` is retained but currently not displayed and **must be labelled Bookmarks, not silently reinterpreted as Favorites**; decision required before adding it to the baseline favorites slot. `score: 0` is invented, not a vote score; hide. Original byte size is absent in inspected DTO; do not download original to measure. Top-level width/height can describe the artwork but **per-page fidelity for multi-page works is unverified**; do not display as verified original page dimensions without evidence. The current DTO has no comment count (third-party Pixiv schemas mention it; verify endpoint/account and avoid guesses). Preserve multi-page, ugoira, restricted placeholders and bookmark identity behavior.

### 3.12 Anime Pictures

**Host:** anime-pictures.net.

**Source:** `packages/booru_clients/lib/src/anime-pictures/types/post_dto.dart`; `lib/boorus/anime-pictures/posts/{parser.dart,providers.dart,post_data.dart}`; `anime_pictures_builder.dart`.

**Present:** ID, erotics-level content rating, bytes/dimensions, `ext`, publication date, numeric score, uploader ID. **`PostDetailsDto`** also contains uploader user and a distinct `file_url`; site DTO has download count and further extras.

**Gaps:** Current post parser assigns `bigPreview` as `originalImageUrl` and `uploaderName: null`. The app already has `getPostDetails` and `postDetailsProvider`; reuse/cache that request **for the opened post only** to resolve real original URL and uploader name. Do not display source bytes/dimensions as confirmed original until matched to that resource. No verified favorites total, comment total or post description from currently inspected fields; do not count `favoritesUsers` without proof of completeness. Avoid scope creep into #57 quality behavior.

### 3.13 e-shuushuu

**Host:** e-shuushuu.net.

**Source:** `packages/booru_clients/lib/src/eshuushuu/types/post_dto.dart`; `lib/boorus/eshuushuu/posts/{parser.dart,post_data.dart}`; `eshuushuu_builder.dart`.

**Present:** ID, original size/dimensions/ext, date, uploader, numeric `favorites`, `bayesian_rating`, `caption` (DTO), optional `posts`, user rating and links.

**Confirmed semantic bugs:** Parser hardcodes `Rating.general` without an actual content rating; DTO `rating` and `bayesian_rating` are **user score aggregates**, not NSFW classification. Parser assigns `score: e.favorites ?? 0` and treats `e.posts` as whether comments exist; neither is a verified score/comment count mapping. Preserve Favorites as its own count, treat Score as unknown pending discovery, and make the caption available as description after confirming it is artwork text. Never present `posts` as exact comments without site/API proof.

### 3.14 HyBooru

**Host:** booru.funmaker.moe.

**Source:** `packages/booru_clients/lib/src/hybooru/types/{post_summary_dto.dart,post_dto.dart}`; `lib/boorus/hybooru/posts/{parser.dart,providers.dart}`.

**Present:** Listing summary carries ID, dimensions, extension and date but not full metadata. Single-post DTO has content `rating`, bytes, dims, extension, post date, sources, notes and relations; repo already supplies single-post fetch (`getPost`).

**Gaps:** Summary parser hardcodes General, score zero; full parser maps null rating to General and score zero. Do not imply a rating from a missing summary or assign fabricated score. Reuse existing single-post fetch on opening an unresolved post; do not fire it for every grid tile. No uploader/favorite/comment/description established in current DTO.

### 3.15 Hydrus

**Host:** Local/self-hosted Hydrus Client API; NOT a public booru with upload/community votes.

**Source:** `packages/booru_clients/lib/src/hydrus/types/file_dto.dart`; `lib/boorus/hydrus/posts/parser.dart`; [Hydrus Client API](https://hydrusnetwork.github.io/hydrus/developer_api.html).

**Present:** Local `file_id`, original bytes/dimensions/extension, duration, service tags, known URLs, local favorite boolean, `time_modified`, `file_services` import times, service-specific ratings. Current parser hardcodes `Rating.general`, `score=0`, and `createdAt=null`.

**Decision:** Hide unprovided content rating, public score, uploader, favorite count, comment count, description, and **Upload date**. Do not mislabel local import/modified time as public upload time. A separately named **Imported** or **Modified** field may be proposed but needs its own approval. Preserve Hydrus private keys/service data and never expose authentication material or mix local favorites with public favorites.

### 3.16 Nozomi.la

**Host:** nozomi.la.

**Source:** `packages/booru_clients/lib/src/nozomi/types/{post_dto.dart,media_dto.dart}`; `lib/boorus/nozomi/posts/parser.dart`.

**Present:** Post ID, media URL/type, per-media or post dimensions, extension from URL, date, categorized tags. Rating is already `unknown`.

**Gaps:** Byte size, uploader, aggregate favorites, score, comments, post description are not present in the inspected DTO; parser nevertheless writes `score: 0` and `fileSize: 0`. Hide these. Multiple media can belong to one Nozomi post: only claim per-media original dimensions/format when the selected media matches.

### 3.17 Zerochan

**Hosts:** zerochan.net, kpop.asiachan.com.

**Source:** `packages/booru_clients/lib/src/zerochan/types/post_dto.dart`; `lib/boorus/zerochan/posts/parser.dart`.

**Present:** ID, dimensions, optional size, multiple media URLs, and source/tags. URL extensions supply tentative format.

**Gaps:** Parser **hardcodes General rating and zero score**, upload date and uploader are unavailable in inspected DTO, and no favorite/comment/description counts are represented. Original URLs can be **inferred from thumbnail strings**; do not assert original-only metadata based on unverified URL rewriting. Verify both hosts independently, preserve fallback playback and the original download behavior.

## 4. Host-level validation matrix

The registered-host list below comes from the pinned `boorus.yaml`, **not** an assertion that every host was live-tested. For each family, capture one representative actual listing and detail response (and optionally restricted/login state), noting API type, HTTP status and which of the eleven fields are reliably present. Store sanitized, deterministic **small fixtures** only; no cookies, tokens, private posts or user data.

| Engine | Registered sites and mandatory variations |
| --- | --- |
| Danbooru | danbooru.donmai.us; donmai.moe; safebooru.donmai.us; aibooru.online; testbooru.donmai.us — permissions/content restrictions |
| Gelbooru | gelbooru.com — API JSON, auth/API-key permission |
| Gelbooru v1 | illusioncards.booru.org — thumbnail vs full HTML |
| Gelbooru v2 | rule34.xxx (API host); hypnohub.net (HTML details); realbooru.com (HTML list/details); bbooru.com; xbooru.com; tbib.org; safebooru.org (XML); differing site auth/pagination |
| Moebooru | konachan.com; konachan.net; yande.re; sakugabooru.com — version/favorite-support flags |
| e621 | e621.net; e926.net — site content/permissions |
| Zerochan | zerochan.net; kpop.asiachan.com — inferred-vs-confirmed full media |
| Sankaku | chan.sankakucomplex.com; beta.sankakucomplex.com; sankakucomplex.com; sankaku.app; idol.sankakucomplex.com; www.idolcomplex.com; idolcomplex.com — endpoint/rating/ID variation |
| Philomena | derpibooru.org; ponybooru.org — content rating policy |
| Shimmie2 | rule34.paheal.net; optional extension path and plain XML |
| Szurubooru | User-supplied instances; version/auth capability detection |
| Hydrus | User-supplied Client API; permission and service types |
| Anime Pictures | anime-pictures.net; list vs detailed API |
| HyBooru | booru.funmaker.moe; summary vs full record |
| e-shuushuu | e-shuushuu.net; distinguish stars/faves/posts/caption |
| Nozomi | nozomi.la; image and video/multimedia |
| Pixiv | pixiv.net; authorization, multi-page, restricted works |

Do not expand this issue into unknown/unregistered hosts without evidence; make parsing robust for user-configured compatible hosts.

## 5. Proposed implementation sequence for the next agent

**Phase A — evidence and contract**

1. Read current `AGENTS.md`, `docs/issue_workflow.md`, this specification, `docs/post_architecture.md`, the current Issue #77 and related #76. Confirm task ownership/branch and the *latest* develop baseline; this research is pinned to the SHA above.
2. Create fixture-based per-engine checks of **raw absent**, **source-confirmed 0**, **source-confirmed positive**, **malformed value**, **partial listing**, **complete detail**, and where appropriate **restricted/auth response**. Test HTML and XML variants independently. Mark genuinely unavailable fields unknown, not pending implementation indefinitely.
3. Implement one consistent presentation availability contract before mapping all engines. Prefer a small optional common value object and use typed data only for genuinely engine-specific semantics. Avoid a second Post type, extra global caches, and parallel controller hierarchy.

**Phase B — shared data and details UI**

4. Route verifiable raw values into the new nullable contract without breaking existing numerical media/ordering getters. Keep `Post.sitePostId` as the source-visible ID. Normalize format/MIME and map ratings only from content-rating evidence.
5. Update common file details rows and summary so unknown ID/rating/size/resolution/format/date/uploader are completely absent; no stray delimiters, empty container or fake 0. Refactor statistics so each metric is optional and an empty statistics section vanishes. Ensure loading/errors do not flash 0.
6. Preserve provenance through `StoredPostCodec` common version evolution and engine codecs. Version and test any changed encoded structures. Existing bookmarks, favorite/snapshot/recovery flows and Following must still decode; unknown/custom payload handling remains graceful.
7. Render post descriptions only when supplied by the original source, with empty/missing text hidden and safe/engine-appropriate formatting; no untrusted inline HTML injection or code execution. Keep existing artist commentary separate.

**Phase C — engine updates, with concrete priorities**

8. **High-value no-extra-request**: e621 `comment_count` + full stats/description; Gelbooru/Gelbooru v2 `comment_count`; Sankaku `comment_count` and ID; Philomena/Szurubooru nullable counts/ratings; Pixiv caption and genuine ID (do not mislabel bookmarks); e-shuushuu score-vs-favorites/rating correction; fix fabricated missing ratings/scores in HyBooru/Hydrus/Zerochan; use Moebooru `file_ext`; use Szurubooru MIME.
9. **Detail-only enrichment**: Anime Pictures existing `getPostDetails` for original media/uploader; HyBooru full post for summary-only entries; current Realbooru full-post loader; Danbooru uploader and comments existing providers. Coordinate #76 rather than duplicating its Realbooru original URL/size work.
10. **Source-limited cases**: Gelbooru v1 thumbnail HTML, Moebooru favorite/comment totals, Shimmie GraphQL extension, Nozomi, Zerochan, Pixiv byte size/comments. Add fields only where reliable and low-cost. Avoid HEAD/GET media probes solely to populate original bytes on every post; validate permission, redirects and caching before proposing a single-post on-demand probe.

**Phase D — verification and completion**

11. Test all eleven fields across supported engines and meaningful host variants; assert **not displayed when unknown**, **0 displayed when explicitly known**, and correct source ID. Verify the collapsed file summary and stats sections as well as expanded tiles.
12. Test snapshot v1 migration/round-trip, new versions, unknown post data, failed detail recovery, mixed-engine bookmarks, Following, favorites, downloads, original URL/quality and navigation; verify no extra metadata requests for grids or prefetch.
13. Run scope-appropriate analysis/tests and the complete final integration suite per `AGENTS.md` before proposing integration. Device smoke-check narrow screens and title/description overflow. Distinguish static source checks, automated tests, emulator/manual results and unverified host endpoints in report.

### Request/caching policy

- Prefer data already delivered with search/listing API response.
- Only fetch additional data after the user opens the post, and only when missing/valuable and the site supports it. Reuse existing providers and detail response where possible.
- Key caches by actual **engine + normalized host + appropriate auth/profile identity + genuine post/page identity**. Keep credentials isolated and avoid applying a result to a different profile or a stale post after swipes.
- Coalesce in-flight requests, bound concurrency, cache positive/negative outcomes sensibly, handle offline/timeouts, and cancel/discard obsolete results. Do not fetch original media bytes just to measure length.
- Add tests counting outgoing requests for listing 50/100 posts vs opening 1 post; no per-post N+1 calls during scrolling, prefetch or bookmark-grid restore.
- Do not hide existing functionality (tag categorization, original download resolver, media variants, notes, parent/child/pools, favorites). Preserve site-specific permissions and privacy.

## 6. Non-Danbooru metadata — explicitly pending individual decisions

This is a **decision catalog**, not an instruction to implement every extra. All candidates below are present in inspected clients or existing typed data unless otherwise noted. Record approval/rejection and labeling for **each concept** before changing user-visible details.

| Source / extra | Recommended disposition (NOT approved) | Reason |
| --- | --- | --- |
| Pixiv artwork title + caption | Caption as baseline Description; separate optional Title candidate | Do not combine title and body silently |
| Pixiv total bookmarks, total views | Keep Bookmarks distinct from Favorites; Views optional | Neither is a vote Score; metric names must remain truthful |
| Pixiv series, page index/count, AI type, drawing tools, ugoira | Keep supported internal data; no new tile until UX decision | Artworks may have multiple pages and specialized media |
| e621 species/lore/invalid tags, source list | Retain existing engine-specific tags/URLs | Not universal metadata fields |
| e621 video codecs, FPS and size of alternates | Retain existing media resolution data; optional media-info view | Different from original size |
| Philomena Wilson score, first seen, spoiler/deletion state, up/down votes | Document; optional separately | First-seen is not Upload date; Wilson is not general Score |
| Sankaku recommended score/posts, vote count, premium gate, author avatar | Document; defer UI pending benefit/privacy checks | Not equivalent to baseline counts |
| Shimmie2 title, tooltip, extension votes, approved/locked/private states | Preserve in typed payload; validate scope first | Extensions and moderation are site-specific |
| Szurubooru notes, pools, feature count, custom thumbnail | Keep existing presentation; extra stats require approval | A pool description is not post Description |
| Moebooru sample/JPEG dimensions and sizes, approver/lock/frames | Keep media variant metadata; optional media details later | Avoid confusing original vs derivative renditions |
| Anime Pictures downloads, stars/float rating, tag count, color, moderator | Document; optional independently | Downloads and stars do not substitute favorites/content rating |
| e-shuushuu caption, Bayesian/user rating, original filename, avatar | Caption as baseline Description if genuine; other data optional | Star/Bayesian scores are not safety rating |
| Hydrus import/modified dates, user-defined ratings, file states, frame/EXIF/ICC | Separate **Imported/Modified** option only after approval | Local file metadata is not public upload/vote data |
| Nozomi per-post multiple media and tags | Retain existing media/tag metadata; optional grouped media information | Do not force every site into one file representation |
| Danbooru artist commentary, approver, up/down scores | Preserve existing sections; no forced generic Description | Not post-authored body text |

**Acceptance rule for extras:** Any new shared or engine-specific metadata requires a separately documented decision about identity/semantics, availability, UI wording, user value, request cost, privacy, persistence and tests. This ticket does **not** authorize displaying all extras by default.

## 7. Regression and fixture checklist

Suggested existing coverage to extend (all paths relative to repository root):

- `test/core/posts/post/stored_post_codec_test.dart`
- `test/boorus/posts/{interaction_post_codec_contract_test.dart,low_variance_post_codec_contract_test.dart,rich_post_codec_contract_test.dart}`
- `test/core/posts/details/file_details_upload_date_test.dart`
- `test/core/posts/details/{post_fallback_presentation_test.dart,post_presentation_context_test.dart,single_post_details_provider_test.dart,mixed_post_details_page_test.dart}`
- `test/core/search/following_topics/{feed_post_snapshot_test.dart,pixiv_cached_details_test.dart,pixiv_search_pagination_test.dart}`
- `test/boorus/gelbooru_v2/{realbooru_full_post_loader_test.dart,realbooru_original_image_test.dart,rule34_api_post_recovery_test.dart,website_capability_lookup_test.dart}`
- `packages/booru_clients/test/pixiv/pixiv_illust_dto_test.dart`
- New parser/DTO fixtures for each of the other families and XML/HTML variants where no current direct test exists.

**Cases to test explicitly:**

- Parsed field absent vs JSON null vs explicit 0 vs positive; fields missing in partial listing but present in full detail; no misleading 0 on asynchronous fetch before completion or on error.
- Rating source missing/invalid never silently becomes General or Sensitive. Stars/Bayesian/Pixiv bookmarks/Hydrus boolean favorites never leak into wrong baseline slot.
- Site ID for Sankaku **string** and Pixiv **multi-page** is stable and copied exactly, not synthesized grid key.
- Original metadata describes original rendition (not sampled/transcoded thumbnail), and still displays correctly when media blocked/restricted/removed without attempting an unauthenticated fallback.
- Old snapshot v1, current snapshot, engine custom schema versions, unknown typed payload, migrated bookmarks/followed posts and mixed-origin detail page all remain usable.
- Posting/metadata from one profile cannot appear on another website/profile after a swipe, cache hit, authentication change or offline recovery.
- Numeric 0 is visible for score/favorites/comments when and only when the service explicitly returned it.
- UI remains compact and localized (`context.t`), no invalid separators/blank panels, correct long descriptions/uploader names/large text/narrow screens.

## 8. Open evidence and implementation ownership

**Research completed here:** Registry and officially listed sites, 17 engine parsers, major client DTO models, detail builders, current shared Post/snapshot/UI architecture, existing provider behavior in key engines, and public API reference documentation for Danbooru/Szurubooru/Hydrus plus supplemental Pixiv/e621 schema references.

**Not verified:** Live site/credential-dependent API payloads, every site-specific HTML layout, final count endpoints for hosts lacking raw totals, response caching headers/rate limits, Flutter analyzer/tests/emulator or device UI. Static DTO field support **must not be reported as live confirmed support**. Site probes/fixtures in Phase A are the first implementation-agent gate.

**Related task boundaries:** [#76 Realbooru original image metadata](https://github.com/timberpile/Boorusama/issues/76) owns original URL/dimensions/size extraction for Realbooru; reuse/integrate, do not duplicate. [#71 Improve search options and tag input](https://github.com/timberpile/Boorusama/issues/71) owns **query metatag syntax**, not post metadata. [#59 Mark Pixiv as experimental](https://github.com/timberpile/Boorusama/issues/59) defines Pixiv's maturity/UX label, not permission to misrepresent unsupported metadata.

**Reference material:**

- [Danbooru post API field definitions](https://safebooru.donmai.us/wiki_pages/api%3Aposts)
- [Szurubooru API documentation](https://github.com/rr-/szurubooru/blob/master/doc/API.md)
- [Hydrus Client API field and time semantics](https://hydrusnetwork.github.io/hydrus/developer_api.html)
- [e621 OpenAPI third-party schema](https://github.com/anthrove/openapi-e621-go/blob/main/docs/Post.md) — cross-check against actual host responses
- [Unofficial Pixiv App API observations](https://gist.github.com/ZipFile/3ba99b47162c23f8aea5d5942bb557b1) — not contractual documentation
- Local first-party implementation source: the pinned `develop` commit and `packages/booru_clients/boorus.yaml`.

**Success:** A post's Details shows exactly the available meaningful baseline fields for its **originating** source; missing values are omitted; known zero counts are retained; no invented classifications or reused unrelated metrics; website-specific behavior and current data remain intact; fetching stays bounded; additional metadata has documented explicit decisions rather than surprise UI additions.


## 9. Nullable Model Migration: Impact and Cost

**Status:** Additional static architectural assessment for #77; effort estimates are *rough engineering-day ranges*, **not** measured implementation durations. No compiler, test suite or dependency-wide automated reference count was run for this estimate. Effort below addresses nullable model/data/presentation work **separately** from external website investigation, account setup, site-specific HTML scraping and #76.

### 9.1 What is actually non-nullable today?

\`PostCoreData\`, \`PostRecord\`, \`Post\` and the shared mixins have a non-null legacy/operational API. This is a different problem from the nullable raw HTTP DTOs:

| Property / current contract | What "unknown" looks like today | Should the canonical source value be nullable? | Impact of changing the *public* \`Post\` getter |
| --- | --- | --- | --- |
| \`fileSize: int\` | API null becomes 0 in numerous parsers | **Yes** for proven original bytes; an explicit valid source 0 must not be confused with missing | **Medium.** Viewer preload estimates, media metadata/preview, share descriptions and details tiles expect numbers |
| \`score: int\` | API null becomes 0, sometimes metrics are wrongly substituted | **Yes**; 0 is an ordinary valid score | **Medium.** Grid overlays, tag filters (\`TagFilterData.score\`), sort/metrics and statistics consumers |
| \`width/height: double\` | 0 or even artificial 1; may describe artwork rather than actual selected original rendition | **Yes** for *verified original* dimensions; preserve separate **usable display geometry** | **High.** \`ImageInfoMixin.aspectRatio/mpixels\`, viewer \`Size(post.width, post.height)\`, note coordinate adjustment, progressive images and media aspect ratios |
| \`format: String\` | Empty string, artificial \`jpg\`, or an extension inferred from the wrong rendition | **Yes** for *verified original format* | **High.** \`MediaInfoMixin.isVideo/isAnimated\`, \`VideoInfoMixin\`, grid media, download filename extension tokens and sharing policy |
| \`duration: double\` | Often \`kNoduration = -1.0\`, sometimes 0 | Arguably yes, **outside the eleven baseline fields**; existing sentinel is intentional compatibility behavior | **Medium.** Animation/video controls and record interfaces; defer until separately justified |
| \`hasComment: bool\` | Absence becomes \`false\` | Arguably tri-state (\`bool?\`) when the backend exposes only presence, **not a count** | **Medium.** Existing comment badge/availability logic; do not change to solve \`commentCount\` |
| \`hasParentOrChildren\`, \`isTranslated: bool\` | \`false\` also means not supplied | Potentially, but not needed for #77 | **Medium.** Features use these as operational capabilities; changing them affects behavior |
| \`md5: String\`, media URLs and \`tags: Set<String>\` | \`''\` or an empty collection | Conceptually optional source facts, but actively used as media/identity/navigation inputs | **High/risky.** Avoid a blanket nullable migration under #77 |
| \`id: int\` | 0 placeholder or synthetic numeric application ID | **Do not** make the runtime ID nullable; \`post.sitePostId: String?\` already expresses a genuine source ID | **Very high.** Equality, pagination, grid keys, bookmarks, links and caching rely on a stable ID |
| \`rating: Rating\` | Enum has \`Rating.unknown\` | **No**: existing explicit unknown state is sufficient | **Low** if the rendering/parsers are corrected; a nullable enum adds a redundant absence state |
| \`createdAt: DateTime?\`, \`uploaderName: String?\`, \`uploaderId: int?\`, \`hasSound: bool?\` | Already nullable | **No structural migration required** | Existing UI/parser fixes only |
| \`favoriteCount\`, \`commentCount\`, \`description\` | Not in common \`PostCoreData\`; some values exist as required fields inside typed engine payloads with \`?? 0\` or \`?? ''\` | **Yes** as an optional normalized details contract, preserving per-engine meaning | **Low-to-medium** if the new getters are added rather than changing all existing consumers |

**Important source distinction:** Existing \`post.width/height\`, \`post.format\` and \`post.fileSize\` are also used to manage/play/render media. Even making them nullable would **not** prove they refer to the **original file**. A missing original size must not turn a known preview size into an original size. The source fact's *provenance* is as important as its nullability.

### 9.2 Confirmed coupling: concrete code points

| Current code | Current assumption and nullable consequence |
| --- | --- |
| \`lib/core/posts/post/src/mixins/image_info_mixin.dart\` | \`width <= 0\`, \`height <= 0\`, \`width / height\`, \`width * height\` are defined on non-null doubles; a direct \`double?\` migration requires changes to both public mixin API and every arithmetic caller |
| \`lib/core/posts/details/src/widgets/post_details_page_scaffold.dart\` | \`Size(post.width, post.height)\` feeds Auto Comic/viewer geometry; accepting null directly is impossible and selecting a fallback needs validation |
| \`lib/core/posts/details/src/widgets/post_details_image.dart\` | Note-coordinate adjustment reads width and height; wrong/unknown geometry must not silently misplace annotations |
| \`lib/core/posts/post/src/mixins/{media_info_mixin.dart,video_info_mixin.dart}\` | Media/video/GIF classification assumes a non-null operational format (though low-level \`isFormatVideo\` accepts null) |
| \`lib/core/downloads/filename/types/generator_impl.dart\` | \`post.format.startsWith\`, file extension fallback, width/height filename tokens; changing types may affect persisted user filename rules and download outcomes |
| \`lib/core/posts/details/src/widgets/post_details_image_preloader.dart\` | \`estimatedSizeBytes: post.fileSize\` is passed into prefetch planning; a nullable public size requires an explicit estimation fallback |
| \`lib/core/posts/details/src/widgets/post_media.dart\` | Video/media component uses \`post.fileSize > 0 ? post.fileSize : null\` |
| \`lib/core/posts/listing/src/widgets/post_grid_item.dart\` | Grid score overlay uses \`post.score\` |
| \`lib/core/posts/filter/src/types/score_type.dart\` and \`.../filter/src/tag_filter_data.dart\` | Score is a required int for filter evaluation; making unknown scores fail or pass a comparison is a **behavior decision**, not a mechanical type change |
| \`lib/core/posts/shares/src/share_media_description.dart\` | Original media description uses numeric dimensions/size and string format operations; a nullable source-only value is preferable to breaking the operational model |
| \`lib/core/posts/details_parts/src/file_details/file_details_section.dart\` | Existing \`> 0\` and \`format\`/rating/ID rows hide valid zeros or show fabricated unknowns; the collapsed subtitle needs the same verified-presence handling |
| \`lib/core/posts/details_parts/src/simple_post_stats_tile.dart\` | Three required integers render three rows unconditionally; introduce nullable metric inputs and omit unavailable metrics/empty container |
| \`lib/core/posts/post/src/data/stored_post_codec.dart\` | \`commonSchemaVersion = 1\`; decoder requires non-null \`width\`, \`height\`, \`format\`, \`fileSize\` and \`score\`; a type-only schema edit breaks persisted posts |
| \`lib/core/posts/post/src/types/post_record.dart\` | Engine record interface requires non-null width/height/format/fileSize/score; directly changing it affects all **17** engine families and record constructors/codecs |

**Tests directly connected to this contract:** \`test/core/posts/post/stored_post_codec_test.dart\`, \`test/boorus/posts/{rich_post_codec_contract_test.dart,low_variance_post_codec_contract_test.dart,interaction_post_codec_contract_test.dart}\`, \`test/core/posts/details/file_details_upload_date_test.dart\`, \`test/core/posts/details/mixed_post_details_page_test.dart\`, \`test/core/posts/details/post_presentation_context_test.dart\`, and \`test/core/posts/shares/share_sheet_media_description_test.dart\`. The test fixtures construct \`PostCoreData\` with required numeric/format defaults; update tests to check real missing values rather than blindly replacing all zeros.

### 9.3 Three implementation strategies

**Option A — Full direct nullable migration (not recommended for this issue)**

Change \`PostCoreData\`, \`PostRecord\`, all engine record classes, \`Post\` getters and affected mixins to \`int?\`/\`double?\`/\`String?\` for all unknown-capable fields, then fix every call site. Version snapshots and engine codecs, introduce per-feature fallbacks, and review changed sorting, metadata, downloads, note positioning and video detection. This is a broad refactor cutting across the 17 parsers, both common and engine-specific persistence, tests and additional unrelated consumers.

Advantages:
- Clear, single source of truth for absent values throughout the *public* API.
- Type system forces consumers to explicitly handle uncertainty; fewer hidden sentinels and fewer duplicate fields.
- Easier future extension of arbitrary metadata if the entire system adopts nullable semantics.

Disadvantages:
- Broad compile-time churn, large regression footprint and higher integration risk relative to the user-visible benefit.
- Replaces intentional fallback/operational values with optional values even where a usable default is necessary (geometry, grid sorting, video classification, filenames).
- No automatic guarantee of original-media provenance: a nullable \`width\` can still be a preview width.
- Older snapshots and \`PostRecord\` fixtures must remain valid; user-generated filenames/filters can behave differently.
- \`hasComment\`, \`id\`, tags and rating require different semantics; **"make everything nullable" is not a sound objective**.

**Option B — Canonical nullable source facts, backward-compatible operational getters (recommended)**

Make a **small, explicit, source-verified nullable metadata contract** accessible on the common \`Post\`/detail presentation while retaining the current non-null operational accessors. There are two implementable subvariants; choose one after inspecting all conversion points:

1. **Preferred when practical:** Store nullable canonical facts for existing common source attributes (e.g. known score/size) internally in \`PostCoreData\`. Keep compatibility getters such as \`Post.score => core.knownScore ?? 0\` and \`Post.fileSize => core.originalByteSize ?? 0\`, with separately named nullable detail accessors. Do **not** change \`PostRecord\` and the media mixins en masse. Propagate original DTO nullability through an explicit optional record capability or \`PostCoreData.fromPost\` conversion overrides. **Do not** call \`PostCoreData.fromPost(record)\` and silently treat its legacy zero defaults as known values.
2. **Lower-churn fallback:** Add one immutable optional \`PostDetailFacts\` value object to \`PostCoreData\`, with nullable original byte length/dimensions/format, score, count fields and description. Continue using the existing \`PostCoreData.width/height/format/fileSize/score\` as operational compatibility values. The decoder keeps old snapshots usable. Ensure the fact object is populated **from raw source responses**, not reconstructed from legacy fallback getters. Avoid duplicating known uploader/date/rating/ID values without a reason, and test that vote/detail refresh updates do not leave duplicated values inconsistent.

The design may combine these: retain existing operational geometry and media-format getter semantics, while storing **separate verified original-file geometry/format**; promote scalar nullable score/size internally only where that avoids unnecessary duplication.

Advantages:
- Accurately models missing vs zero **in UI and snapshots** without disrupting geometry, notes, preloader, filenames, grid filters or other runtime code.
- Smaller blast radius, incremental per-engine rollout, fewer incidental behavior changes; existing mixed-profile and offline behavior remains intact.
- Allows valid count 0, unknown field suppression, and original-vs-sample distinctions.
- Does not require fetching new metadata to initialize every grid item; \`null\` can stay unknown until optional detail resolution.

Disadvantages:
- More concepts in the codebase: source facts vs operational fallback getters. Names/docs must clearly communicate which is authoritative.
- Risk of duplicated score/size/format fields drifting apart when posts are replaced or a vote changes; avoid redundancy where possible and test update/recovery paths.
- A persisted old zero cannot be disambiguated automatically; old snapshots should conservatively mark the corresponding source fact *unknown* until valid refresh.
- Reviewers must verify all new parser mappings use raw DTO presence, not \`?? 0\` values from legacy \`PostRecord\`.

**Option C — UI-only sentinel checks (not acceptable as the final #77 fix)**

Continue using existing \`> 0\`, empty string and \`Rating.unknown\` checks, and patch individual engine-specific UI cases without any source-presence model. This can hide obviously invalid values quickly, but **cannot** distinguish a genuine zero score/favorite/comment count from a missing one, or verify that original metadata describes the original rendition. Use only for independent visual bugs, never as the acceptance strategy for all eleven fields.

### 9.4 Relative engineering cost (estimates, not measurements)

Assume one developer/agent familiar with the architecture, no unrelated refactors, already accessible test tooling, and source DTOs from the current code. The following estimates **exclude** site-by-site live verification, metadata discovery beyond current DTOs, #76, and complete release QA. Parallelism between phases and uncertain host behavior can change elapsed time.

| Workstream | Compatible nullable facts (Option B) | Full public nullable migration (Option A) |
| --- | --- | --- |
| Data contract and parser/record transport | ~1–3 engineering days | ~3–6 days across interfaces, mixins and engine records |
| Common snapshot versioning / legacy decoding | ~1–2 days | ~2–4 days with strict v1 compatibility |
| UI: file tiles, summary, independent stats, descriptions | ~1–2 days | ~1–3 days (plus extra consumers of now-null getters) |
| Mapping raw availability into existing engine converters | ~2–4 days | ~3–6 days (plus broad call-site adjustments) |
| Focused regression tests and review | ~2–4 days | ~5–9 days (geometry, filters, filenames, viewer, persisted state) |
| **Total, non-additive estimate** | **~6–12 developer-days (about 1–2.5 weeks)** | **~15–28 developer-days (about 3–6 weeks)** |

These are **not** promises, person-hour measurements, or a full #77 estimate. Workstreams overlap (e.g. parser mapping is already part of #77), so do not mechanically add the rows, and do not add the Option B total to the full issue estimate as if it were separate work. A broad \`flutter analyze\` may surface additional downstream callers not captured by static inspection.

**Specific risk/effort ranking if a full migration is considered separately:** \`score\` and \`fileSize\` are **medium**; \`format\` and particularly \`width/height\` are **high**; \`duration\` and \`hasComment\` are **medium but lower priority**; \`id\` and \`rating\` **should not migrate**. The image geometry group is the most behavior-sensitive because of zoom/pan, Auto Comic, notes and representation replacement.

### 9.5 Migration rules and verification gates

1. Define stable, precise semantics: **source-known = non-null**; invalid/ambiguous input = null; missing JSON key = null; source-confirmed count **0** remains 0. Original dimensions must be >0 to qualify; explicit byte count 0 remains distinguishable if the source genuinely provides it.
2. Keep **operational getters and site identities stable** during #77. \`Post.id\` stays internal and numeric; use \`Post.sitePostId\` for display and copy. \`Rating.unknown\` remains the absence value.
3. Introduce a versioned/backward-readable snapshot representation. The new decoder must read all supported old snapshots; old unknown zeros must **not** become falsely known. An engine codec upgrade is needed **only** when its encoded custom payload schema actually changes.
4. Preserve original-vs-thumbnail/sample meaning in every conversion and detail hydration. Keep page-specific Pixiv dimensions nullable until verified. No additional N+1 API calls.
5. Test pairs for **raw absent vs 0 vs positive**, **complete details vs listing**, malformed numbers/negative dimensions, old v1 snapshots, engine typed payloads, mixed origins, bookmark/following reopen, and on-demand detail replacement.
6. Check downstream gameplay/behavior explicitly: note overlay geometry, aspect ratio/progressive upgrade, video/GIF detection, preload budgeting, existing score/tag filters and grid badges, downloads/filename tokens and share metadata.
7. Consider wider public nullable type changes only after #77 has stabilized and a **separate scoped refactor** demonstrates a concrete benefit. Do not use this issue as a repository-wide type cleanup.

**Recommendation for #77:** Implement **Option B**. It meets the user-visible requirement (truthful availability + known zero + original-only metadata) with materially lower risk. Do **not** make all public \`Post\` getters nullable merely to render a sparse Details section. Record any discovered need for full public nullable conversion as an explicitly evaluated follow-up rather than an implicit prerequisite.
