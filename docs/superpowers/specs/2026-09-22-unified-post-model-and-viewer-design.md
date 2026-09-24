# Unified Post Model and Mixed-Booru Viewer

## Intent

Posts should have the same presentation and behavior regardless of whether the
user reaches them through a normal search, server favorites, local bookmarks,
or a Following Feed. A viewer may contain posts from multiple profiles and
booru engines. Swiping to a new post must switch to that post's engine-specific
data, media rules, controls, and interactions without leaving the viewer or
changing the app's globally selected profile.

This design replaces the separate reduced bookmark and feed post models with a
single runtime `Post` model. Engine-specific data remains typed and owned by
the engine. Serializable snapshots are a separate storage representation, not
a second runtime post hierarchy.

The abandoned `feature/feed-post-rendering-parity-investigation` branch is not
an implementation base or a validated dependency. Its notes may be consulted
for requirements, but every relevant observation must be verified against the
current source before use.

## Current State

`Post` is currently an abstract contract containing the common getters used by
listing and viewer code. `SimplePost` supplies storage for those common fields,
and simpler engines extend it. More specialized engines such as Danbooru,
e621, Philomena, Sankaku, and Szurubooru implement `Post` directly and add
their own fields.

This creates three problems:

1. Common data storage is duplicated between engine post classes.
2. Bookmark and feed persistence discards engine-specific data, then rebuilds
   reduced `BookmarkPost` and `CachedFeedPost` objects with invented defaults.
3. Generic UI is nominally typed as `T extends Post`, but engine widgets look
   up exact contexts such as `InheritedPost<DanbooruPost>` and
   `PostDetails<DanbooruPost>`. A heterogeneous list therefore cannot safely
   use the native engine UI.

The result is visible drift: the same upstream post can have different
overlays, quick actions, media selection, details, and interactions depending
on the screen from which it was opened.

## User-Visible Contract

- Search, server favorites, local bookmarks, and feeds use the same post card
  and post viewer presentation.
- A viewer accepts an ordered `List<Post>` containing any mix of supported
  profiles and engines.
- Swiping between engines is continuous. The current page selects the correct
  profile configuration, viewer layout, media resolver, gestures, detail
  sections, and server-backed actions.
- The app's globally selected profile is not changed by a mixed viewer.
- A valid stored snapshot renders immediately without requiring a network
  fetch. Server-backed state and mutations still use the network as usual.
- If native reconstruction or origin resolution fails, cached media remains
  usable and the viewer shows a localized warning plus safe generic UI.
- Container-specific state remains visible without changing the post itself.
  Examples include a feed's `NEW` marker and bookmark group actions.

## Runtime Domain Model

### Post

`Post` becomes the single concrete runtime model used across the application.
It retains convenient top-level getters such as `post.score` and
`post.originalImageUrl` so general UI does not need to reach through nested
objects for every value.

Conceptually it contains:

```dart
class Post extends Equatable {
  const Post({
    required this.origin,
    required this.core,
    required this.booruData,
  });

  final PostOrigin origin;
  final PostCoreData core;
  final BooruPostData booruData;
}
```

The implementation may delegate the existing `Post` getters to `core`. The
end state has no engine-specific subclasses of `Post` and no persistent
`BookmarkPost`, `CachedFeedPost`, or `UniversalPost` runtime types.

Preview-only or workflow-specific objects, such as theme demo data or upload
draft state, should construct or contain a `Post` rather than introduce a new
listing post hierarchy.

### PostOrigin

`PostOrigin` identifies the engine and the local profile that produced the
post without storing credentials. It contains:

- the stable booru engine type;
- the booru identifier already used by bookmark identity and engine matching;
- a normalized source base URL or host;
- an optional local profile ID hint.

Resolution first uses the profile ID only when its engine and host still
match. It then matches engine type and normalized host. If multiple profiles
remain ambiguous, the app must use the generic fallback instead of choosing an
arbitrary account for a destructive server action. Profile IDs are hints and
are not assumed to survive backup restore on another installation.

### PostCoreData

