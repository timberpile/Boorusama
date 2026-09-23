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
