# Stage 08: native nhentai Gallery adapter

**Issue:** #157. **Branch:** `feature/157-native-nhentai-galleries`.
**Base:** reviewed #141 candidate, including all shared source/access/storage stages.
**Goal:** Android-first public Gallery browsing/search and Page viewing on the existing shared architecture, with bounded tag resolution and no account mutations.
**Final reviewer:** independent Astra High.

## Evidence and its limits

Read `docs/designs/2026-11-05-decision-04-nhentai-api-and-tags.md`. User-run WSL probes established HTTP 200 for public config, listing, CDN config, Gallery 694482 details and tag ID lookup; the detail manifest had source Pages 1-41 and a separate media_id. Thumbnail and image CDN HEADs returned WebP. Tag category `general` failed; `tag` succeeded. Pages 1 and 2 requested per_page=5 but each returned 120 items, total 4,774 and num_pages 40; Page 2 first/last IDs were 35972/28349. These are historical observations, not an official or stable API guarantee. HEAD is not GET/decode evidence, and two successful pages do not prove duplicate/gap-free catalog traversal.

Some returned thumbnail paths ended in `.webp.webp`; preserve actual source paths until tested. Never normalize an extension by assumption. Revalidate everything used by the native adapter; do not enable a source solely because a third-party OpenAPI mirror describes it.

## Files and boundaries

Add a native engine adapter beside the repository's current source integrations, proposed `lib/boorus/nhentai/` with client mapping, posts, galleries, tags, engine registration and read-only presentation. Client code belongs under `packages/booru_clients/lib/src/nhentai/` if consistent with current package organization. Add source/config entries through the actual existing booru configuration inputs and generation workflow, not a hardcoded registry fork.

Consume ContentReference/Group Summary/Details/member source, #143 public policy, #140's shared media-first composition, #141's explicit Group/Page local targets, StoredGroupCodec and existing Post media/download/cache pipeline. Do not create a new Gallery hierarchy, media cache, profile manager, network client per Page or app-wide tag service.

New tests: engine client/parser/source suites under `packages/booru_clients/test/` and `test/boorus/nhentai/`; Group/Page identity/roundtrip, CDN policy, paging, visible-tag priority and tag-checkpoint recovery tests. Fixtures must be synthetic/redacted and contain no private titles, credentials or user media.

## Task 1: native feasibility gate before enabling the engine

1. Using the app's actual Dart/Dio stack and an exclusively leased Android emulator, perform bounded anonymous GETs for config, a small listing, one detail manifest, one tag-ID lookup and search/pagination. Follow current source request coordination, timeouts and cancellation.
2. Validate one actual thumbnail and one Page image with GET plus decoder success, not just HEAD. Use paths/hosts returned by the successful API response; test the suspicious duplicate-extension path separately without silently rewriting it.
3. Validate the exact response envelopes, total/num_pages/next behavior, tag type names and Gallery/page fields against real payload structure. Record redacted field-level evidence in the handoff and durable API doc; do not commit raw private responses.
4. Handle 403/challenge/429/offline and retries conservatively. No proxy, scraping bypass, anti-bot evasion, credential forwarding or invented endpoint success. If native public reads fail, keep fixtures/code disabled and report the concrete blocker; previous stages remain valid.
5. Web/CORS support is not claimed by Android success. Preserve other platforms' builds with capability gating; do not introduce a server/proxy to sidestep browser restrictions.

## Task 2: stable Gallery/Page mapping

1. Freeze codec fixtures for `group/gallery:<galleryId>` and `post/gallery-page:<galleryId>:<sourcePageNumber>`. Source Page numbers remain 1-based in this new engine key; shared sourcePosition is pageNumber-1. Gallery ID and media_id are separate.
2. Produce Group Summaries directly from listings; known title/cover/member count/tag IDs are nullable source evidence. Details carry native description/creators/tags/dates only where supplied; extras use typed nhentai data.
3. Map each media Page to the existing real Post/PostCoreData with an engine-owned payload and stable source key. Do not make numeric core IDs the durable identity or blindly copy Pixiv's multiplier. The bridge to current PostId/media consumers must be deterministic, collision-free within validated source/storage bounds and tested, including missing/large page numbers; fail explicitly rather than truncate/round or collide.
4. Preserve original Page numbers and manifest order when media is missing, filtered or restricted. Do not compact indices or guess original URLs from thumbnails. A thumbnail is not evidence of original geometry/format/size.
5. Share detail/manifest request data between metadata and member loaders and pass already resolved Posts through GroupMemberBatch. No Page-by-Page detail refetch when the manifest contains the facts.
6. Test single Page, multi-Page, missing middle Page, malformed manifest, negative counts, unknown tags, repeated IDs and source ID versus media_id confusion. Roundtrip Group/Page bookmarks independently through v10.