`PostCoreData` stores the engine-neutral data required by shared listing,
media, filtering, download, share, and basic details behavior. It covers the
current `Post` contract and the generally useful optional capabilities that
are currently spread across mixins and side interfaces:

- upstream post ID and creation time;
- thumbnail, sample, original, video, and video-thumbnail URLs;
- media variants and per-media aspect ratios when supplied;
- width, height, format, MD5, file size, duration, and sound state;
- full tags and optional artist, character, and copyright tag sets;
- rating, score, downvotes, comment and translation indicators;
- parent/child relationship state and parent ID;
- uploader ID and name, source, normalized status, and search metadata.

Missing optional source data remains absent. Code must not invent a false,
zero, or unknown value merely to fill a field. Parsing external data continues
to treat every nullable value explicitly.

### BooruPostData

`BooruPostData` is an extensible interface implemented by typed engine payloads
such as `DanbooruPostData`, `E621PostData`, and `PixivPostData`. Runtime code
does not pass raw JSON maps as engine data.

Each payload contains only information that cannot be expressed faithfully in
`PostCoreData`. Examples include:

- Danbooru vote totals, favorite count, approver, categorized general/meta
  tags, variant metadata, pixel hash, and detailed moderation state;
- e621 species/lore/invalid tags, description, source list, favorite state,
  and typed video variants;
- Pixiv illustration identity, page position, user data, series, AI marker,
  restriction state, and illustration kind;
- Szurubooru tag details, pool membership, own-favorite state, and aggregate
  counts.

An `UnknownPostData` or `LegacyPostData` payload represents a post whose
engine-specific snapshot cannot yet be reconstructed. It is a deliberate
fallback state, not a partially forged engine payload.

## Storage Model and Codecs

### StoredPostSnapshot

Persistence uses a separate, JSON-safe `StoredPostSnapshot`; it does not
implement or extend `Post`.

```dart
class StoredPostSnapshot {
  final PostOriginSnapshot origin;
  final Map<String, Object?> common;
  final Map<String, Object?> custom;
  final int codecVersion;
}
```

The common portion has a versioned, engine-neutral schema. The custom portion
is owned and versioned by the engine codec. Credentials, provider state,
repository instances, callbacks, controllers, and other runtime objects are
never stored.

### BooruPostCodec

Every registered image-post engine provides a typed codec responsible for:

- constructing the engine's `BooruPostData` from API data;
- encoding that payload into a JSON-safe custom map;
- decoding supported payload versions;
- rejecting malformed or unsupported payloads without throwing through the
  listing or viewer UI.

Every codec must satisfy a round-trip contract for all meaningful fields:

```text
API result -> Post -> StoredPostSnapshot -> Post
```

Unknown newer codec versions preserve the common snapshot and produce generic
fallback presentation. They must not cause the entire bookmark or feed cache
to be discarded.

### Bookmarks

A bookmark becomes a library record around a stored post snapshot:

```dart
class BookmarkEntry {
  final int localId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final StoredPostSnapshot post;
}
```

Bookmark groups continue to refer to local bookmark IDs. Existing membership,
identity, import-conflict, scoped-export, removal, and rollback semantics do
not change as part of this work.

### Feed Cache

Following Feeds persist the same `StoredPostSnapshot` instead of a separate
`CachedFeedPost` schema. Feed ownership, source membership, ordering,
retention, `NEW` state, refresh checkpoints, history, and pagination semantics
remain unchanged.

### Backup Compatibility

New bookmark exports use backup version 2 and contain bookmark timestamps plus
the stored post snapshot. Group objects retain their current shape and
file-local bookmark references.

Version-1 bookmark backups remain importable through one localized adapter:

```text
legacy bookmark fields -> PostCoreData + LegacyPostData -> BookmarkEntry
```

The importer does not guess missing engine-specific fields. A later successful
native refresh may replace `LegacyPostData` and persist a complete snapshot.
New exports are not dual-written in the old format.

Existing on-device Hive bookmarks must be migrated on app upgrade even if
backup compatibility changes later. If version-1 backup support unexpectedly
requires cross-cutting compromises beyond the codec boundary, it may be
removed after explicit review; local data migration remains required.

## Engine Registry and Presentation

Each engine registers a post capability composed of two independent parts:

