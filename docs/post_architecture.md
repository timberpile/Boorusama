# Post architecture

Searches, server favorites, bookmarks, and Following Feeds all expose the same
final `Post` runtime type. Shared grids and viewers must consume `Post` directly;
feature-specific wrappers may hold a post, but must not define another post
model.

## Runtime model

`Post` has three parts:

- `PostCoreData` contains engine-neutral media, tags, rating, relationship,
  source, uploader, status, and pagination data used by shared UI.
- `PostOrigin` identifies the producing engine and site without credentials. A
  profile ID is only a hint and is accepted only when its engine and normalized
  host still match.
- `BooruPostData` is a typed engine-owned payload for information and behavior
  that cannot be represented by `PostCoreData`.

API parsers return exact runtime type `Post`. Parser-only `*PostRecord` classes
may be used while normalizing nullable API values, but they must not cross a
repository boundary or be consumed by UI.

## Persistence

`StoredPostSnapshot` is the JSON-safe persistence format. `StoredPostCodec`
owns the versioned common and origin portions, while each engine registers a
`BooruPostDataCodec` for its custom payload. Bookmarks and Following Feeds both
store this snapshot; neither owns a reduced post representation.

Unsupported or malformed custom data preserves the common post data and
decodes to `UnknownPostData`. Legacy bookmark data decodes to `LegacyPostData`
without inventing engine fields. Credentials, repositories, provider state,
callbacks, and controllers are never persisted.

Persistence decoders must accept string-keyed `Map<Object?, Object?>` values
and normalize them before typed access. Hive may rehydrate nested maps with
dynamic key types even when the original snapshot used `Map<String, Object?>`;
non-string keys remain malformed input.

## Presentation and profile resolution

Each engine registers a `BooruPostCapability` containing its codec and
`BooruPostPresentation`. Native presentation is selected only when both the
post origin and typed payload are compatible. The presentation owns
engine-specific grid additions, detail sections, viewer wrappers, and actions;
shared cards and viewers keep engine-neutral behavior.

`PostOriginResolver` resolves the current page independently. It validates an
exact profile hint first, then matches engine and normalized host. Missing or
ambiguous profiles never select an arbitrary account.

Profile-specific listing code must bind the full `BooruConfig` at the
repository boundary, before a post reaches `PostScope`. Parser defaults know
the engine but not the selected host or profile ID; leaving those defaults on
a live post makes multiple profiles for the same engine ambiguous. Use
`originAwarePostRepoProvider` (or explicitly bind custom repository results)
for home, search, favorites, and engine-owned listing pages.

`MixedPostDetailsPage` keeps one controller while `PostPagePresentationScope`
changes the read-only profile and presentation for each active post. It does
not change the globally selected profile. Media resolution is also scoped per
page so adjacent posts from different engines cannot inherit stale settings.

For sites whose listings expose only thumbnails, keep that thumbnail as the
provisional media URL instead of deriving an original path that the listing
cannot prove. The engine presentation may resolve only the post the user opens
and replace it in the existing details controller. Listing metadata marks the
snapshot as unresolved; a successful single-post fetch has no listing metadata
and must not be fetched again. If resolution fails, the provisional thumbnail
remains available.

The ordinary `/details` route keeps one mixed viewer and one details/page
controller for the selected post sequence. When opened from a grid controller,
it also receives an append-only live source: newly loaded `Post` objects extend
the same list held by those controllers, preserving the current page and
source-specific presentation. The grid controller's debounced `fetchMore()`
future resolves after the actual request and filtering complete, and its
loading/error/final state drives the zoomed navigation action. Fixed-list
entry points retain snapshot behavior. The separate `LazyPostDetailsPager`
route is not used for normal grid navigation.

The shared details controller must receive the same swipe mode as the page
viewer. The image transform, not the post swipe mode, determines whether zoom
navigation is needed: Auto Comic and manual zoom both disable page swipes.
The image retains pan and pinch ownership. A single horizontal-dominant drag
can navigate only after reaching the displayed image's left or right clamp
edge and moving a further 96 logical pixels outward; it commits one page on
pointer release. A 30dp hollow progress ring appears at the relevant viewport
edge during a valid pull, reaches full opacity at half progress, and remains
armed at full progress until release. Unavailable actions have no ring; Retry
and Load more use distinct icons and localized semantic labels. The ring does
not intercept touch or depend on toolbar visibility. Vertical scroll,
multi-touch, reversal, and cancellation hide the ring without navigating.
Localized screen-reader custom actions expose the same bounded Previous, Next,
Retry, and Load-more callbacks. A crossing move counts only the distance
left after the image's actual pan reaches its clamp; an initial gesture move
that does not pan the image cannot bank progress. Flutter may deliver several
pointer moves before running microtasks, so a pending move is finalized when the
next move arrives, after the image has applied the earlier pan. The 96-pixel threshold
measures net outward displacement, so small inward corrections cannot add
progress. A cumulative retreat of more than 2 pixels
from the pointer's farthest outward position cancels that drag permanently,
even when the retreat arrives in many small move events. An active drag is
also cancelled when its bounded navigation action or current media state
changes, including a fetch completing while the finger is held. The handoff is
available only after the primary still
image actually decodes; blocked, empty, loading, and failed media placeholders
remain non-navigable even if their viewer transform is zoomed.
Existing desktop navigation controls remain. The usual first/last-page bounds
and pending-load behavior still apply.
Auto Comic fits a qualifying post once per settled page visit, not once per
viewer lifetime: leaving clears the visit guard, so returning re-applies
fit-to-width and top positioning without retriggering on same-page rebuilds.

