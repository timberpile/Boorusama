# Approved content architecture contract

Approved by Timber on 2026-11-06 after the full architecture review. This repository-native contract supersedes conflicting options in earlier design briefs. It is an implementation specification, not a claim of implemented runtime behavior or merge authorization.

Runtime baseline: `e306ff5338a2255a89731c61bd0672336a933344`.
Design baseline: `5c8f6171d40877db4d23d16554f20c454af3648a`.
Read [execution order](README.md) and [local-agent handoff](../../handoffs/content-architecture-local-agent.md).

## 1. Boundaries

Keep the existing real Post, PostCoreData, BooruPostData, StoredPostSnapshot and StoredPostCodec. A Post is one media item, including video/animation. A Group is an addressable source resource containing Post or Group references. Do not add a universal ContentItem superclass, fake Group Posts, parallel Post models, or global pool/work/gallery/series/ordered/unordered kinds.

Reuse the Mixed Viewer, engine registry, origin-aware media, bookmark service, HTTP coordination and Kurumi. Existing Post-only APIs remain Post-only. Only native Group/mixed listings receive a narrow sibling contract. Following Feeds are not rewritten to store Groups. Server favorites remain separate account capabilities.

Keep semantic content identity, validated source address, local Bookmark ID, local Bookmark Group UUID, member occurrence key, outer viewer occurrence and access scope distinct.

## 2. Addressing

```text
ContentKind = post | group
ContentIdentity [Dart record]
  siteNamespace: String                 // normalized host, port and installation path
  kind: ContentKind
  sourceKey: String
ContentReference
  engine: BooruType                     // validated adapter, never authorization
  site: Uri                             // complete validated source installation URL
  kind: ContentKind
  sourceKey: String                     // canonical engine-owned key
  siteNamespace: String [derived]
  identity: ContentIdentity [derived]
ContentKeyCodec [engine interface]
  engine: BooruType
  canonicalize(kind, sourceKey): String
  keyForPost(post): String?
  postIdFor(sourceKey): PostId           // existing PostRepository bridge
ContentReferenceCodec
  parse(engine, site, kind, sourceKey): ContentReference
  fromPost(post): ContentReference?
  encode(reference): Map<String, Object?>
  decode(value): ContentReference
```

Semantic identity excludes engine to preserve existing Post bookmark matching. Full reference equality includes engine, complete normalized site URI, kind and key. Access caches additionally include account/policy. Validate compatible engine/resource/payload interpretation before deduplication; incompatible collisions fail preflight rather than silently selecting a winner.

Reuse normalizePostSourceHost and BoorusamaPostLink validation. Preserve HTTP-only installations, non-default ports, relevant paths and deployed normalization semantics; never reduce identity to Uri.host or rebuild every locator as HTTPS. Reject user-info, fragments, invalid escapes, unsupported schemes and unsafe paths. An imported locator alone grants no request permission.

Preserve deployed Post keys exactly: id:123, source-owned Sankaku string IDs, Pixiv work-page:120:2. New Group fixtures use pool:42, related:42 and work:120; later key grammars remain engine-owned. A Pool category change never changes pool:42. No guessed aliases: #43 remains separate. A local Bookmark integer is never an upstream identity.

Construct references through validated factories/codecs in a valid Dart library. Do not copy a private constructor into a separate inaccessible library from a sketch. Legacy Posts with no provable stable identity stay renderable and retained but are omitted from the semantic dedup index; never invent a key from a URL/hash.

## 3. Metadata