- `BooruPostCodec` owns typed data conversion and persistence.
- `BooruPostPresentation` owns grid and viewer presentation for a compatible
  payload.

The central post code does not contain a switch over every engine. The engine
registry resolves the capability from `PostOrigin`. Before building typed UI,
the presentation validates the payload type. A mismatch returns the generic
presentation rather than causing a cast failure.

### Shared Grid Presentation

All post-listing entry points use the same shared card renderer. Common data
drives image quality, aspect ratio, explicit-content handling, video/GIF,
translation, comments, relationships, AI, sound, duration, score, tag preview,
selection, and generic gestures.

The engine presentation supplies optional additions such as moderation
overlays, native quick-favorite controls, or other engine-only card behavior.
The enclosing feature may add its own orthogonal decoration, such as `NEW` or
a bookmark group affordance, without replacing the shared post renderer.

### Shared Mixed-Booru Viewer

The shared viewer accepts an ordered `List<Post>` and owns one stable page,
overlay, zoom, video, details-sheet, and slideshow controller. It does not nest
one complete native viewer inside another page view.

When the current page changes, the viewer resolves a presentation context
containing:

- the current `Post` and validated typed payload;
- its matched local `BooruConfig` when available;
- engine-specific UI builders and wrapper behavior;
- media URL and aspect-ratio resolution;
- layout, viewer, gesture, download, and authentication configuration;
- repository-backed actions and supporting providers.

The current read-only booru configuration is overridden within the viewer's
local provider scope. This lets existing engine widgets read the correct
profile without updating `currentBooruConfigProvider`, settings, or the home
screen's selected account. Page media builders receive their own explicit
configuration so adjacent pages remain correct while swiping.

The current exact-type `InheritedPost<T>` and `PostDetails<T>` boundary is
replaced by a non-generic post/details context. Engine widgets read the common
`Post`, then obtain their validated typed payload through their presentation
or a typed engine extension. Engine-specific UI must never assume that every
post in the surrounding viewer list belongs to its engine.

Normal search and server-favorite pages use this same viewer. Engine-specific
viewer pages become thin entry points or are removed once their wrappers and
presentation behavior have moved into the engine capability.

## Data Flows

### Search and Server Favorites

1. The engine client returns nullable external DTO data.
2. The engine parser creates `PostCoreData` and its typed `BooruPostData`.
3. The repository returns `Post` objects.
4. The shared grid and viewer select the registered engine presentation.

These posts do not require serialization unless another feature stores them.

### Bookmark Creation and Opening

1. Bookmark creation encodes the selected `Post` into a
   `StoredPostSnapshot` and writes a `BookmarkEntry`.
2. Opening the library decodes snapshots into the same runtime `Post` used by
   search.
3. A valid typed payload renders native presentation immediately.
4. A legacy or invalid payload may be refreshed through the matched profile's
   post repository.
5. Successful refresh replaces the in-memory post and updates the stored
   snapshot without changing the bookmark's local ID or group memberships.

### Feed Refresh and Opening

1. Existing refresh adapters return runtime `Post` objects.
2. The feed service stores snapshots for the bounded retained cache.
3. Opening a feed decodes snapshots without making per-card network requests.
4. The shared card and viewer use the same engine presentation as search.

This work does not make an unsupported engine feed-capable.

### Mixed Viewer Page Change

1. The page controller selects the next `Post` by stable list position.
2. Origin resolution finds an unambiguous matching profile.
3. The engine registry validates the payload and returns its presentation.
4. The local configuration scope and details UI switch to that presentation.
5. Account state providers load under the selected post's profile.
6. The global app profile and the ordered viewer list remain unchanged.

## Failure Handling

The generic presentation plus a localized warning is used when:

- no compatible local profile can be resolved;
- profile resolution is ambiguous;
- the engine is unavailable;
- the custom codec version is unsupported;
- custom data is malformed;
- a legacy post cannot be refreshed;
- the upstream post has been removed or a refresh fails.

The fallback preserves common media, tags, metadata, swipe navigation, zoom,
download, share, and other safe generic behavior when their required data is
available. A retry action is offered when an origin can be resolved. One
failed post does not remove, reorder, or block adjacent posts.