Thumbnail quality and Post quality are independent. Thumbnail controls show
Auto, Low, Medium and High while preserving listing quality scalars 0/1/2/4.
Auto chooses High for Large, Medium for Medium/Small, and Low for Tiny/Micro
through shared thumbnail settings. Existing Auto GIF animation policy and
Danbooru's GIF variant ladder remain exceptions. Generic thumbnail High uses
Sample with its corresponding aspect ratio; Danbooru keeps its specialized
Highest representation ladder. Engines without intermediate resources may reuse
Original through an existing Sample alias. Historical thumbnail Original (3)
remains a stored compatibility value, without a new selectable option.
Ordinary bookmark grids use the same thumbnail resolver; fixed group covers
retain their existing cover policy.

Details use the separate `PostQuality` presets Medium and High, default High.
Medium retains former High behavior and High retains former Highest behavior;
they may choose the same Sample on engines without another viewer tier.
The `postQuality` JSON key writes explicit scalars 2/4, never enum indexes.
Legacy Auto/Low/High values migrate to Medium; Highest/Original migrate to High.
Missing or invalid values use High, and the dormant legacy full-view key remains
unchanged. Migrated Original is not an automatic Original request. Existing
explicit engine detail overrides, manual Load Original, original-on-zoom,
Share Original, video resolution and download policy remain independent.
Resolver selection matches explicit auth to one enabled stored profile viewer
override, otherwise global viewer settings; it never follows an unrelated
selected profile. Conservative preload rules retain their own policies.
Repositories expose media resolver providers as policy lookups. The consuming
media provider owns their reactive watch; the engine initializer's retained
Ref must not subscribe to viewer/profile state. Otherwise media use adds a
profile dependency to the registry and subsequent login lookup during profile
deletion creates a Riverpod cycle. This applies to default and engine resolvers;
using a read snapshot or disabling debug assertions does not repair ownership.

Still-image upgrades stage the configured network provider until its first
frame decodes, then display that exact provider through the existing controller.
The stage listener stays attached until the display frame attaches, so decoded
images exceeding the RAM cache budget reuse their live stream without another
fetch or decode. Ignored candidates release their handles immediately; terminal
failed candidates evict only their own decoded-cache key, including pending
listeners, while the retained representation and disk payload remain intact.
A decoded lower or previous representation stays visible during transport or
decoder failure. Distinct grid fallback and placeholder URLs are eligible even
when the grid primary equals the target or is empty; candidates are unique and
never duplicate the active target request. Media identity/auth changes clear that retained state. Known
post dimensions determine stable layout; representation ratios are only a
fallback when dimensions are unknown. Actual decoded geometry controls contain
and edge readiness. Cropped previews are never stretched or treated as proof of
full-image edges; tall previews start at the content top so Auto Comic keeps them
visible. A representation replacement cancels a held edge drag even when both
load states are completed; subsequent animation frames do not. Metadata-only
recovery re-evaluates decoded compatibility and cancels held drags only when
that effective compatibility changes, without refetching the image. Arrival of a
compatible full image does not restart Auto Comic or replace the route, page,
controller or transformation matrix.
The production image deduplication interceptor shares success or failure as
completion data, then rejects each failed duplicate through its own Dio request
handler. This preserves normal errors across Dio interceptor error zones and
avoids an unobserved error future when a media request has no duplicates.

A nonempty server page may contribute no visible posts after duplicate or
blacklist filtering. Near the end of the mixed viewer, the route checks the
visible append result after each completed fetch and continues through at most
three such pages per trigger, with a short cooldown. If more pages remain after
that budget, a further outward edge drag or screen-reader `Load more` action
can continue manually. A visible append, fetch error, final page, or route exit
stops the automatic chain; retry and manual continuation use the same grid
fetch path.
If the grid already has a debounced `fetchMore()` pending when the route opens,
the route joins that same Future before deciding whether another page is needed.

Providers that use `ref.watchConfig*` below this per-page scope must declare
the matching `currentReadOnlyBooruConfig*Provider` as a Riverpod dependency.
Providers that watch one of those scoped providers must declare that provider
as a dependency too. Without the complete dependency chain, Riverpod attempts
to read the provider from the root container and asserts at runtime.

When origin or payload resolution fails, the viewer continues with cached
media, common tags and file details, navigation, zoom, download, and sharing.
Engine-only mutations are disabled and a localized reason-specific warning is
shown. A retry action is displayed only when the caller can provide a valid
recovery callback.

