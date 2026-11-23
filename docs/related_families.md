# Related families

A Danbooru Related family is one source-scoped parent anchor and its direct
children. `RelatedFamilyReference` is the semantic reference for saved bookmarks,
viewer entries and timeline grouping. Its `ViewerContentIdentity`
contains the engine, normalized source namespace, `related` kind and positive
anchor ID. A child uses its positive parent ID; a parent uses its own ID.
References never follow later reparenting or traverse grandchildren.

`RelatedViewerEntry` adds a separate occurrence ID and transient source binding.
Repeated families retain independent navigation and viewport positions. The
Danbooru viewer capability renders a compact, lazy Post grid for `parent:N`, with
the existing floating navigation header. Members open the ordinary Post viewer;
Back retains the outer index and gallery viewport. Selection suspends outer
swipes and keyboard navigation. A missing parent, singleton or inaccessible
family does not invalidate the reference. An empty accessible result offers
Retry without making any deletion claim.

The Related-only timeline order defaults to Oldest (`order:id_asc`); Newest uses
`order:id_desc`. The shared `Settings.relatedPostsOrder` preference survives normal
Settings persistence and backup/restore. Missing or invalid values use Oldest.
New occurrences read that preference, while existing occurrences retain their
own order and viewport through Back and eviction. Changing order saves first,
then clears selection, resets scrolling and replaces the page controller; old
requests cannot publish into the new controller. A failed save retains the
visible order and content and reports a localized error.

The gallery bookmark action uses the shared Kurumi anchor and observes membership
by canonical family identity, including removal and Undo. Related card context
menu actions use a Kurumi dialog because their trigger disappears. Related cards
have no title or reserved title space; their type/count semantics remain. Source
icons and type badges share 24 dp footprints, 16 dp type icons, 4 dp overlay
insets and a 4 dp gap.
The tile's existing 2 dp outer padding is separate from these overlay insets.

## Bookmark organization and compatibility

`CollectionBookmark` shares the existing reference metadata, membership,
selection, filtering, sorting, refresh and Undo machinery. `PoolBookmark` retains
its Pool identity and JSON shape. `RelatedBookmark` stores `kind: related` and
`anchorId`, never a Pool ID. Both live in the existing organization box's
`poolBookmarks` list; the legacy storage key and service method names are kept
to avoid a parallel repository or unnecessary data migration. No member lists
or member Post snapshots are stored. Individually bookmarked Posts remain
independent of their family reference.

Bookmark exports use version 7. Imports still accept versions 4, 5 and 6;
Related rows require version 7. Other versions and unknown reference kinds are
rejected before import. Group/folder scoping and merge/copy/replace use the same
reference organization pipeline. Reference identities, local IDs and memberships
are validated before import mutations. Exception rollback restores all reference
variants with Posts and organization, and reports rollback failures. It does not
guarantee recovery from a process crash between writes.

Source/profile hints are separate from semantic identity. Saved Related
references require their bound profile; imported unbound references keep local
metadata but cannot borrow another account, including a sole account on the same
host. Viewer bindings reject changed authorization or visibility contexts.
Pending picker writes recheck the exact source and mounted picker before saving.

## Bounded metadata

Showing a Related bookmark card does not load its family. Opening the picker for
a new reference or explicitly refreshing metadata uses one request for at most
40 Posts through the existing source-bound repository. The Danbooru producer
already makes an exact-count request for `parent:N`: the total budget is one Post
request plus that count request, without extra probes or pagination. Concurrent
consumers in the same authorization context share the provider request.

Only direct, visible members contribute tags and static cover variants. The
source profile's blacklist, rating and deleted/banned restrictions apply. Tag
coverage remains complete, partial or unknown. Counts remain unknown when the
producer cannot establish them. Upload extrema are stored only when every member
and every upload date is known. A failed refresh preserves the saved summary;
new offline references can be saved with unknown metadata. Covers follow the
existing visibility-policy check and never resolve using an unrelated profile.

## Timeline grouping

Browse, Search, Artist, and Topic Feed timelines use the shared grouping projection.
When Related grouping is enabled, an eligible Danbooru Post with verified
parent/child evidence represents its direct family, including a singleton.
Later direct-family members join
that card regardless of distance or appended page. The first thumbnail, position,
and viewer occurrence remain stable; every member retains its original raw index.
Series keeps its five-result lookahead and priority for unfrozen results. Late
metadata never steals a built ordinary, Related, or Series card.

Appearance settings and Timeline View Options offer **Group Related Posts**.
Both edit the same persisted global preference, which defaults OFF and survives
query, source/profile, controller, Selection Mode, and viewer/Back changes.
OFF expands only Related families and restores their individual Related thumbnail
icons; Series remains grouped. Changing the preference does not refetch or modify
the raw list. Selection and explicit family/Series searches always show raw Posts.
Preference changes restore a visible raw member's scroll anchor where practical,
including under pinned headers, and preserve frozen Series representatives.

Related badges show an access-valid cached full-family total when known; otherwise
they show only the Related icon. There is no fallback count, placeholder, ratio,
or extra count request. Tapping still opens the full accessible family gallery.
The family registry is reconstructed from raw Posts and frozen entries on each
projection and is never persisted or shared across timelines.

Browse uses the same projection and bounded Series membership admission as
Search. Mobile trend-tag selections and applied desktop queries update the
grouping session; explicit family/Series queries remain raw.

Topic Feeds resolve Series membership from optional feed-local cached metadata.
Opening a cached feed or changing the Related preference makes no Post or Series
requests. Refresh backfills missing Series metadata; failures preserve loaded
Posts. Older history still requires explicit continuation. Series cache entries
remain source/account scoped and are excluded from backups and sharing.

See the [approved #134 handoff](handoffs/134-related-one-card-group-posts-toggle-2026-11-18.md)
and the revised [global preference](handoffs/134-global-related-grouping-2026-11-18-results.md)
and [Topic Feed](handoffs/134-topic-feed-grouping-2026-11-18-results.md) implementation notes.
The [Browse follow-up](handoffs/134-browse-grouping-verification-2026-11-18.md)
records the missing home-route connection in `e6ccbfbee` and its regression coverage.
The optional exact-parent
Search toolbar action is deferred to #115; combined queries are never treated as
a complete unfiltered family.
