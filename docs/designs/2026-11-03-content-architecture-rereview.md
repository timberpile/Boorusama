# Content Architecture and Open-Decision Rereview

Review baseline: `e306ff5338a2255a89731c61bd0672336a933344` (`develop`).
Original review date: 2026-11-03. Published for continued design discussion on 2026-11-04.
Status: research and architectural recommendations, not an approved implementation specification.

This document preserves the findings of the earlier chat review in a repository-native form. It is a structured preservation, not a byte-for-byte copy of the original conversation attachment `boorusama_content_architecture_rereview_2026-11-03.md` (SHA-256 `4d8d35473a5a88b637bd751b3d3f58ae55aac1cda1fb3c65f2abf144d9f9889a`). Later user feedback takes precedence over the recommendations recorded here, particularly delivery order, Android-first scope, viewer visibility, and zoom behavior. Keep that feedback in a separate dated supplement rather than silently rewriting this historical review.

## Executive conclusion

Keep `Post` as one independently displayable media item. Extend the existing Post/snapshot/engine/Mixed Viewer architecture with a small reference-oriented group layer. Do not convert all repositories, controllers and widgets to an obligatory `ContentItem` superclass. Do not add independent Pixiv and nhentai bookmark/viewer systems either.

Generalize the boundaries that genuinely differ: stable addressing, group metadata, ordered member loading, listing-result presentation, operation targets and gallery lifecycle. Preserve the existing media viewer, media loading, snapshot persistence, user memberships and source authorization rules.

A group is not necessarily `List<Post>`. A member is a reference with a source position or member identity and availability state. This permits Series -> Work -> Page without requiring a recursive tree UI now. Animation frames are media encoding details, not independently navigable pages.

The original recommendation was to validate the design early against a Pixiv Work, while Danbooru Pool/Related and Szurubooru expose shared behavior. The user's later sequencing decision supersedes that delivery suggestion: finish current work and establish a clean baseline, then implement the architecture, then the remaining Pixiv/nhentai features. Fixtures may validate the proposed interfaces during design without shipping those features early.

## Evidence and limits

The original review inspected the pinned develop source, `AGENTS.md`, design/review skills, relevant models, persistence, galleries, search, Pixiv, current issues and the integrated style guide. The supplied cross-agent handoff was supporting context, not authority to override the user's decisions. The HTML mockup was reviewed as a proposal, not as implemented Flutter UI.

Evidence categories:

- **Confirmed source finding:** directly visible in the pinned repository.
- **Official documentation:** source product documentation, not an authenticated API test.
- **Schema-described:** stated by the inspected API schema or mirror; production behavior not verified.
- **Inference:** plausible consequence of code, without device reproduction.
- **Recommendation:** proposed approach, not an approved decision.
- **Open:** requires a user choice or more evidence.

No Flutter tests, analyzer, Android build, Maestro run, device benchmark or authenticated Pixiv request was performed by the original review. It did not have independent subagent reviews. Its identity/migration, API and UI/performance counterchecks were performed by the same reviewer.

Official nhentai API/docs/CDN retrieval was unsuccessful through the available tools. No authoritative HTTP-header capture established the reason. Do not infer an API outage, mandatory login, bot protection or CORS failure from that result. The settings review was not a completed interaction audit of every setting and profile override. Feed and navigation defects remain reported symptoms with source-supported investigation points.

## Important corrections to earlier discussion

