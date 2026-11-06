# Candidate Content Group Metadata Shapes (Decision 1)

**Status: comparison for joint decision, not approved Dart APIs.** Based on the current Group-contract [Decision 1](2026-11-05-decision-01-shared-group-contract.md). These two alternatives store **identical domain facts**. They differ only in whether lightweight and detail fields have distinct immutable value types.

## A — one progressively enriched `ContentGroup`

```dart
// Conceptual field contract. Not committed runtime Dart.
ContentGroup {
  ContentReference reference;          // required, stable source identity
  String? title;
  GroupCover? cover;
  String? displayCategory;             // source category, not identity
  int? memberCount;
  MemberCountUnit? countUnit;          // posts | pages | works
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
  int? memberCount;
  MemberCountUnit? countUnit;
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

- **Pixiv Work** summary: genuine illustration ID, title, cover, category, known `pageCount`, unit `pages`. Details: caption, Pixiv user ID/name/account/avatar when available, canonical tags, nullable view/bookmark statistics, Series reference only if the API supplies a Series ID.
- **Danbooru Pool** summary: Pool ID, name, category `series|collection`, cover and known post count. Details: description and any real source timestamps. Category changes do not change identity.
- **nhentai Gallery** summary: Gallery ID, English title, thumbnail, page count when supplied and tag IDs. Details: upload date, full tags, known favorites, alternative title and scanlator if supplied. The `PageInfo` media manifest is a **separately loaded member source**, not a field of Details.

## Decision criterion

Pick **B** if list/detail APIs, caches and independent loading are the primary concern. Pick **A** if the extra small type demonstrably complicates existing sources more than it helps. No behavior difference is implied for card versus media-first Work vs Pool timeline UI.

The names and exact nullability still require acceptance before implementation. The final design must validate source identity, privacy, missing data and backup compatibility.
