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

### Accepted: retain the existing Related Gallery, persist only its own order

**Confirmed in develop:** `RelatedGallery` currently shows a `PostGrid` and opens an ordinary Post viewer. Oldest/newest correspond to `order:id_asc` and `order:id_desc`; the order is currently only a global preference plus transient occurrence state. The existing `RelatedBookmark` is a subclass of `CollectionBookmark`, not a new type to introduce.

**User direction:** Keep the current Related grid/timeline and ordinary Post viewer for the initial group-architecture integration. Do **not** build or ship the proposed separate media-first Related viewer/Overview or an alternate Timeline-overflow switch yet. A later UI experiment must start from the actually agreed Pixiv Work designs and established Post Details sheet, rather than independent illustration-driven mockups.

Store the chosen member order **only for saved Related families**, not as a generic Content Group viewing option:

```text
RelatedBookmark (existing type; add a field on the current model or its future equivalent)
  family: RelatedFamilyReference        // canonical parent/anchor identity
  preferredOrder?: RelatedPostsOrder    // saved oldest/newest for this family; null for legacy records
  // All existing local group memberships, added dates and summary data remain.
```

On first save, capture the current visible order. When opening a saved family, use its own order; when opening an unsaved or legacy family, fall back to the global preference. Explicitly changing the order of a saved family updates only that family. Preserve the order across metadata refresh and backup import/export. Do not persist a fixed list of member IDs just to express the sort direction. Post IDs are not guaranteed story chronology, so no automatic inference of authorial sequence is claimed.

### Open proposal: a unified local Bookmark contract and membership model

**Current code:** `Bookmark` represents a saved Post with an automatically allocated Hive `int` ID; `BookmarkGroup.bookmarkIds` and `addedAt` reference those Post IDs. Existing `CollectionBookmark` stores Pool/Related entries separately in the organization store using a UUID `localId` and its own `groupIds`/`addedAt`. This historical compatibility design is not a Flutter limitation; adding more Group bookmark families should not automatically duplicate it.

**User question for joint architecture review:** Would one generic `Bookmark` interface, one local integer ID namespace, and one group membership mechanism better express the product, while retaining typed Post and Group data?

**Concrete candidate, not an approved Dart API:**

```text
Bookmark (abstract interface)
  id: int                              // unique stable local bookmark ID, not a source ID

PostBookmark implements Bookmark
  id: int                              // retain existing Post bookmark ID
  snapshot: StoredPostSnapshot        // existing full Post snapshot
  createdAt: DateTime                  // original local creation
  updatedAt: DateTime                  // last snapshot update

ContentGroupBookmark implements Bookmark
  id: int                              // allocated from the same local ID namespace
  reference: ContentReference          // stable engine/source/kind/key
  summary: ContentGroupSummary         // stored offline-safe Group summary
  createdAt: DateTime                  // local creation date
  observedAt: DateTime                 // last successful metadata observation

RelatedBookmark extends ContentGroupBookmark (specialized existing concept)
  preferredOrder?: RelatedPostsOrder    // only for Danbooru Related families

BookmarkGroup (extend existing structure)
  id: String                           // local group UUID, unchanged
  name: String                         // user-visible group title
  folderId?: String                    // local organization
  position: int                        // display order
  bookmarkIds: Set<int>                // local IDs of Post AND Group bookmarks
  addedAt: Map<int, DateTime>          // group-specific membership date per local bookmark ID
```

Common bookmark classification here describes the persisted **bookmark**, not a new universal superclass for `Post` and `ContentGroupSummary`. Post media APIs keep their specialized Post types. Preserve lazy snapshots, indexes, and efficient large-library mutations.

**Existing timestamp semantics (verified against develop):** `Bookmark.createdAt` is initially assigned when a Post is saved and acts as a fallback for missing per-group `BookmarkGroup.addedAt` dates and local Added sorting. Upload sorting instead uses `bookmark.post.createdAt`. `Bookmark.updatedAt` changes when the stored Post snapshot is replaced (`upgradeBookmarkSnapshot`), is retained through storage/backup, and is not a normal sort key. In v9 backup, the Post record encodes `updatedAt` but not its own `createdAt`; importing reconstructs `createdAt` from the earliest membership timestamp, which can differ from the original first save. `CollectionBookmark.observedAt` instead records the last metadata observation. Proposed `Bookmark` interface should expose only the local ID until a cross-type common field is demonstrably needed; keep type-specific update/observation timestamps. The user favors unification but final ID migration and persistence contracts remain under discussion.

**Migration/feasibility constraints:** Existing Post IDs must remain stable. Collection UUIDs and content identities require a lossless mapping to new integers, including undo/import/backup and per-group `addedAt`. Hive Post writes currently use `Box.add()`; that allocator must not collide with Group IDs. A shared durable allocation strategy or equivalent storage layout is needed before claiming one integer namespace. Backup v9 remains readable and v10 changes are preflight-validated and transactional; never drop Group members or merge a Page bookmark into a Work bookmark.

A narrower fallback is a typed local ID (old Post integer vs Group UUID) behind the same Bookmark interface and group-membership contract; it avoids ID reallocation but is less uniform. Decide whether the extra migration cost of global integer IDs is warranted before implementation.

### Earlier, more detailed material

- [Illustrated entry page](2026-11-04-content-architecture.md)
- [Type, identity and state diagrams](2026-11-04-content-architecture-visual-guide.md)
- [Viewer interaction lab](mockups/2026-11-04-viewer-interaction-lab.html)
- [Full rereview and limitations](2026-11-03-content-architecture-rereview.md)
- [Source feedback / API research](2026-11-04-content-architecture-feedback.md)

All linked source documentation is in English. The discussion can take place in German.
