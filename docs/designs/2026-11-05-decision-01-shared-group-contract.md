# Decision 1 — Minimal Shared Content Group Contract

**Status:** Research and recommendation for discussion. Not an approved Dart API or implementation.
**Baseline:** `develop` at `e306ff5338a2255a89731c61bd0672336a933344`. Android first. Complete current stabilization before architecture rollout.

## One-minute explanation

**Keep Post as one media item. A Group is an addressable source object that points to Posts or other Groups.** We need common addressing, member loading and display integration; we do not need a new root `ContentItem` hierarchy or to make all groups look like the same screen.

Examples:

- Danbooru Pool 42 (display category **Series** or **Collection**) contains independent Post IDs 100 and 101.
- Pixiv Work 120 contains its own ordered Page-Posts, e.g. `work-page:120:0` and `work-page:120:1`.
- Pixiv Manga Series 9 contains **Works**, each of which contains Pages.
- nhentai Gallery 800 contains image pages. `gallery` is the source's term, not a new core UI class.
- A local Boorusama Bookmark Group organizes saved content; it is **not** a remote Content Group.
- Pixiv Related Works are recommendations, **not** members of a Work. Danbooru direct parent/children are a different relationship.

## Proposed smallest boundary

| Role | Recommended realization | Necessity |
| --- | --- | --- |
| `ContentReference` | Immutable validated portable address: engine, normalized source namespace, stable **resource kind**, opaque stable key | **New shared value** |
| `ContentGroupSummary` | Lightweight card data: reference, optional title/cover, optional count **with unit**, presentation category and known/unknown metadata | **New shared value**, or a compatible existing summary adapted to it |
| `GroupMember` | A member reference plus immutable source position/key and availability; may hold already loaded Post/summary | **New small value** if a reference alone cannot express source order/missing members |
| Group source capability | Engine adapter: load one group's metadata, a bounded ordered/paged batch of members, and supported actions | **New narrow interface**, not a generic content repository rewrite |
| `Post` | Existing Post, media providers, downloads, snapshots | **Keep unchanged** |
| `ViewerEntry` | Existing transient occurrence in the Mixed Viewer | **Extend existing model**, not persisted group identity |
| Member paging | Existing compatible paginated result container with next cursor/completeness | **Reuse** instead of mandating `GroupMemberPage` |
| Group session | Existing Riverpod/controller request state keyed by reference, access and scope | **State, not a separate domain entity** |
| Group presentation | Composition of existing Kurumi/Danbooru cards, toolbar and details sections | **Reuse**, do not introduce a general UI framework |
| `ContentListEntry` | Optional union at a genuinely mixed list boundary, with Post and Group variants | **Only if needed**; no blanket `List<Post>` replacement |

**Not prescribed as new standalone classes:** `ContentIdentity` (usually derived from validated reference), `ContentGroupDetails` (can be progressively loaded metadata), `GroupSession` (controller state), `GroupPresentation` (UI composition), `ContentItem` (conceptual term).

A minimal sketch, **not final Dart signatures**:

```text
ContentReference(engine, siteNamespace, resourceKind, stableKey)
         |                         |
         |                  access binding (not persisted)
         v                         v
ContentGroupSummary       Engine Group Adapter
         |                  load metadata / members
         +----> GroupMember(reference, sourcePosition, availability)
                         |
                         +----> Existing Post or another Group
                         |
                  Existing Mixed Viewer + Kurumi UI
```

## The boundaries that matter

**Resource identity is not a display badge.** A Danbooru Pool keeps its Pool ID when its `series`/`collection` category changes. Both currently use `DanbooruPool`. The category still influences certain features (automatic Series grouping). The verified reference key must distinguish resource classes with overlapping IDs where a source requires it, not source-specific labels as an arbitrary global hierarchy.

