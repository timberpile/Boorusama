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

Container-owned state stays outside the post presentation. Examples are a
feed's `NEW` marker and bookmark-group actions.