1. Integrated bookmark exports are **v9**, not v7. The codec accepts v4-v9.
2. All/Newest uses the latest current membership date; All/Oldest uses the earliest. Do not restore the earlier independent-global-date proposal.
3. A shared gallery does not by itself support native Work/Gallery search results: search remains Post-bound.
4. Logical identity must not depend on a mutable presentation label, account binding, viewer occurrence, media URL or synthetic integer.
5. The source namespace normalizer retains meaningful ports and installation paths. `Uri.host` alone is insufficient.
6. Gelbooru.com uses the `gelbooru` adapter; Rule34.xxx uses `gelbooru_v2` with site-specific overrides. Shared widgets do not imply identical source capability.
7. Official Pixiv help limits native Series to Manga and Novels. A normal illustration is not a member of a Manga Series merely because a mockup shows it.
8. Pixiv's separate Collection Feature (Beta) includes heterogeneous content. This is an extensibility consideration, not current scope.
9. nhentai schema evidence is not an API/CDN/browser acceptance pass.
10. The existing viewer-hidden preference is reapplied during post changes on compact layouts, not only on route opening.
11. The separate Original Image page is reachable through configured gestures. A grid-origin action needs a normal viewer to be opened before an in-place original-media request is possible.

## Current implementation and boundaries

| Area | Source finding | Consequence |
| --- | --- | --- |
| Post | Shared final runtime `Post`, typed engine payloads, versioned snapshots | Retain media model and consumers. |
| Viewer identity | `ViewerContentIdentity` uses engine, namespace, kind and integer upstream ID | Add stable string/composite addressing without rewriting every media consumer. |
| Bookmark identity | `BookmarkIdentity` uses normalized site plus string `postKey` | Identity rules are not yet one common contract. |
| Source namespace | Includes meaningful port and installation path | Preserve self-hosted isolation. |
| Viewer group data | `PoolViewerEntry` imports `RemoteBookmarkPool` from Bookmarks | Move genuinely neutral metadata out of the bookmark layer when touched. |
| Renderer extension | Repository implements `ViewerEntryContentCapability` returning Widgets | Separate data and presentation registration at this boundary. |
| Group bookmark | Private constructor, integer reference, optional Related family and binary `_typed()` | Renaming the class alone does not make it extensible. |
| Group capability | `PoolBookmarkCapability` combines metadata, Series discovery and WidgetRef navigation | Split data lookup from UI/navigation responsibility. |
| Gallery lifecycle | Pool/Related duplicate selection, outer paging ownership and checkpoints | Extract shared orchestration, not engine query semantics. |
| Szurubooru | Separate Pool detail UI and fetch-by-ID path | Useful independent engine validation; do not assume embedded parity. |
| Summaries | `PoolSummaryIndexer` samples members through Pool queries | Keep as an existing strategy, not a universal loader. |
| Search | `SearchPageScaffold<T extends Post>` and PostGridController-bound builders | A native group-result seam is required. |
| Backups | Dated memberships and v4-v9 import | Extend current semantics and preserve compatibility. |

Primary source paths at the pinned baseline:

- `lib/core/posts/post/src/types/{post.dart,booru_post_data.dart,post_origin.dart,post_id.dart}`
- `lib/core/posts/post/src/data/{stored_post_codec.dart,post_origin_resolver.dart,origin_aware_post_repository.dart}`
- `lib/core/posts/details/src/types/viewer_entry.dart`
- `lib/core/posts/details/src/widgets/{viewer_entry_content.dart,mixed_post_details_page.dart}`
- `lib/core/bookmarks/src/types/{bookmark_identity.dart,pool_bookmark.dart,pool_bookmark_capability.dart,bookmark_grid_entry.dart}`
- `lib/core/bookmarks/src/services/pool_summary_indexer.dart`
- `lib/core/backups/sources/bookmark_backup_codec.dart`
- `lib/core/search/search/src/widgets/search_page_scaffold.dart`
- `lib/boorus/danbooru/pools/details/src/pool_detail_page.dart`
- `lib/boorus/danbooru/posts/related/related_gallery.dart`
- `lib/boorus/szurubooru/pools/src/pool_detail_page.dart`

## Architecture alternatives

### Universal ContentItem rewrite

Uniform generic signatures would propagate through repositories, media resolution, snapshots, downloads, favorites, selection, feeds and tests. Groups would be pressured to expose media-only fields. Not justified solely by Works and Galleries. A conceptual umbrella is useful; an obligatory base class is not.

### Separate implementation per engine