**Source namespace is not only `Uri.host`.** Keep normalized host, relevant port and installation path. Canonical aliases require a verified mapping, as scoped in [Recognize Verified Booru Host Aliases (#43)](https://github.com/timberpile/Boorusama/issues/43). An alias must never grant another profile's credentials.

**Access is independent.** A profile or anonymous read-only context is resolved when opening. It must not be serialized into the content key or reused across authenticated/private caches. Profile changes invalidate incompatible sessions.

**One content may occur multiple times.** Viewer occurrence IDs, originating list positions, scroll state, temporary paging and local group membership dates are separate from source identity.

**Positions must survive gaps.** A missing Pixiv page 1 does not rename page 2. Source positions and original IDs stay stable after filtering and pagination. Unknown member availability must not be rendered as a fake `Post`.

**Group metadata is not the entire group.** Card summary may be available without members; a manifest may be partially loaded; a known page count is not a proof that the media is accessible. A group can include mixed nested resources without eagerly downloading a whole hierarchy. Source-specific tags and tag coverage are not necessarily unions of all member tags.

**UI is compositional, not dictated by resource kind.** A Danbooru Pool can retain header/description/grid. A Pixiv Work can show media first with artist and details below. nhentai can share the group/member contract and common controls without being a special base class. Source APIs/adapters must not return Flutter Widgets.

**Listing and viewer are different boundaries.** Native gallery search returns Group cards; it cannot be squeezed into the existing `SearchPageScaffold<T extends Post>` by inventing fake Post IDs/media. A mixed listing may use the optional union, while Post-only screens remain Post-only.

## Loading profiles

| Source | Member strategy | Key handling |
| --- | --- | --- |
| Danbooru/Szurubooru Pool | Known independent IDs, batched Post requests | Preserve original source order |
| Danbooru Related | Bounded parent/child listing | Real direct-family identity; not recommendation |
| Pixiv Work | Work detail plus image-page manifest | Existing `work-page:<id>:<zeroBasedIndex>` remains valid |
| Pixiv Manga Series | Paged ordered Work references | Do not flatten all works/pages into one list |
| nhentai Gallery | Detail manifest plus media/CDN resolver | Preserve `PageInfo.number` and validate its indexing |
| Local Bookmark Group | Locally dated membership of references/posts | Keep existing v9 dates; not a remote adapter |

## What is already real vs proposed

**Real in develop:** `Post`, synthetic Pixiv page Posts with a stable Work/Page key, `ViewerEntrySequence` with Post and Pool entries, `CollectionBookmark` with strict Pool/Related serialization, v9 per-group membership dates, engine-specific Pool routes. **Proposed:** shared ContentReference/Group summary/member interface and native group listings.

**Against a giant rewrite:** Existing Post-only downloads, favorites, snapshotted Posts and image grids are extensive. Introducing one universal `ContentItem` superclass would force unrelated consumers to handle non-media content.

**Against separate engine implementations:** Duplicating lifecycle, missing-member handling, bookmarks and route navigation for Pixiv/nhentai creates drift.

## Acceptance examples for a technical design review

- Same Post belongs to two Pools; same Work appears twice in one viewer with independent occurrences.
- Pool category changes from Collection to Series without changing its saved identity.
- A Series contains Work references; a Work can be opened before all siblings load.
- Page 2 remains Page 2 if Page 1 is missing or restricted.
- Anonymous and account A cannot share restricted cached data with account B.
- Two installations under one hostname but different installation paths remain distinct.
- Partial group summaries can render without fetching members.
- Group search results are not fake Posts.
- New group references can be backed up and shared without changing local membership dates.

## Proposed decision

Approve **three small shared data values (reference, summary, member)** and **one engine-group adapter capability** as a *design direction*, while reusing all appropriate existing Viewers, Riverpod sessions and paging containers. Allow optional mixed list entries only for actual mixed native results. Decide concrete Dart names and field nullability during the implementation design after stabilization.

**Still discuss:** Whether a separate `GroupMember` value is necessary for all engines, or only for groups with positions/unavailable members; whether a source-key resource discriminator is global or engine-registered. No runtime work should begin before these boundaries are agreed.

### Evidence

- [Current mixed viewer entries](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/posts/details/src/types/viewer_entry.dart)
- [Current Pool/Related bookmark serialization](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/core/bookmarks/src/types/pool_bookmark.dart)
- [Current Pixiv Post identity](https://github.com/timberpile/Boorusama/blob/e306ff533/lib/boorus/pixiv/posts/post_data.dart)
- [Danbooru Pools API](https://safebooru.donmai.us/wiki_pages/api%3Apools)
- [Technical Visual Guide](2026-11-04-content-architecture-visual-guide.md)