```text
ContentGroupSummary
  reference: ContentReference            // group only
  title?: String
  cover?: GroupCover
  memberCount?: int                     // direct source members, not visible/loaded count
  displayCategory?: String              // display fact, not identity or capability
  previewTags?: GroupTags               // source-owned tags or IDs
  sourceData?: BooruGroupSummaryData
ContentGroupDetails
  summary: ContentGroupSummary          // same Group, no duplicate ID
  description?: GroupDescription
  creators?: List<CreatorRef>            // null unknown; [] known empty
  tags?: GroupTags                      // not a sampled member-tag union
  sourceDates?: GroupSourceDates
  sourceData?: BooruGroupDetailsData
GroupCover
  thumbnail: Uri
  sample?: Uri
  original?: Uri                        // only when identified as original by source
  width?: int
  height?: int                          // this representation's geometry
  representedPost?: ContentReference    // real underlying Post, if known
  variants: Map<String, String>
GroupDescription
  text: String
  format: GroupTextFormat               // plainText | dtext | html
GroupTags
  values: List<GroupTag>
  coverage: MetadataCoverage            // unknown | partial | complete
GroupTag
  sourceId?: String
  name?: String                         // canonical tag, not translated display text
  category?: String
  displayName?: String
CreatorRef
  displayName: String
  sourceKey?: String
  account?: String
  avatar?: Uri
  sourceUrl?: Uri
GroupSourceDates
  createdAt?: DateTime
  publishedAt?: DateTime
  updatedAt?: DateTime                   // source facts, not local save dates
BooruGroupSummaryData / BooruGroupDetailsData [separate interfaces]
  typeKey: String
  schemaVersion: int
BooruGroupDataCodec [one engine registration]
  encodeSummary(data), decodeSummary(value)
  encodeDetails(data), decodeDetails(value)
```

Use immutable values, defensive decoding and existing Hive string-keyed Map<Object?, Object?> normalization. Missing remains unknown; zero means known zero. Reject negative counts/invalid geometry. Summary refresh cannot erase cached Details. Adapters distinguish omission from an authoritative deletion; do not universally null-coalesce every update. Sanitize/render supported markup using existing components.

memberCount counts direct Works in a Series or Pages in a Work, never grandchildren; presentation supplies localized units. No stored countUnit/isOrdered flag. No invented Related title, creator or description. No speculative generic statistics map.

```text
PixivWorkSummaryData
  workType: PixivIllustType
  typeKey = pixiv.work.summary; schemaVersion = 1
PixivWorkDetailsData
  totalViews?: int
  totalBookmarks?: int                  // source metric, not account bookmark state
  aiType?: int
  series?: ContentReference             // relationship only, no Series rollout
  typeKey = pixiv.work.details; schemaVersion = 1
NhentaiSummaryData
  mediaId: String                       // distinct from Gallery identity
  typeKey = nhentai.gallery.summary; schemaVersion = 1
NhentaiDetailsData
  alternateTitles: Map<String, String>
  scanlator?: String
  favoriteCount?: int
  typeKey = nhentai.gallery.details; schemaVersion = 1
```

Engines with no real extras use null, not empty payload classes. Credentials, current-account favorite/privacy state, profile settings and provider state do not enter reusable metadata. Metadata saved offline never proves another account currently has remote access.

## 4. Members, hydration and paging

```text
GroupMember
  reference: ContentReference
  memberKey: String                     // membership occurrence in this Group
  sourcePosition?: int                  // zero-based shared position
  availability: MemberAvailability      // unknown | available | unavailable
ContentEntry [sealed boundary union]
  reference: ContentReference
PostContentEntry
  reference: ContentReference
  post: Post                            // real existing Post object
GroupContentEntry
  summary: ContentGroupSummary
  reference: ContentReference [derived]
ContentCursor
  token: String                         // transient, adapter-validated
ContentPage<T>
  items: List<T>
  next?: ContentCursor                  // null only for source exhaustion
  total?: int
GroupMemberBatch [Dart record]
  page: ContentPage<GroupMember>
  resolved: List<ContentEntry>           // already fetched/parsed media or summaries
GroupMemberQuery
  reference: ContentReference
  orderKey?: String
  cursor?: ContentCursor
  requestedLimit?: int                  // hint, not response-size guarantee
```

Do not collapse member occurrences just because they share content identity. Prefer native membership keys; where unavailable, duplicate ordinals belong to a manifest generation. Native page numbers stay in engine keys/payloads while sourcePosition is zero-based. Missing Page 2 never renumbers Page 3. Related sort does not invent authored sourcePosition. Availability is access-scoped; timeout is a request error, not permanent absence. Placeholders must not leak blocked content metadata.