## Task 3: CDN/media policy and existing viewer reuse

1. Validate config-provided CDN hosts using an engine-owned trust policy for the actual service, scheme and path shape. An API-provided URL is not unrestricted permission to fetch arbitrary hosts. Never send unrelated profile credentials or accept hostile redirects.
2. Use exact source paths and needed non-secret headers through the existing media resolver/cache. Keep retry/failover bounded; do not probe every host for every image. Do not assume every size/extension is available on every server.
3. Use the approved reusable Image View/Overview composition for Gallery/Pages, with real source metadata. No independent new UI design, Related changes or source-account Favorite controls.
4. Normal local Bookmark targets Gallery; explicit alternate targets current Page. Page download/share and explicit Download All use the same captured-target/queue rules as Pixiv, preserving native numbering and reporting unavailable Pages honestly.
5. Test decoder failure with safe retained preview, cold cache, cancellation, changed CDN config, expired/unavailable URL, large portrait Page, orientation and shared cache reuse. No full Gallery media prefetch merely on opening Details.

## Task 4: tag resolution without blocking reading

1. Resolve visible Summary/Details tag IDs first through verified ID lookup. Cache by actual source plus tag ID/type; retain canonical name separately from display translation. ID-only metadata is valid pending lookup.
2. Build optional/resumable catalog warm-up in the existing foreground source lifecycle and HTTP bulk coordination; it must not block browsing and is not new OS background scheduling (#70).
3. Maintain a per-source/category checkpoint containing observed sort/category, next page/cursor and observation metadata. Persist the fetched tag batch before advancing its checkpoint. Resume idempotently after interruption and deduplicate by tag ID, not name.
4. Use real response length and server continuation/num_pages; never hardcode 120 or assume per_page was honored. Detect repeated pages, changed totals and non-progress. Stop/cool down rather than spinning or declaring missing data complete.
5. Popularity ordering can move while enumerating. Treat coverage as partial unless actual evidence supports completion; retain known cache records across refresh and schedule a bounded future recheck rather than deleting unseen entries after one sweep. No claim of gap-free pagination from the two WSL responses.
6. Test 120 results despite limit 5, duplicate IDs across pages, empty page with continuation, total changing, error/retry/cancel, two categories, stale source, checkpoint write failure and visible lookup preempting bulk warm-up.
7. Reuse source taxonomy from validated config/API. `tag` is the observed ordinary-tag category; do not label API requests `general`. Preserve unknown categories safely rather than mapping them to the wrong existing type.

## Task 5: rollout and final acceptance

1. Register the engine only after native public read/media gates pass. Anonymous access is explicitly read-only; no account/profile is manufactured or server favorite write enabled.
2. Exercise native listing/search pagination, loading/error/empty states, metadata rendering, ordered Page navigation, Group/Page local saving, offline metadata and source removal. Use normal settings/localization and Kurumi.
3. Ensure other engines and Flutter platform builds are unaffected. New package changes require that package's complete tests plus app consumers. Run formatting/analysis and `./scripts/run_regression_tests.sh` on the final candidate.
4. Perform real Android acceptance for API GET, actual decode, pagination/tag resumption, limited/cancelled downloads and backup restart roundtrip. Keep adult/private media out of committed screenshots and logs; use redacted or safe symbolic fixtures for shared evidence.
5. Update source capability and API documentation with verified behavior and explicit platform/auth/rate-limit limits. Do not claim official stability or full site support beyond exercised functions.

## Delegation and review

Lower-cost agents may create sanitized parser fixtures, implement straightforward DTO-to-common-field mapping against fixed interfaces, add translations and layout tests. The lead owns source trust, ID bridging, raw-manifest sharing, paging/checkpoint recovery and native verification. Independent Astra High reviews the entire feature; the overall rollout then receives the separate cross-stage Astra High review in the handoff. Missing live evidence is a blocker, not a reason to invent successful support.

Do not add Manga Series, recommendations, account mutations or further sources. Deliver #157's individual handoff and keep the issue open until authorized publication.
