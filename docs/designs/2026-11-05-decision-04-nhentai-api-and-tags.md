# Decision 4 — nhentai Feasibility, CDN and Tag Catalog

**Status:** Research and recommendation with a subsequent **user-run live WSL HTTP check on 2026-11-06**. Public API and two CDN HEAD requests succeeded in that environment; Android runtime, actual media GET, auth, rate limits, and broader reliability remain unverified.

## Live WSL results (user-supplied, 2026-11-06)

The user provided terminal results from a local WSL environment. These are direct evidence of requests that succeeded there, unlike the earlier third-party schema or blocked browsing-tool fetches:

| Read-only endpoint | Observation |
| --- | --- |
| `GET /api/v2/config` | HTTP 200 JSON; four image CDN hosts and four thumbnail hosts |
| `GET /api/v2/galleries?page=1&per_page=2` | HTTP 200; real summary objects with Gallery `id`, separate `media_id`, tag IDs and page counts |
| `GET /api/v2/cdn` | HTTP 200; same configured host families |
| `GET /api/v2/galleries/694482` | HTTP 200; 41 ordered Pages with source numbers **1–41** and concrete page/thumbnail paths |
| `GET /api/v2/tags/ids?ids=152` | HTTP 200; tag ID resolves with name/type |
| `GET /api/v2/tags/general` | HTTP 400; API rejects `general` as a type, accepts `tag` instead |
| `GET /api/v2/tags/tag?sort=popular&page=1&per_page=5` | HTTP 200; reported **4,774 total tags** and **40 pages**, but supplied JSON has **120 actual results** despite requesting `per_page=5` |
| `HEAD https://t1.nhentai.net/galleries/4301386/thumb.webp` | HTTP 200, `image/webp`, `content-length: 26226`, strong cache headers |
| `HEAD https://i1.nhentai.net/galleries/4301386/1.webp` | HTTP 200, `image/webp`, `content-length: 148402`, strong cache headers |

**New implementation implications:**

- Use the real tag type key `tag`, not `general`. Do not assume `per_page` is honored by the live endpoint; calculate progress from actual returned items and server-reported completion, and confirm page-2 continuity. The observed ~120/page explains 40 pages for 4,774 tags. Earlier examples assuming 100 tags/page or five pages = 500 tags were estimates, not measured operational contracts.
- Treat `Gallery.id`, `media_id`, and `PageInfo.number` as distinct fields. Preserve the original 1-based page number. Some returned `thumbnail` paths include `.webp.webp`; preserve source-supplied paths pending direct checks rather than rewriting file extensions.
- Respect the API-supplied CDN server list and validated paths. CDN HEAD success is useful but does **not** prove full GET decoding, image access across hosts, cache freshness, or Android compatibility.
- Anonymous API access worked from one network/time; do not infer rate limits, authenticated behavior, all categories' counts, search pagination, CORS, geographic reliability, or future uptime.
- Follow-ups: small paged tag requests (including page 2), bounded CDN GET/decode from the returned exact paths, search and Android Dio-stack probes. No credentials or anti-bot workarounds needed for these initial reads.

The original API-schema-based feasibility checklist below remains the next validation framework. Its speculative request counts and page-size assumptions must be revisited using these observations.

## One-minute explanation

A remote nhentai Gallery can use our shared **Content Group** model, with one **Post per actual image page**. The nhentai source still needs a dedicated HTTP adapter and media resolver. The UI is assembled from shared Kurumi group/viewer components; it need not be a different `Gallery` class from a Danbooru Pool just because the source calls it a Gallery.

**Platform scope:** Android first, desktop optional. Web/CORS need not block the initial native integration.

## Sources and evidence