A valid snapshot does not fall back merely because the device is offline.
Static native details remain available from the typed payload. Server-backed
actions use existing loading and error behavior and must not optimistically
claim a known state when it has not been loaded.

## Migration and Delivery Strategy

The implementation may use temporary adapters internally to keep intermediate
commits testable, but the delivered architecture has one runtime `Post` model.
The migration should proceed in dependency order:

1. Introduce origin, core data, typed payload, snapshot, codec, and registry
   contracts with contract-test helpers.
2. Migrate engine parsers and payloads, preserving all current fields.
3. Replace exact generic post/details contexts and build the mixed viewer.
4. Extract the shared grid presentation and migrate normal search.
5. Migrate server favorites, bookmarks, and feeds to `Post`.
6. Add Hive and backup migration, then remove reduced and obsolete post types.
7. Complete full automated and live Android verification.

If a migration step reveals that an engine cannot preserve its current
behavior through these contracts, the design must be amended rather than
silently falling back for that engine.

## Verification

### Model and Codec Tests

- A shared contract suite covers every registered image-post engine.
- Round trips preserve every common and engine-specific field.
- Missing nullable data remains absent.
- Unsupported and malformed custom payloads retain common data and select the
  generic fallback.
- Post origin matching covers exact profile, restored profile, ambiguous
  profile, removed profile, and mismatched host cases.

### Persistence and Migration Tests

- Existing Hive bookmark rows migrate without changing local identity or
  group membership.
- Version-1 backups import bookmarks and legacy group shapes.
- Version-2 backups round-trip full snapshots and groups.
- Feed snapshot round trips preserve ordering, retention, membership, and
  `NEW` behavior.

### Presentation Tests

- The same `Post` receives the same shared card semantics in search,
  favorites, bookmarks, and feeds.
- Engine additions appear only for compatible payloads.
- A mixed sequence including Danbooru, e621, Pixiv, and a fallback post changes
  toolbar, details, media rules, overlays, and provider configuration on each
  swipe.
- Actions call repositories with the current post's origin profile, never the
  globally selected or previous page's profile.
- Zoom, load-original, video playback, details sheets, slideshow, back
  navigation, and scroll-position restoration survive engine boundaries.
- One failed post remains viewable and does not prevent navigation.

### Repository Validation

Run focused model, codec, bookmark, feed, favorites, listing, and details tests;
then run `fvm flutter analyze`, the full `fvm flutter test`, and
`git diff --check`.

Use Maestro on the available Android emulator with existing signed-in test
profiles. The live scenario bookmarks or otherwise assembles posts from more
than one engine, opens the mixed viewer, swipes across the boundary, and
visibly verifies different engine-specific overlays and actions. Credentials
remain in `.test_credentials` and must not appear in fixtures, logs,
screenshots, issues, or reports.

## Non-Goals

- Adding new booru actions or engine capabilities.
- Adding feed support to engines that cannot currently refresh feeds.
- Changing feed refresh, history, checkpoint, ordering, retention, or `NEW`
  semantics.
- Changing bookmark group membership, removal, conflict, or scoped-export
  semantics.
- Automatically downloading all bookmark or feed media for offline use.
- Persisting credentials, provider state, or other runtime objects.
- Treating the abandoned feed-rendering branch as mergeable implementation.

## Acceptance Criteria

- All supported post-producing entry points expose the single runtime `Post`
  model.
- No shipped listing/viewer path depends on `BookmarkPost`, `CachedFeedPost`,
  or a persistent `UniversalPost` runtime representation.
- Search, favorites, bookmarks, and feeds use the shared card and viewer
  presentation contracts.
- A single viewer can swipe through different booru engines and uses the
  correct typed data, profile, UI, media behavior, and interactions on every
  page.
- Valid snapshots work without a network fetch; incomplete posts fail softly
  to generic UI with a localized warning and retry where possible.
- Existing local bookmarks and version-1 bookmark backups remain importable,
  subject to the deliberately localized compatibility boundary above.
- Automated and live verification demonstrate behavior without regressing
  bookmark groups or feed semantics.
