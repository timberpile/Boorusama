# Candidate Content Group Metadata Shapes (Decision 1)

**Status: comparison for joint decision, not approved Dart APIs.** Based on the current Group-contract [Decision 1](2026-11-05-decision-01-shared-group-contract.md). These two alternatives store **identical domain facts**. They differ only in whether lightweight and detail fields have distinct immutable value types.

## Latest decision direction (2026-11-06): choose B and support typed engine payloads

The user prefers **two loading stages**, matching the data already available in search/list responses versus a separate detailed content request. The user also explicitly requires **engine-specific extension fields**, analogous to the existing `Post.booruData` pattern. Variant A remains below for comparison, not as a second implementation to build.

**Both `ContentGroupSummary` and `ContentGroupDetails` are common application values usable by Danbooru Pools, Pixiv Works/Series, nhentai Galleries and other sources.** They must NOT become giant classes containing all site-specific fields. A field absent from the source is optional/unknown, not an invented zero or empty item. An adapter maps each source's list/detail DTOs into the appropriate common stage plus typed source payload.

### Recommended minimal shape (design sketch, not finalized Dart)

```text
ContentGroupSummary
  reference: ContentReference                // durable engine + source + kind + key
  title?: String                              // known summary title
  cover?: GroupCover                         // thumbnail/media reference and safety
  int? memberCount;                          // direct members only (12 Works OR 5 Pages)
  displayCategory?: String                    // e.g. Danbooru Series/Collection
  previewTags?: GroupTagPreview               // only if source lists provide them
  sourceData?: BooruGroupSummaryData          // typed Pixiv/Nhentai/Danbooru extension

ContentGroupDetails
  summary: ContentGroupSummary               // same source group, no duplicate ID
  description?: String
  creators?: List<CreatorRef>
  tags?: GroupTags                            // source-owned and coverage-aware
  sourceDates?: GroupSourceDates
  sourceData?: BooruGroupDetailsData          // typed engine-specific detail extension

GroupMemberSource (separate from both)
  load members/continuation
  preserve stable source position, unavailable members, access binding
```

The `BooruGroupSummaryData` and `BooruGroupDetailsData` names are **candidate contracts**, not necessarily two required public interfaces for every engine. They can share the equivalent of `BooruPostData`'s `typeKey`/`schemaVersion` and typed codec strategy if persistence requires it. Avoid a generic unvalidated JSON map in the UI and do not make engines define empty payload classes when no extra fields exist.

| Source | Common summary | Optional summary payload | Common details | Optional detail payload |
| --- | --- | --- | --- | --- |
| Danbooru Pool | ref, title, cover, Post count, Series/Collection badge | Source-only pool ordering/filter metadata if exposed | description, supported tags/dates | Engine-defined Pool facts only when needed |
| Pixiv Work | ref, title, cover, Page count, type badge | Work kind and source-specific preview flags | caption, creator reference, Work tags | Series **ID**/relationship, AI indicator or richer Pixiv-only fields |
| Pixiv Manga Series | ref, title, cover, **Work** count | Source-specific Series summary fields | synopsis/author, if supplied | Source pagination/order facts, separately from member loader |
| nhentai Gallery | ref, title, thumbnail, Page count, tag ID previews | `media_id` or other source ID needed for source resolution, safe metadata | source tags, upload date, known favorite statistics | alternative titles, scanlator, source-specific details |

**Do not persist account-scoped state in an otherwise reusable group value.** For example, Pixiv `isBookmarked`/Public-Private state belongs to the authenticated account state/capability layer, not a global static Summary. Likewise, image URLs are media references, not stable group keys. Preserve credentials/privacy boundaries in caches.

**An API's list/detail DTO is not the same thing as a persistent domain value.** When the detail API already provides enough fields, the adapter may construct a Summary from it; no extra list request is needed. Detailed members remain independently fetched even if a detail response includes a page manifest.

**Current implementation reference:** `Post.booruData` uses `BooruPostData` with a `typeKey`, `schemaVersion` and typed codec, plus an `UnknownPostData` fallback for unsupported custom versions. The Group equivalent should follow this pattern where it materially reduces lost engine information, rather than copying every Post abstraction mechanically.

**Remaining design choices:** precise common field minimum; whether both loading stages require separately typed payload interfaces or a single versioned source value; which extra fields must survive offline Bookmark snapshots; provenance/unknown states for counts and tags. The choice of **two common stages with typed source extensions** is the accepted direction.

## A — one progressively enriched `ContentGroup`

```dart
// Conceptual field contract. Not committed runtime Dart.
ContentGroup {
  ContentReference reference;          // required, stable source identity
  String? title;
  GroupCover? cover;
  String? displayCategory;             // source category, not identity
  int? memberCount;                   // direct members only; null means unknown
  GroupTags? tagPreview;               // can be ID-only or partial
  MetadataKnowledge metadataKnowledge;

  String? description;
  List<CreatorRef>? creators;
  GroupTags? tags;                     // names, IDs, types, coverage
  SourceGroupStats? statistics;        // source-defined metric labels
  GroupSourceDates? sourceDates;
  ContentReference? parentSeries;
  EngineGroupData? sourceExtras;       // typed engine-specific values
}
```

Advantages: one model for lists and details; simple call sites. Costs: many irrelevant/unknown fields in search results, and an update to a partial summary must not accidentally discard fetched details. Load status must still be tracked separately.

