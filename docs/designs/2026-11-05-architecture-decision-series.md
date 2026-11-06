# Content Architecture — Six Decisions, Ready for Sequential Review

**Discussion index | 2026-11-05.** Current code reference: `develop` `e306ff5338a2255a89731c61bd0672336a933344`. No architecture, Pixiv or nhentai runtime code changed on this documentation branch. Existing issues and bugs should reach the agreed clean stabilization baseline before implementation. No PR or integration authorized.

**Start with the [illustrated, five-minute overview](2026-11-04-content-architecture.md)**. Read these six research briefs **one at a time**; they are evidence and proposals, not silently accepted product decisions.

| Discuss | Brief | One key decision | Recommended direction |
| --- | --- | --- | --- |
| **1. Shared models** | [Minimal shared Group contract](2026-11-05-decision-01-shared-group-contract.md) | How few new types are necessary? | Existing `Post` + validated Reference, light Summary, positioned Member, narrow engine capability; reuse ViewerEntry, paging and Kurumi |
| **2. Work/Page UX** | [Compact actions and gallery UI](2026-11-05-decision-02-work-page-ux-and-actions.md) | How to distinguish Work versus current Page without duplicating controls? | Normal Bookmark saves Work; hold offers Work/Page; Page download default, hold Download All; two portable links inside existing Share Sheet; Pools keep group Header + per-Post Timeline |
| **3. Pixiv** | [Series, names and related recommendations](2026-11-05-decision-03-pixiv-series-users-related.md) | Which source features require a live authenticated spike and which data must survive mapping? | Series → Works → Pages; stable numeric user ID with readable resolved name; optional Related Works; preserve title/artist/stats/series IDs |
| **4. nhentai** | [API/CDN and staged tag catalog](2026-11-05-decision-04-nhentai-api-and-tags.md) | When to initialize tags and whether access is feasible? | Native-only proof first; visible ID lookup + five popular pages nonblocking; complete cache by category over time |
| **5. Persisted data** | [v9-to-v10 migration and future records](2026-11-05-decision-05-migration-future-records.md) | Opaque unknown Group retention versus preflight rejection? | Typed v10 Group references when added; v9 still readable; reject unsupported structural versions; only preserve opaque unknown kinds if lossless round-trip is proven |
| **6. Zoom** | [Aspect-aware Classic and real-device samples](2026-11-05-decision-06-zoom-geometry-and-data.md) | What first double-tap amount and reset baseline do real observations support? | One-in/next-out, measured aspect-aware target; Comic reading baseline treated explicitly; wait for JSON from the test branch |

**Concrete Zoom algorithm:** [Aspect-Aware Classic test candidate](2026-11-06-aspect-aware-classic-zoom-algorithm.md) translates the user's four extreme-image footprint rules into smooth transitions and a normal-picture detail zoom. The coefficients are experimental and not deployed.

**Direct Group member counting:** A single nullable `memberCount` represents **immediate** members only (Series → Works, Work → Pages, Pool → Posts, Gallery → Pages); derived display labels, no aggregated grandchild Page count in the shared Series Summary. [Concrete Group field proposal](2026-11-06-content-group-summary-details-candidates.md).

**Conservative zoom preference (later clarification, 2026-11-06):** User prefers a slightly weaker zoom to a too-strong one; ordinary images should usually start around 2.0–2.5×, square boost tentatively only to 2.45×. Extreme wide/tall **readability** zoom is exempt from that ordinary-image limit. The [concrete candidate](2026-11-06-aspect-aware-classic-zoom-algorithm.md) has been updated. Earlier 0.29× fitting statistics refer to the **previous** stronger model, not the revised conservative one.

## Updated user direction (2026-11-06)

- **Group metadata:** User prefers **separate Summary and Details stages**, not one all-optional domain class. Both should be reusable across engines, but have optional **typed engine-specific payloads** analogous to `Post.booruData`; missing source fields remain unknown. See [the concrete field comparison](2026-11-06-content-group-summary-details-candidates.md). Exact payload interface and persisted codec still require approval.
- **Zoom:** User distinguishes readability zoom on extreme image ratios from detail inspection on normal images. Extreme tall portrait → fill width; tall landscape → square-ish centered image column; wide portrait → square-ish/slightly portrait image band; wide landscape → fill height. Empirical user-selected image footprint medians strongly support these targets. See [the updated Zoom brief](2026-11-05-decision-06-zoom-geometry-and-data.md). These samples were deliberately manually chosen; do not dismiss them because Snap or Auto Comic settings were enabled.
- Runtime remains untouched by these documents. No final zoom thresholds or source-payload Dart signatures are approved.

## Confidence and research limitations

**Confirmed in current source:** existing `Post`, `ViewerEntry`, strict Pool/Related bookmarks, v9 backup dates, Pixiv Work/Page stable keys, Post-only search boundary, Share Sheet fields and current zoom algorithms.

**Externally supported but not Boorusama-tested:** Pixiv's user search / related / bookmark write endpoints (third-party App API clients); nhentai's v2 tag list/popularity, gallery details, ID lookup and CDN API contract (current third-party OpenAPI mirror); Pixiv's official Manga Series limitation.

**Not yet verified live:** Pixiv Manga Series continuation, authenticated User search result reliability, Related Works pagination, Write/Favorite state behavior in our app, nhentai API/CDN reachability and rate behavior, current tag counts beyond the user's website observation. Do not claim production availability from an OpenAPI schema alone.

