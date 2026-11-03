# Related families

A Danbooru Related family is one source-scoped parent anchor and its direct
children. `RelatedFamilyReference` is the semantic reference for saved bookmarks,
viewer entries and future timeline grouping. Its `ViewerContentIdentity`
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

Automatic Search/Artist grouping belongs to #134. The optional exact-parent
Search toolbar action is deferred to #115; combined queries are never treated as
a complete unfiltered family.