Fast initially, but duplicates source resolution, restoration, membership, failure handling and navigation. Keep source adapters, not separate bookmark databases or full viewers.

### Neutral references and small shared capabilities

Preferred: preserve ordinary Post APIs, add narrow group/listing seams, adapt Pool/Related without changing wire identities for naming reasons. Avoid speculative interfaces. Validate the design against concrete existing consumers and representative fixtures for new sources.

## Proposed domain boundaries

Names below are proposals, not approved APIs.

### Identity, reference, authorization and occurrence

- **Content identity:** underlying source resource, independent of access account and display position.
- **Content reference:** validated portable address sufficient to resolve that resource.
- **Access binding:** chosen real profile or explicitly supported anonymous read-only context.
- **Occurrence:** one appearance of content in a particular list/viewer/member sequence.

Identity conceptually includes a canonical source namespace, stable resource discriminator and source key. The engine participates in validation/resolution. Resolve the exact relationship to the verified alias registry before changing persisted IDs. Preserve actual origin/access URL separately from canonical database identity.

A Danbooru Pool remains the same Pool if its display category changes between Series and Collection. A Pixiv Work remains the same Work if classified as Illustration or Manga. Those mutable labels must not determine identity. Canonical kinds and presentation roles are separate concerns.

The existing normalizer preserves paths and ports; an installation under `/a` is not automatically the same database as `/b`. Verified host aliases from **Recognize Verified Booru Host Aliases (#43)** must never authorize credential forwarding, weaken visibility restrictions or merge unrelated installations. Same image/hash does not mean same upstream content.

Current synthetic Post integers may remain compatibility identifiers for established media APIs. New logical references should preserve exact string/composite keys, including Pixiv `work-page:<workId>:<originalIndex>`. Do not encode every future entity into integer arithmetic or silently change existing Pixiv IDs. Reconcile internal integer consumers incrementally and use canonical keys for new addressing.

### Group semantics

| Resource | Membership | Relevant distinction |
| --- | --- | --- |
| Danbooru Pool | Ordered independent Posts | Display category can be Series/Collection. |
| Danbooru Related | Direct parent/child family | Dynamic family, not recommendations. |
| Szurubooru Pool | Source-defined ordered Posts | Its own API and capabilities. |
| Pixiv Work | Ordered image pages | Work metadata and account actions differ from page-media actions. |
| Pixiv Manga Series | Ordered Works | Nested group references, not a flat image list. |
| nhentai Gallery | Ordered image pages | Gallery metadata can be complete without member sampling. |
| Local Bookmark Group | User-managed local memberships | Not a remote Content Group. |

Use membership edges, not a universal single `parentGroup` field: a Post can belong to multiple Pools. A page may have an owning Work while also appearing in local groups and other viewer sequences. Prepare nested references without implementing an arbitrary recursive tree UI. Future nested navigation needs cycle protection and explicit route state. Reading direction is not the same as UI RTL.

Ugoira frames encode one animation; they are not independently bookmarkable Gallery pages. Similar/related recommendations also do not create authoritative membership: nhentai similar Galleries and Pixiv related illustrations are not Danbooru direct families.

### Summary, details and members

A compact summary carries a reference, known title, safe cover, count with unit, applicable tags and source facts. Engine-specific details remain typed. Loading members is separate from loading summary/details; a group detail object must not require every Post to be eagerly materialized.

A member result needs the referenced content, source member key/position, optional hydrated Post or child-group summary, availability and continuation semantics. Preserve original Pixiv page positions and source nhentai page numbers. Missing members do not renumber later ones.

Distinguish: not requested, partially loaded, inaccessible, transient failure, removed, unsupported, and confirmed empty. Missing/default-empty `pages` with a positive page count is not a proven empty group.

Counts need units: 12 Works is not 12 images. Remote totals, loaded items and visible items differ. Unknown is not zero. Tag completeness needs scope: all Work-owned tags is different from a full union of member tags. Group publication dates differ from oldest/newest member upload times. Do not use one `isComplete` flag for all these independent facts.

### Loading and capabilities

The small mandatory group contract should resolve metadata and open a member source. Optional capabilities include supported ordering, local bookmarks, remote favorite target, sharing, downloads, artist navigation and search. Avoid both a giant UnsupportedError interface and an interface per text field.

Support ordered ID batches, dynamic paginated queries, small complete manifests and paginated child Works. A source adapter owns cursor/page interpretation, end-of-list evidence, sort semantics and cancellation. Zero renderable items does not prove exhausted pagination. Validate server `next_url` values rather than forwarding credentials to arbitrary URLs.

Bind asynchronous results to resource, order/query, access/policy and generation. Late responses from replaced profiles must not update the new session. Cache account-sensitive metadata by access/policy context, not content identity alone.

### State ownership

| State | Owner |
| --- | --- |
| Validated references and neutral facts | Data layer / engine adapter |
| Reusable fetched metadata and manifests | Access-aware bounded cache |
| Favorite visibility and account state | Access-bound state |
| Local group memberships and dates | Existing bookmark library |
| One appearance's order, selection and scroll checkpoint | Route/occurrence session |
| Image transform, playback and media loading | Existing Post viewer |
| Globally selected browsing profile | Existing navigation layer |

References and snapshots never contain credentials, Widgets, providers, callbacks or controllers. Cache manifests without creating user bookmarks for their members. Prefer immutable revisions and structural reuse so progress events do not cause whole-library decoding.

## Shared gallery and listing presentation

Reuse existing Kurumi/Danbooru controls, spacing, card badges, action layout and details sections. Share gallery navigation, loading/error states, checkpoints, selection and gesture ownership. Keep source API grammar, membership and mutations outside the shared shell.

A reusable gallery shell does not require the same vertical layout for every semantic resource. The later user feedback specifically asks for media-first Pixiv Works rather than blindly copying Pool Header -> Description -> Grid. Treat the metadata and member-layout slots as composition points.

A reader is a presentation over ordered members, not a new data model. Avoid independent nested full viewers with competing horizontal gestures. Opening member Posts through the normal viewer above a gallery must preserve return position and the outer occurrence.

Native group search requires a result boundary in addition to gallery extraction. Reuse query editing, history, suggestions and search options while allowing native Post or group entries. Do not fetch every Gallery detail to manufacture fake Posts. Keep ordinary Post repositories unchanged where possible.

**Group Related Posts in Timelines (#134)** is a separate projection over already-loaded Post results. It retains its rolling window, original result order and counts. A native Work result is not a grouped search occurrence.

## Bookmarks, imports, sync and operations

Preserve v9 membership rules: idempotent adds retain dates; true removal/re-add uses a new date; Undo and duplication restore dates; All uses extrema of current memberships. Dates belong to local user membership, not remote summaries.

Preserve historical Pool/Related wire variants and storage keys through compatibility adapters. Unknown future data must not disappear during writes or exports. Either preserve an opaque unsupported payload or fail safely before mutation; do not claim arbitrary forward compatibility exists today. Imports require transactional validation, source consistency, deduplication and rollback.

**Import Bookmarks Without Matching Profiles (#142)** separates storage from availability. **Display Imported Bookmarks Without Profiles (#143)** specifies a reusable internal anonymous read-only context where supported, not hidden saved profiles. Do not probe arbitrary imported hosts or borrow other accounts. **Add Folder-Based Collection Sync (#144)** keeps received subscriptions read-only; metadata refresh is not permission to edit user/subscribed memberships.

Operations need an explicit target. On a Pixiv page: local Save Page targets the page; Save Work targets the Work; remote Favorite targets Work plus account; Download Image targets the selected media; Share Work targets the Work reference. Current favorite consumers using `post.id` must not receive synthetic page IDs for Work-level mutation. Reuse existing actions through engine target resolution rather than per-widget special cases.

## Pixiv findings

Current infrastructure includes the authenticated app-api client, nullable illustration/user DTOs, stable page indexing, typed Post payloads, snapshots, Mixed Viewer, Explore, read-only Favorites and following feeds. **Fix Pixiv Page Index Renumbering (#137)** and **Navigate Mixed Content in Post Viewer (#138)** are integrated foundations.

The current parser flattens Work pages. It preserves original positions when earlier media is missing. Keep that identity behavior when adding Work entries. **Present Pixiv Multi-Image Works (#140)** owns Work presentation. **Bookmark Pixiv Works and Images (#141)** owns independent whole-Work and page memberships. **Support Pixiv Artwork Bookmark Actions (#124)** is account-scoped remote mutation, not local bookmarking.

### Native entities and endpoints

Official help says Manga/Novels support Series, not ordinary Illustrations. A series DTO alone does not establish member loading. An independently implemented client provides concrete evidence for `/v1/illust/series` with `illust_series_id` and continuations involving `offset`/`last_order`; this remains an undocumented, unverified-for-Boorusama endpoint.

Pixiv also documents a distinct Collection Feature (Beta) with heterogeneous Works/Novels/links/text. Do not expand current scope to all of it. It demonstrates why a Post/group sum is a scoped application model, not a claim about all possible content.

The current Boorusama `getUserIllusts` sets `type=illust`. Broader Manga coverage needs explicit source work. Authentication remains required for the existing app-api integration. Optional desktop is not proof of browser CORS support.

### Artist discovery

Keep `user:<positive-id>` as stable query serialization. Resolve names for display and allow ID input. Display name/account name are not identity. Account identifiers can change. The user-search endpoint is a concrete candidate, but exact account-name matching and ambiguous results require authenticated tests. Debounce, cancel stale responses and cache repeated lookups; do not resolve every chip with an independent per-item request. Follow **Expand Pixiv Search Capabilities (#83)** and preserve incompatible-scope validation.

### Data fidelity before UI expansion

- Preserve title, caption and creator separately from page file facts.
- Artist name, account and ID already exist; avatar/follow status are available in DTOs but need careful mapping and account ownership.
- Views and bookmarks currently collapse missing values to zero. Preserve unknown before displaying numbers.
- Translated tag names are currently inserted as additional tags. Retain canonical names and translations as paired display information instead.
- Preserve series ID with title if navigation is intended; a title is not a reference.
- AI unknown is not evidence of Not AI-Generated.
- Work favorite/follow/private state is account-scoped, not a universal persistent content fact.
- Single-image resolution may be verified from the source; do not claim those dimensions for every page of a multi-image Work.
- Original bytes remain unknown unless independently verified from already available original media or a bounded metadata path. Never fetch an entire original merely to populate a label.
- Keep Pixiv Bookmarks and Views labeled as such, not Score or silently generic Favorites.
- Ugoira duration derives from trustworthy frame timing when available; do not invent per-frame Posts.

The earlier mockup was a visual experiment. Its Illustration/Series and Ugoira/multipage combinations require correction. Do not implement every control shown there solely because its visual direction was accepted.

### Gelbooru and Rule34 correction

Gelbooru.com's `gelbooru` builder registers shared toolbar, source, tags, file details, artist/uploader/character sections. Rule34's `gelbooru_v2` builder additionally registers a conditional Related section. Generic detail-fact slots show known score/comments where supplied. Per-host DTO/API responses differ; MD5/status may be useful optional technical fields, but unprovided counts/description/size remain unknown. **Resolve Original File Size Where Available (#127)** owns bounded original-size discovery.

## nhentai findings and uncertainty

The inspected OpenAPI mirror advertises Gallery listing/search/detail, CDN config, tags by type, batched tag-ID lookup, tag autocomplete, favorites and optional archive downloads. This is schema evidence only.

Key schema distinctions:

- Gallery list entries contain lightweight IDs/titles/thumbnail/page and favorite counts/tag IDs.
- List entries do not establish an upload date.
- Optional/defaulted counts need field-presence awareness.
- Details contain fuller tags and page metadata; absent pages are not confirmed empty.
- `PageInfo.number` is explicit. Verify its numbering convention and preserve it through filtering.
- Gallery ID, media ID and media path have different purposes.
- CDN config must inform allowed media resolution rather than hardcoded historic hosts.
- Similar Galleries are recommendations, not a Danbooru Related family.
- Archive download is authenticated and feature-flagged; individual page downloads are a separate capability.

### Tag cache

The user's goal is a complete persistent ID-to-tag catalog, not a mandatory startup crawl. The original recommendation was batched on-demand resolution plus optional resumable catalog synchronization. Later feedback adds a popularity-first warmup and a website observation of roughly 4,000 general tags; treat that observation separately from unmeasured total tags across artist/character/parody/group/language/category types.

The mirror describes up to 100 IDs per lookup and up to 100 tags per catalog page. Its catalog description mentions cursors, but the inspected parameter list exposes page/sort/per_page; do not invent a continuation parameter. Changes during popular ordering, renamed/merged tags, partial progress and negative cache behavior need validation. A populated catalog still needs on-demand lookup for new IDs.

The current cache is keyed primarily by site/name. Add a scoped numeric-ID index without forcing unrelated engines to adopt IDs. The Web provider uses EmptyTagCacheRepository; native Android support is a distinct deliverable.

### Minimal later runtime gate

Before claiming engine readiness, capture one listing, search, Gallery detail, thumbnail, original page and tag batch through the actual client. Check source numbering, request/auth headers, cancellation, error/429 behavior, CDN origin/redirect trust and cache use. Test browser CORS only if Web becomes supported scope. No scraping or bypass assumption follows from a failed documentation fetch.

## Sharing

Retain the existing `.bslink` envelope: format `boorusama-link`, version 1 and a validated URI. Resource kind already lives in the URI authority (`post`, `artist`, `search`); it is not an extra envelope type. Proposed `pool`/`related` routes can map to the shared validated reference model.

`BoorusamaCollectionLink` was a proposed implementation name, not a required abstraction. Two small typed parsers with shared validation may be simpler. Preserve existing Post/Artist/Search compatibility. Old apps will reject unfamiliar URI kinds safely even if the file envelope stays v1; do not call that full backwards feature compatibility.

Export no credentials, local membership list or member snapshot database. A Pool uses its source ID; a direct family uses the established anchor reference. Resolve through an appropriate local profile; future anonymous support must reuse the same trust/access rules. File names and share text need privacy review too: existing Artist names can include a local profile label.

## UI and interaction findings

### Timeline contract

Headers are opaque. Search field surfaces remain distinct rounded Kurumi fields over a shared opaque region. Other toolbar child controls can be transparent. Preserve independently configured toolbar/search visibility and avoid overlapping/double-reserved insets. **Fix Browse Search Toolbar Overlap (#146)**, **Unify Android Timeline System Bars (#147)** and **Standardize Timeline Header Scrolling (#148)** share the contract but need separate acceptance. **Establish Kurumi UI Design System (#136)** owns the guide, not implicit runtime approval.

The prior **Fix Floating Pixiv Titlebar Background (#131)** wording preserved Public/Private controls as top-only, whereas later global scrolling proposals can imply all toolbars return. This needs explicit classification: top-only page selection versus a true toolbar filter. Later user feedback clarifies that true toolbar filters should return with their toolbar, but the current separate Public/Private row need not follow automatically. Its vertical cost remains open.

App bottom navigation and Android system navigation are different regions. A disappearing app bar leaving reserved black space is not automatically repaired by system-bar styling. Inset ownership belongs to one shell/route region and must restore correctly after immersive media viewing.

### Kurumi and menus

Use suitable Kurumi components rather than raw alternative presentation. Do not ban Material primitives inside standardized components mechanically. Leading action icons differ from trailing checkmarks/counts/submenu indicators. Shape definitions should preserve the same visible/background/pressed/hover/focus geometry. **Standardize Control Corner Radii (#105)** owns radius decisions, not arbitrary new tokens in every feature.

### Bookmark toolbar

Reuse common layout/overflow/scroll mechanics without erasing bookmark-specific semantics. **Integrate Search Actions Into Timeline Header (#115)** does not itself promise a complete BookmarkListControls rewrite. Source filter options should come from the current group's contents before applying the source filter; otherwise a filter may hide its own alternatives. Source and account/profile filters are distinct. Short sort labels retain explicit accessibility descriptions. Partial/unknown tag data must not silently change already agreed local strict-filter semantics.

### Keyboard dismissal

The Browse/search cleanup deliberately retains nonempty drafts. That is a source-supported investigation point for the reported invisible blocking overlay, not a device diagnosis. Preferred behavior is retaining draft data without mutating the applied query or leaving an unexplained modal barrier after dismissal. Back behavior needs a deliberate draft/editor contract.

### Viewer controls

Title Case label `Viewer Controls on Open`, with `Visible`/`Hidden`, was accepted. At review time the implementation reapplied Hidden on compact-layout post transitions. Later feedback explicitly changes the desired contract: use the setting only when opening the viewer. Preserve user-controlled visibility while navigating, with group-owned controls handled separately.

### Original viewer

`OriginalImagePage` and `/original_image_viewer` are still reachable through `viewOriginal` gestures. Replace compatibly: inside a normal viewer request original media there; from a grid open the normal viewer with the correct source/sequence and request original. Preserve saved gesture keys/backups. Review image rotation separately from device orientation. Do not drop a capability because the old route looked unused.

### Zoom

Classic resets on the next double-tap but normally uses 3x and special other-dimension fit for strong aspect mismatch. Fit Cycle progresses through other-dimension fit, a further detail level, then reset. A square image in a 400x800 viewport gets 2x then 6x; a 1600x900 image gets about 3.56x then 10.67x, before maximum clamps. These are geometric calculations, not device tests.

Separate the two decisions: immediate zoom/reset interaction and geometry-dependent first target. A fixed 2x proposal was not accepted. Later user feedback prefers Classic's two-state interaction with aspect-aware targets, square images fitting height, wider images zooming more, and very tall content handled by Comic mode. Resolve orientation, available viewport, Auto Comic baseline, manual pan/pinch and reset semantics through a visual experiment before selecting constants. Keep video seek and user gesture overrides intact.

## Performance, settings and integration

The 5,000-Post Feed report needs profiling. `_CachedFeedGrid.didUpdateWidget` may rebuild a history session and synchronously decode recent snapshots after content changes; it also has a branch retaining active history. Do not claim every progress event always decodes everything. Separate decoding, filter/sort, database work, image decoding and widget rebuilds in profile mode before introducing isolates or large provider rewrites.

The settings review checked category/behavior boundaries, not all interactions. A complete audit should inventory meaning, scope, default, global/profile override, effective value, dependency, search aliases, accessibility and restore behavior. Moving categories alone will not explain inheritance. Preserve stable setting IDs/serialization when changing labels. Do not equate all appearance with static styling: motion, reader gestures and playback may need their own comprehensible grouping.

Batch integration can use one final combined candidate and a complete regression on that exact state. Scope checks remain per task; a changed runtime combination invalidates the earlier full pass. Do not weaken final verification because several ready branches are stacked. Issue IDs must remain in final commit messages.

## Counterexamples that the design must survive

- Identical numeric IDs from two unrelated sites; same-host separate installation paths.
- Verified database aliases without credential/visibility broadening.
- One resource appearing twice with independent scroll/selection state.
- A Pool changing display category without losing bookmarks.
- A missing middle page without shifting later page identities.
- A Series containing Works rather than raw Posts.
- Ugoira frames remaining one animation.
- Recommendation sections not becoming canonical families.
- Unknown count versus zero; unloaded members versus confirmed empty.
- Group-owned tags versus sampled member unions.
- Work-level favorites from a page-specific display.
- Account removal/token/visibility changes invalidating stale requests and sensitive cached state.
- Unknown serialized types surviving a safe path or causing preflight rejection before mutation.
- Native group search with no detail request per result.
- Large feeds without whole-collection recomputation on status updates.
- Accessible Android UI under narrow width, enlarged text, keyboard and RTL without changing reading order accidentally.

## Verification required for eventual implementation

Identity tests cover namespaces, stable keys, original page positions, category changes, duplicates, aliases and hostile inputs. Persistence tests cover v4-v9 imports, new schemas, memberships/dates, Undo, duplication, rollback and unknown types. Listing tests cover incomplete/empty/filtered pages, source continuations, bounded loading, cancellation and stale responses. Viewer tests cover repeated occurrences, member opening/Back, sorting, selection, retained media, nested group boundaries and source removal. Action tests cover Work/page targets, account isolation and failed mutations. UI acceptance covers the integrated timeline contract, gesture/three-button Android modes, applied themes and real scroll transitions. Performance acceptance uses measurable work/frame behavior rather than wall-clock sleeps.

## Decisions not resolved by the review

- Final type names and exact reference/identity storage schema.
- Whether a narrow Post/group listing union is needed at each new seam; no compulsory universal base class.
- Extent of nested-member support in the first release.
- Pixiv Work opening behavior: media-first preview, inline gallery, direct viewer or reader.
- Complete-catalog synchronization/bundling policy and supported nhentai platform scope (later clarified Android-first).
- Public/Private filter placement.
- Aspect-aware zoom targets and Comic reset behavior.
- Exact Original-viewer migration/rotation behavior.
- Scope and delivery ordering (later clarified: stabilize current issues, architecture, then new source features).

## Source index

All repository paths above refer to [the pinned baseline](https://github.com/timberpile/Boorusama/tree/e306ff5338a2255a89731c61bd0672336a933344), not mutable assumptions about develop.

Useful repository documents: `AGENTS.md`, `docs/post_architecture.md`, `docs/bookmark_groups.md`, `docs/ui_style_guide.md`, `docs/development_workflow.md`, `docs/designs/booru-post-database-aliases.md`, `docs/designs/engine-post-metadata-audit.md`.

External references originally consulted (revalidate before implementation):

- [Pixiv: illustration series](https://www.pixiv.help/hc/en-us/articles/115000316794-I-want-to-create-an-illustration-series)
- [Pixiv: Collection Feature Beta](https://www.pixiv.help/hc/en-us/articles/48871761081369-What-is-the-Collection-Feature-Beta)
- [Pixiv: Ugoira](https://www.pixiv.help/hc/en-us/articles/235584628-What-are-Ugoira)
- [Pixiv: changing a pixiv ID](https://www.pixiv.help/hc/en-us/articles/235644707-I-want-to-change-my-pixiv-ID)
- [nhentai official API documentation](https://nhentai.net/api/v2/docs)
- [nhentai OpenAPI mirror](https://github.com/deretame/Breeze-plugin-nhentai/blob/main/openapi.json), evidence of the mirrored schema rather than successful production requests.
- [Independent Pixiv client endpoint definitions](https://github.com/FlanChanXwO/pixiv-cli/blob/db95542c15f5c97be579843f16840015ac96df9e/internal/pixiv/api/routes.go)
- [Independent Pixiv Series loading implementation](https://github.com/FlanChanXwO/pixiv-cli/blob/db95542c15f5c97be579843f16840015ac96df9e/sdk/pixiv/artwork.go)

## Handoff boundary

This publication preserves research. It does not create new implementation issues, authorize merges, approve every proposed API or certify runtime behavior. Consult the dated feedback supplement and visual variants before turning recommendations into implementation requirements. Always refer to issues by descriptive title as well as number in communication with the user.