## B — two immutable data values

```dart
ContentGroupSummary {
  ContentReference reference;
  String? title;
  GroupCover? cover;
  String? displayCategory;
  int? memberCount;                   // direct members only; null means unknown
  GroupTags? tagPreview;
  MetadataKnowledge metadataKnowledge;
}

ContentGroupDetails {
  ContentGroupSummary summary;         // same group identity
  String? description;
  List<CreatorRef>? creators;
  GroupTags? tags;
  SourceGroupStats? statistics;
  GroupSourceDates? sourceDates;
  ContentReference? parentSeries;
  EngineGroupData? sourceExtras;
}
```

Advantages: a bounded search/list request returns only the summary; opening can fetch Details independently; optional source values do not fill every lightweight result. Fits both Pixiv and nhentai's separate list/detail HTTP responses. Costs: one additional small value type and a reference to the summary in Details.

**Preferred candidate:** B. No separate, mandatory `ContentGroup` superclass, no new session-domain type, and no request to load all members when loading details. Two values are not two different *kinds of group*.

## Direct member count: one field, one meaning (agreed 2026-11-06)

Use **only `int? memberCount` for direct members**. A Pixiv Manga Series reports its number of **Works**, and a Pixiv Work reports its number of **Pages**. A Danbooru Pool reports Posts; an nhentai Gallery reports Pages. Do not put an aggregate descendant page count into the common Series Summary or display it as an alternative `pageCount`. This count is source-authoritative, not the number of currently loaded members. `null` means unknown and `0` means confirmed empty.

The UI derives the label (Works, Pages, Posts or generic Items for a mixed/unknown member type) from the source/group's supported direct member kind, rather than storing another count or a redundant `countUnit` field in Summary. If one source exposes aggregate statistics about descendants, they belong in explicitly optional engine-specific detail information and are not a second common member-count property.

```text
Pixiv Manga Series: memberCount = 12   → 12 direct Works
     ├─ Pixiv Work A: memberCount = 5  →  5 direct Pages
     └─ Pixiv Work B: memberCount = 8  →  8 direct Pages

Danbooru Pool: memberCount = 22        → 22 direct Posts
nhentai Gallery: memberCount = 180     → 180 direct Pages
```

## What the nested values actually contain

| Value | Concrete proposed shape and source examples |
| --- | --- |
| `ContentReference` | `engine`, normalized `siteNamespace` (host+port+installation path), `resourceKind` (`pool`, `work`, `manga-series`, `gallery`, `related-family`), validated stable `sourceKey`. Never credentials. |
| `GroupCover` | Optional media/thumbnail URL or existing media reference, optional aspect ratio and safe-display/cover policy. Not a canonical identity. |
| `GroupTags` | Source tag ID, canonical name when resolved, source tag type, known/unknown coverage. `tagPreview` can be a subset or ID-only; detailed tags need not be the union of every member's tags. |
| `CreatorRef` | Known source user/artist ID, display name, account handle and optional avatar URL; no forced network fetch per result card. |
| `SourceGroupStats` | Typed source-defined counts such as Pixiv `totalViews`/`totalBookmarks` or nhentai `numFavorites`. Preserve the correct label; unknown is not `0`. |
| `GroupSourceDates` | Nullable source creation, publication/upload and update timestamps when actually available; not local Bookmark membership time. |
| `EngineGroupData` | Typed source-specific extras when needed, e.g. nhentai scanlator/alternative titles or a source-specific ordering metadata field. Avoid an unvalidated generic JSON bag in shared UI. |
| `MetadataKnowledge` | Field/section provenance and known/partial/unknown coverage; does **not** substitute the separate transient loading/error state in Riverpod. |

## What is **not** stored in either model

- `GroupMember` list or network continuation cursor. Load these independently and keep source positions/availability stable.
- Saved local Bookmark-Group IDs and per-membership `addedAt` values. They belong to the local Bookmark library.
- Current profile, token, anonymous source access, private cached account state, or a viewer occurrence ID.
- Open sheet state, current image index, animation controllers or scroll position. These belong to transient viewer state.
- Related recommendations returned by a separate API. These are **not** current Group members and can fail independently.

## Worked examples, without inventing source values

- **Pixiv Work** summary: genuine illustration ID, title, cover, category, known direct `memberCount` (Pages). Details: caption, Pixiv user ID/name/account/avatar when available, canonical tags, nullable view/bookmark statistics, Series reference only if the API supplies a Series ID.
- **Danbooru Pool** summary: Pool ID, name, category `series|collection`, cover and known post count. Details: description and any real source timestamps. Category changes do not change identity.
- **nhentai Gallery** summary: Gallery ID, English title, thumbnail, page count when supplied and tag IDs. Details: upload date, full tags, known favorites, alternative title and scanlator if supplied. The `PageInfo` media manifest is a **separately loaded member source**, not a field of Details.

## Decision criterion

Pick **B** if list/detail APIs, caches and independent loading are the primary concern. Pick **A** if the extra small type demonstrably complicates existing sources more than it helps. No behavior difference is implied for card versus media-first Work vs Pool timeline UI.

The names and exact nullability still require acceptance before implementation. The final design must validate source identity, privacy, missing data and backup compatibility.