Separate Details/member methods do not require separate HTTP requests. Share access-scoped single-flight envelopes/manifests and pass their real Posts in resolved. Pool adapters batch missing IDs and restore authoritative order after out-of-order responses. Summary cards must not fetch every Details/Member list.

Do not relax PostResult<T extends Post>. Use ContentPage only at new Group/mixed list boundaries. Continue using raw source cursor progress when filtering yields zero visible items. Bound automatic continuation, detect stalled cursors, offer manual retry/load. Validate remote next URLs against endpoint, source, query and access. Nested Groups form a graph; phase one tests references only. Future traversal needs cycle/depth/request bounds, not eager recursion.

## 5. Source, access, registration and state

```text
ContentAccessKey
  engine: BooruType
  siteNamespace: String
  profileId?: String                    // null only for explicitly allowed public context
  authEpoch: int                        // revision, never token or credential hash
  policyEpoch: int
ContentAccessContext
  key: ContentAccessKey
  baseUrl: Uri                          // actual authorized endpoint
  config?: BooruConfig                  // transient, never serialized here
GroupLoadKey
  reference: ContentReference
  access: ContentAccessKey
  orderKey?: String                     // member requests only
ContentGroupSource
  access: ContentAccessContext
  loadSummary(reference): TaskEither<BooruError, ContentGroupSummary>
  loadDetails(reference): TaskEither<BooruError, ContentGroupDetails>
  loadMembers(query): TaskEither<BooruError, GroupMemberBatch>
BooruGroupCapability
  engine: BooruType
  keyCodec: ContentKeyCodec
  dataCodec?: BooruGroupDataCodec
  createSource(access): ContentGroupSource
  presentation: BooruGroupPresentation
BooruGroupPresentation [UI boundary only]
  supports(summary): bool
  layoutFor(summary): GroupLayout       // memberGrid | mediaPager
  memberLabel(context, summary): String
  buildCard(...), buildDetails(...)
GroupMembersState
  members: List<GroupMember>
  resolved: Map<ContentIdentity, ContentEntry> // within this access scope only
  next?: ContentCursor
  sourceTotal?: int
  firstPageLoaded: bool
  loadingMore: bool
  nextPageError?: BooruError
  generation: int
GroupMembersController [manual AsyncNotifier family]
  build(GroupLoadKey)
  loadNext(), retryNext(), refresh()
```

Adapt PostOriginResolver, ViewerSourceBinding and existing engine dispatch; no second profile system or competing registry. Profile hints are not authorization. Validate source/account/effective policy before accepting responses/actions; never switch the global profile or borrow an arbitrary account. Keep credentials out of keys/logs. Anonymous policy is implemented by #143, not invented in metadata codecs.

Metadata caches exclude member order; member caches include it; both include access/policy. Cancellation uses existing API coordination and stale generations. Initial failure uses AsyncValue; next-page failure retains members and cursor. Reject late responses after disposal, refresh, order/auth/policy changes. Retain bounded caches and incremental indexes.

Use pinned Riverpod 2.6.1 manual providers, no code generation or dependency upgrade. The method sketch is a contract, not a second generic network framework. Reuse current error, HTTP pacing, cancellation and media-cache infrastructure.

## 6. Viewer and actions

```text
ViewerEntry [existing, adapted]
  occurrenceId: Object
  source: ViewerSourceBinding?
  contentReference: ContentReference?   // legacy unaddressable media may lack it
PostViewerEntry
  post: Post
GroupViewerEntry
  summary: ContentGroupSummary
  initialMemberKey?: String
ViewerMediaBinding
  occurrenceId: Object                 // outer entry owning selected media
  memberKey?: String                   // null for ordinary Post
  post: Post
  access: ContentAccessContext
GroupViewerState [media-first stage only]
  occurrenceId: Object
  selectedMemberKey?: String
  mode: GroupViewMode                  // image | overview
  detailsScrollOffset: double
```