For incomplete bookmark snapshots, opening a post runs the caller's existing
recovery callback once per viewer index. The cached presentation remains visible
and its warning is suppressed until that attempt fails; there is no recovery
loading indicator. The callback waits for the bookmark library when it is still
loading on the first frame. Successful recovery updates that page and its stored
snapshot; complete snapshots and unopened group members do not request recovery.
Failed attempts retain manual Retry without an automatic loop on rebuild or
returning to the page.

Container-owned state stays outside the post presentation. Examples are a
feed's `NEW` marker and bookmark-group actions.

## Shared image cache

Ordinary posts, bookmark grids, group previews, viewers and preloading use the
same temporary image cache. Entries use media URLs, so Thumbnail, Sample and
Original have separate entries when their URLs differ. The old durable
`bookmarks/images` directory is neither adopted, migrated nor removed. Removing
bookmarks changes records and memberships without deleting shared media.

The independent image storage limit defaults to 1 GB and shares the existing
video preset/custom controls. Disabled means zero retained image files; image
display and transfer still work. Ordinary post images have no age expiry.
Explicit `cacheMaxAge` remains available for mutable resources: favicons and the
translation status badge opt into one-hour freshness.

The manager journals actual use, including raw and decoded RAM hits and
progressive stage/display resolution, and checkpoints it for restart-safe LRU.
Normal/AVIF/preload misses reserve write ownership before transport; all-cache
and per-key clear invalidate those owners without interrupting decoded pixels.
Cold metadata failure rebuilds readable payloads in memory and retries durable
bookkeeping when storage recovers. Write-only scratch is created lazily, and
optional cache lookup/admission failure leaves network display available.
Final completed-file publication is prepared before destructive retirement,
so a failed generation rename preserves previous bytes and capacity victims.
Status/path/key probes do not count as use. Admission uses completed file sizes,
a shared serialized budget decision and immutable generations. Reader leases
last through the owned bytes copy or platform handoff, rather than widget
lifetime. Clearing and limit reduction retire pinned files until release; their
physical bytes continue to count toward retained occupancy. A writer begun
before clear cannot repopulate the cleared cache. Disabled, oversized and
pin-blocked admissions use separately owned transient files without evicting
otherwise fitting files.

Clearing Images or All caches does not change bookmark records, snapshots or
group memberships. Generic temp clearing excludes manager metadata, active
transfers and platform handoff directories, including when listing fails. The
operating system may still remove temporary files; this is not an offline
availability guarantee.

## Shared post sharing

The Share sheet builds Image from the active viewer URL. Original and Video
use the engine's original-download extractor, which may resolve a different
URL and cookie from the preview stored on the post. Image and Original remain
separate even when their resolved URLs coincide. Media preparation uses the
profile's existing HTTP client and headers. Image and Original use the normal
viewer cache generation for their URL, holding a file lease through handoff and
downloading through a managed write session on a miss. Android Copy and Share
atomically copy completed retained or transient sources into unique owned files
under `boorusama-clipboard` off the UI thread. Only the completed owned URI is
published, with explicit MIME and Share read permission. Sources can then be
cleared without breaking the receiver. Completed owned handoffs expire after
24 hours from completion; repeated copies retain other recent handoffs. Stale
owned staging partials also expire, while process-wide active copy ownership
protects current partials through atomic publication and cleanup.
Video uses separate temporary staging. None of these actions writes to the
durable Save destination or exposes credentials through the shared URI.

For Share Original, a missing stored original URL cannot be satisfied by the
generic `UrlInsidePostExtractor`: its download fallback may select Sample or
Thumbnail. The Original action stays unavailable in that case. An engine
extractor can opt into lazy Original availability through
`ExactOriginalUrlExtractor` only when it resolves an exact upstream original.

For Share Video, a preview-only post is likewise unavailable: the generic
extractor can fall back to a thumbnail for `quality: original`. Share
qualifies a direct video URL by its media extension (or a video-format post
with an extensionless `videoUrl`) and bypasses that fallback. Engines may
implement `ExactVideoUrlExtractor` to keep a genuinely lazy original video
available. A URL appearing in a preview field is rejected only when it has no
independent original/video provenance: E621 and Gelbooru V2 can store the
same full MP4 in both Original and Sample. Non-video extensions remain
rejected.

The Share sheet omits a separate File name row. Original shows dimensions and
file size from the existing post when those values are positive. It shows a
file type only when the stored original URL has a recognized extension that
agrees with the post format. Image shows those same details only when its
viewer-selected URL equals the stored original URL and does not appear in any
sample, thumbnail, or video-thumbnail field. Anime Pictures can store a preview
URL as both Sample and Original while resolving the true original separately;
that Image variant must not inherit original dimensions or size. Missing values
stay hidden. Opening the sheet does not request additional metadata.

Future item 07 coordination must classify Share preparation as media transfer,
not API metadata traffic; this flow defines no new request rate policy.
