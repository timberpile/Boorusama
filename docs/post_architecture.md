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

## Shared post sharing

The Share sheet builds Image from the active viewer URL. Original and Video
use the engine's original-download extractor, which may resolve a different
URL and cookie from the preview stored on the post. Image and Original remain
separate even when their resolved URLs coincide. Media preparation uses the
profile's existing HTTP client and headers. Image and Original use the normal
viewer cache entry for their URL, downloading into that entry on a miss; Android
Copy and Share pass that cached file to the platform with an explicit MIME type.
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