Keep outer ViewerEntrySequence occurrence-based and append-only. Work Pages stay within their Work. Repeated Works have independent selected Page/mode/scroll/transform state. Grid/loading/error Groups have no active Post. Clear the old binding before enabling another target. Reuse the real Post media/controller/scope instead of a second nested fullscreen viewer.

Image swipes select Pages; horizontal details/Overview swipes change outer Works. Do not cross a Work boundary inadvertently from its image pager. Retain zoom/pinch/pan, zoom-edge navigation, animation/video, accessibility, text selection and existing configured gestures. No two-finger Work skip. Image View/Overview retain the same selected media and reading position. Viewer Controls on Open applies once per viewer session.

Use the agreed Pixiv Image View/Overview mockups and later action geometry decisions, never the rejected Related mockup. Existing Related grid/timeline plus ordinary Post viewer remain unchanged.

Capture action targets before awaits: normal local Bookmark = Work; hold/overflow = Work or Current Page; normal Download = Page; explicit Download All = bounded actual member media; Work/Page portable links are separate in the existing Share Sheet. Native source link stays Work-level where appropriate. Hold chevron is decoration inside existing button bounds: no moved/shrunk glyph, changed padding, extra hit target or duplicate tap after hold. Provide overflow/semantics alternatives. No remote Pixiv favorite writes in #140/#141, no universal command bus.

## 7. Unified Bookmarks

```text
Bookmark [abstract interface]
  id: int
PostBookmark implements Bookmark [rename existing Bookmark]
  id: int
  snapshot: StoredPostSnapshot
  createdAt: DateTime                   // compatibility baseline, not first-ever history
  updatedAt: DateTime                   // snapshot replacement
  post: Post [existing decoded view]
ContentGroupBookmark implements Bookmark
  id: int
  snapshot: StoredGroupSnapshot
  createdAt: DateTime
  observedAt: DateTime
  sourceProfileHint?: String            // non-authorizing hint
  reference/summary [derived]
RelatedBookmark extends ContentGroupBookmark
  preferredOrder?: RelatedPostsOrder    // validated Related family only
BookmarkGroup
  id: String                           // existing UUID
  name: String
  folderId?: String
  position: int
  bookmarkIds: Set<int>                 // all Bookmark kinds
  addedAt: Map<int, DateTime>            // sole membership-date authority
StoredGroupSnapshot
  schemaVersion: int                    // initially 1, separate from backup v10
  summary: ContentGroupSummary
  details?: ContentGroupDetails         // already loaded export-safe metadata
  index?: GroupBookmarkIndex
GroupBookmarkIndex
  tags: Set<String>
  basis: GroupTagIndexBasis             // sourceGroup | memberUnion
  coverage: MetadataCoverage
  oldestMemberUpload?: DateTime
  newestMemberUpload?: DateTime
  coverPolicy?: String                  // non-secret existing visibility digest
StoredGroupCodec
  encode(snapshot): Map<String, Object?>
  decode(value): StoredGroupSnapshot
```

Offline policy approved: retain Summary and already loaded export-safe Details; never fetch solely to bookmark. Do not implicitly store member lists, Page snapshots, media bytes, credentials/account flags or controllers. Serialize Summary once. Failed refresh preserves the last valid snapshot without advancing observedAt. Existing policy checks still govern saved content and covers.

Keep sampled member-union tags separate from native Group tags. Preserve strict local filtering and indexed member-upload ordering, unknown values and safe covers; do not invent Group scores. Replace synthetic id-0 cover Posts with only the rendering descriptor needed.

One compatible identity maps to one saved Bookmark with multiple memberships. Work and Page are independent. After cutover no Group-bookmark groupIds/addedAt authority remains. Reverse membership indexes derive from BookmarkGroup. Default retains its UUID, All remains a view, and last-membership removal uses existing reversible deletion without deleting shared media.

Related order is the only saved Group viewing preference. Capture on first save, update only that saved family on an explicit change, fall back to global for null/legacy records, preserve through refresh/duplicate-group/Undo/backup. No generic GroupBookmarkViewOptions or arbitrary manual order.