The current public [third-party mirror of the site's OpenAPI v2 schema](https://github.com/deretame/Breeze-plugin-nhentai/blob/main/openapi.json), version `2.0.0+878a039` in the inspected copy, declares the following:

| Operation | Declared public access and relevant detail | What it proves |
| --- | --- | --- |
| `GET /api/v2/galleries` | Anonymous listing, 15 requests/min/IP; `page`, `per_page <= 100` | Pagination and lightweight group cards are modeled |
| `GET /api/v2/search` | Public search, anonymous 10/min/IP; keyword, tag, numeric and date syntax; `date`, `popular`, period sorts | Search is naturally Gallery results, **not Post results** |
| `GET /api/v2/galleries/{id}` | Public detail, anonymous 20/min/IP; `include` may request comments, related, favorite and suggestions | Richer group details can be loaded on demand |
| `GET /api/v2/galleries/{id}/related` | Public related gallery recommendations, anonymous 12/min/IP | **Recommendations** are not the current Gallery's pages |
| `GET /api/v2/cdn` | Public CDN configuration with image/thumbnail server lists | Media host assignment is dynamic; do not hardcode old domains |
| `GET /api/v2/tags/ids?ids=...` | Public ID-to-tag resolution, at most **100 IDs/request**, 15/min/IP | Resolve visible unknown IDs in deduplicated batches |
| `GET /api/v2/tags/{tag_type}` | Public type catalog, `sort=popular|name`, `page`, `per_page <= 100`, 15/min/IP anonymous | Popular-first catalog staging is supported **in the examined schema** |
| `POST /api/v2/tags/search` | Public prefix/name search, 30/min/IP | Autocomplete can work before full catalog completion |

The mirror is **not** a runtime availability test or an official support guarantee. Direct visits to `nhentai.net/api/v2/openapi.json` and the popular-tags website failed through the available browsing tool. That failure cannot distinguish site blocking, tool restrictions, CAPTCHA or actual endpoint outages.

## Gallery data: summary is not detail

`GalleryListItem` in the examined schema contains a Gallery ID, `media_id`, English/Japanese titles, thumbnail URL/dimensions, optional count/favorite data, Tag **IDs** and an optional blacklist marker. It does **not** include a verified upload date.

`GalleryDetailResponse` adds title, upload date, full Tag responses, `num_pages`, `num_favorites`, and `pages` manifest, with optional comments/related/favorite context. Its `pages` array defaults empty in the schema, so **no loaded pages** must not automatically mean **a confirmed zero-page Gallery**.

Each `PageInfo` has a source `number`, `path`, width/height and thumbnail fields. Do not invent image file extensions or assume page indices are zero-based. Validate the source's numbering and stable identities before choosing a durable key such as `gallery:<id>:page:<sourceNumber>`. `media_id` is distinct from Gallery ID.

**Avoid claiming `num_favorites=0` or a date from an absent list field**. Keep metadata provenance/unknown states. Do not falsely apply page tags to every image if only Gallery-level tags are provided.

## CDN/access spike required before implementation

A controlled native test, respecting source terms and documented rate limits:

1. Request public API root or config. Record status/headers and failure category without credentials.
2. List a few Galleries and perform one minimal search. Confirm pagination and safe/filter policy.
3. Open one Gallery detail; validate full PageInfo manifest, page order, missing media and one thumbnail/one page.
4. Query the CDN configuration and resolve a single actual media path through the declared server list. Confirm Referer, redirect behavior, Content-Type and cache semantics, not just URL syntax.
5. Resolve a small set of Tag IDs and one popular Tag page. Confirm pagination, category naming, rate-limit headers, 429/Retry-After and optional authentication behavior.
6. Test image load, cancellation and offline errors in the Android app's existing Dio/cache stack; optional desktop only after native success.

A failure is a feasibility finding, **not** a reason to bake in anti-bot workarounds, hardcode a proxy or automatically forward credentials. Use source-aware allowlists and reject unsafe server/path redirects.

## Tag catalog: popularity-first, completeness over time

The user observed approximately **40 popular general-tag pages at ~100 each** on the public website, around 4,000 general Tags. The fifth page had tags with relatively few Works compared with the top Tag. This is a useful priority signal, not a verified API count nor evidence for all categories.

**Recommended lifecycle:**

1. **Never block startup or first Gallery render** on the full catalog.
2. Resolve the **IDs that are actually visible** in Gallery cards with deduplication and bounded batches of <=100. This is higher priority than a background crawl.
3. Warm up a bounded first **five pages of popular general Tags** with `per_page=100` when connection/budget permits. On the user's estimate, at most 500 entries in the first pass.
4. After use, resume a **persistent per-category catalog crawl** at low priority, with checkpoints, cancellation, backoff and network policy. Sort by `popular` for warmup; prefer a verified stable continuation strategy for full coverage. Popular rankings can reshuffle and create page gaps, so deduplicate by Tag ID and periodically reconcile.
5. Reconcile renamed/merged Tags, keep actual canonical name/type/aliases/observed count/time and source version. Unknown IDs remain unknown; do not treat missing tag lookup as proven safe.
6. Completion is **per category and crawl generation**, not a single global boolean. A new Tag may appear after yesterday's completed crawl. On-demand lookup stays available forever.

**Pagination caveat:** The schema prose says both page-based and cursor-based pagination, but the inspected endpoint parameters expose `sort`, `page` and `per_page`, **not a confirmed cursor argument**. Do not build an undocumented cursor contract without a live response.

For 4,000 General Tags at 100 per page, about **40 requests** are theoretically enough for that category. At the schema's 15/min anonymous limit, the lower bound is roughly **three minutes**, not an hour-long startup task. This ignores additional category sizes, overhead and changing rankings. Five warmup pages require at most five of that bucket's requests. 500 popular Tags is about 12.5% of a hypothetical 4,000-tag *catalog*, **not** a measured percentage of Works covered.

## Should a tag seed ship inside the app?

**Not by default.** A bundled tag seed would give immediate offline names but introduces snapshot freshness, reproducible data collection, redistribution/provenance, generation, update cadence and package-size work. It does not remove the need for live lookup or invalidation.

Revisit after a native spike and measurements:
- Actual total count per Tag type and compressed seed size.
- Percentage of visible search results with unresolved Tag IDs after a 5-page warmup.
- Cold-start API calls, app startup latency, mobile data usage and stale/renamed Tag frequency.
- Licensing/terms and whether a reproducible public tag snapshot can be included.

If strongly beneficial, ship a **versioned bootstrap seed** that never overwrites fresher local observations. Do not include user accounts, credentials, Gallery pages or media.

## Product/UI proposal

- Search results show **Gallery cards**: cover, title, page count, languages and known Tag chips.
- Opening a Gallery uses shared Group UI. Initial product proposal: cover/details plus **ordered Page timeline or a media-first viewer**, with the same Post-specific actions as other grouped Posts. Choose the exact presentation with the user after comparing the Pixiv and Pool designs.
- The source's `Related Galleries` results appear as **recommendations**, not canonical member Pages and not Danbooru direct parent/child Related Families.
- Local Gallery Bookmark stores a typed Group reference, not all page snapshots. Page-specific local bookmarks can use stable Gallery/Page identities once verified. Any native account Favorite is a **separate** source feature.

## Proposed decision

Approve a **native-only feasibility spike**, **nonblocking, popularity-first Tag caching** with visible-ID resolution, and the Group/Page model. Defer hardcoded Page URL/identity/seed assumptions until real responses are available. Decide Gallery UI composition and whether to support an authenticated API-key profile only after the public read path has been measured.

**No production network or Android proof was performed in this research.**