**Not yet user-decided:** exact Dart signatures, opaque compatibility policy, Pixiv Series initial release scope, nhentai Gallery presentation, Comic reset and zoom cap. The user's preferred Bookmark/Download/Share shortcuts are recorded as the leading UX direction, not evidence that the gestures have passed Android tests.

## Key product distinctions

- **Group category vs source resource type:** Danbooru Series and Collection share Pool identity/API; nhentai Gallery can reuse the same group framework with its own adapter.
- **Work vs Page:** source Pixiv bookmarks target Work; Boorusama local bookmarks may target Work or a single Page. Download Page is the default; Download All is explicit. The source artwork URL remains one Work link; image URL is Page-specific; Boorusama portable links can distinguish both.
- **Parent membership vs recommendations:** Pixiv Related Works and nhentai Related Galleries are suggestions, not member Pages or Danbooru direct-family relationships.
- **Content vs access vs occurrence vs membership:** one stable content identity, separate account/anonymous permissions, separate Viewer placements, and independent local group membership dates.
- **Not every listed responsibility is a new class:** session is temporary state; category is metadata; common list wrapper is optional; Post stays unchanged.

## How to use this review

1. Decide the **shape of the shared reference/group/member boundary** first.
2. Confirm the compact **Work/Page action targets and menu behavior** within that architecture.
3. Agree the Pixiv and nhentai feasibility spike acceptance criteria, then the compatibility policy.
4. The Zoom Study can continue in parallel; final constants wait for the user's actual Android JSON.
5. Reflect each accepted choice into the parent visual guide and future implementation specs. Do not start broad refactors from candidate diagrams alone.

## Confirmed follow-up decisions and Related discussion (2026-11-06)

These later user decisions supersede unanswered options in the initial six briefs:

- **Design reviews:** Every proposed type/class must show a compact concrete field-and-type sketch with a short description of each field. Avoid type names without their contracts.
- **Work navigation:** Horizontal swiping on the image changes pages inside a Work; horizontal swiping in the details/Overview region changes whole Works. This is the agreed UX direction, still subject to real Android gesture verification.
- **Backup compatibility:** Introduce v10 with typed Group references when needed, continue reading legacy v9, and reject unsupported Group kinds and structural versions in preflight unless lossless opaque round-tripping is explicitly implemented and proven. Do not silently drop records.
- **Pixiv first delivery:** Support Works and their Pages first. Manga Series, Related Works, user-name search, and other Pixiv improvements follow separately; the shared design may anticipate nested Groups without implementing their full UI in phase one.
- **nhentai:** Native anonymous API, tag and CDN behavior awaits the user's controlled live read-only checks. The third-party OpenAPI mirror alone is not operational proof.

### Open: Danbooru Related member order and media-first presentation

**Confirmed in develop:** `RelatedGallery` currently renders members as a `PostGrid` and opens selected Posts in a separate viewer. Its `RelatedPostsOrder.oldest/newest` uses `order:id_asc` or `order:id_desc`. The selected order is retained in per-occurrence `PageStorage` and updated in the global `settings.relatedPostsOrder`, but `RelatedBookmark` contains no per-bookmark order. These are Post-ID sorts, not authoritative narrative sequence.

**Concrete proposal for discussion, not approved:**

```text
RelatedBookmark (extend existing stored model)
  family: RelatedFamilyReference        // existing stable parent/anchor identity
  preferredOrder?: RelatedPostsOrder    // oldest/newest chosen on save; null in old records
  // Preserve existing localId, memberships/addedAt and safe summary/cover fields.

RelatedViewerEntry (extend existing transient occurrence)
  family: RelatedFamilyReference        // existing canonical family
  occurrenceId: Object                  // independent mixed-viewer position
  source: ViewerSourceBinding           // required transient profile authorization, never serialized
  initialPostId?: int                   // selected Post when opened from a Post
  initialOrder: RelatedPostsOrder       // saved preference, else global default
```

Resolve the order at entry opening, update the saved preference if the user changes a bookmarked family's order, and preserve the original selection and family identity. Keep legacy `null` order compatible with the global setting. Do not persist a fixed list of member IDs merely to express ascending/descending sort. Per-bookmark viewing preference is distinct from source-owned Group member order.

**Presentation alternative:** For small Related families, evaluate a media-first horizontal Post pager, with an optional compact Overview or thumbnail strip and family-level Bookmark controls, rather than always opening the current grid/Timeline. Reuse the Pixiv image/details interaction pattern and existing per-Post actions without inventing Work metadata, a fictional description, or a new universal media type. Compare larger families, missing Posts, outer mixed-viewer navigation and restoring the selected Post. Danbooru Related often represents variants rather than authored sequences; never infer true reading order from Post ID.

**Still to decide together:** whether per-bookmark sort is desirable and how its default should be captured; whether media-first should be the Related default or an alternative to the current grid, and whether a small thumbnail Overview is worthwhile. Do not implement these proposals yet.

### Earlier, more detailed material

- [Illustrated entry page](2026-11-04-content-architecture.md)
- [Type, identity and state diagrams](2026-11-04-content-architecture-visual-guide.md)
- [Viewer interaction lab](mockups/2026-11-04-viewer-interaction-lab.html)
- [Full rereview and limitations](2026-11-03-content-architecture-rereview.md)
- [Source feedback / API research](2026-11-04-content-architecture-feedback.md)

All linked source documentation is in English. The discussion can take place in German.