```text
BookmarkLibraryState
  byId: Map<int, Bookmark>
  idByContent: Map<ContentIdentity, int>
  groups: Map<String, BookmarkGroup>
  folders: List<CollectionFolder>
  revision: int
  membershipsByBookmarkId: Map<int, Set<String>> [derived/incremental]
BookmarkIdAllocator
  reserve(count): Future<List<int>>
  nextId: int [internal durable high-water mark]
BookmarkRepository
  readAll(): Future<List<Bookmark>>
  read(id): Future<Bookmark?>
  upsert(bookmark): Future<void>
  delete(id): Future<void>
  durableSync(): Future<void>
BookmarkLibraryService / BookmarkLibraryNotifier [existing, generalized]
  savePost(...), saveGroup(...)
  addToGroup(bookmarkId, groupId), removeFromGroup(...)
  updateGroupSnapshot(bookmarkId, snapshot), setRelatedOrder(bookmarkId, order)
  duplicateGroup(...), deleteGroup(...), undo(...), snapshotForExport()
```

Preserve BookmarkMutationRepository write-through deltas, ambiguous-write invalidation, shallow immutable reuse and existing performance tests. Generic membership uses local IDs; media operations explicitly need PostBookmark. Do not decode everything on a small mutation.

Existing Post payload storage may remain. A private Group payload store is allowed behind one repository, kind index and durable allocator. Replace every autonomous Box.add/addAll Post creation/import path together. IDs include zero, are never recycled, may have gaps, and must be durably reserved before publication. Recover ambiguous reservation failures before allocating again. Backup/import IDs cannot lower the local high-water mark. No competing counters or dual membership authorities.

## 8. Migration, backup and links

```text
BookmarkMigrationPlan [temporary implementation value]
  fromLocalSchema: int
  toLocalSchema: int
  oldCollectionIdToNewId: Map<String, int>
  targetGroups: List<BookmarkGroup>
  targetGroupBookmarks: List<ContentGroupBookmark>
  reservedUpperBound: int
  sourceRevision: String
```

Preserve Post IDs/snapshots, local Group UUIDs/folders and every addedAt. Map each Collection UUID once. Incompatible collisions/malformed references fail before destructive writes. Reuse import journaling, durable sync, revision checks and restart recovery, not just in-memory rollback.

Activation: validate revision; reserve IDs; persist recovery plan; stage records and unified memberships; validate all references/dates/counts; sync; switch local schema/generation; reload providers; then retire old authority. Startup must recover or block editing, never expose partial data. Local schema version is independent of backup version.

Keep .bsexport and v4-v9 readers. Write validated v10 with one tagged Bookmark array, file-local IDs and unified memberships/dates. Wire post/group/related discriminators describe Bookmark payloads, not additional ContentKinds. Preserve Post snapshot format and UnknownPostData behavior. Unknown structural versions/new Group key/payload codecs fail whole preflight; unsupported network access alone does not. No silent partial import/export.

Preserve Merge, Merge Into, Update, Replace, group duplication and Default semantics. Map file IDs to local IDs through validated compatible identity. Retain v9 timestamp reconstruction without inventing first-save history. Preserve existing Post/Page portable URIs and the v1 .bslink envelope; new Group URI grammar is strict and carries no local IDs/auth/membership/private snapshot. Old recipients may reject it safely.

## 9. Scope and discretion

Implementation helpers, focused file splits, exact envelopes and constructor placement are engineer decisions backed by tests. The approved semantics are not reopened. Reuse existing equivalent types instead of adding unused abstractions for symmetry.

Escalate only unavoidable data loss, incompatible source semantics, required API failure, unsafe access or an uncovered user-visible decision. No redesign of Related, no Manga Series UI, remote Pixiv writes, advanced artist search, host-alias migration, full offline Group downloads or general manual order in this rollout.

No PR, develop/master merge, issue closure, release or unrelated branch integration is authorized by this contract. Follow the handoff's per-issue branches, testing and independent final review gates.
