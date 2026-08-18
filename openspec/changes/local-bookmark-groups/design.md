## Context

The existing local bookmark feature stores complete post snapshots in a Hive box named `favorites`. `BookmarkHiveObject` records are read by `BookmarkHiveRepository`, while `BookmarkNotifier` exposes bookmark state to post controls and the bookmarks page. Existing bookmarks are globally available and already retain their booru identity, source URL, post ID, image URLs, tags, and metadata.

The existing `FavoriteRepository` abstraction is for server-backed favorites and is implemented separately by each booru integration. Danbooru favorite groups are also server-backed and Danbooru-specific. Local groups therefore belong in the core bookmark domain rather than in a Gelbooru or Danbooru repository.

See `proposal.md` for motivation and `specs/local-bookmark-groups/spec.md` for the behavior contract.

## Goals / Non-Goals

**Goals:**

- Add global local group membership without changing the meaning of server favorites.
- Preserve all existing bookmarks as ungrouped bookmarks after upgrading.
- Support multiple memberships, group-specific removal, and explicit complete deletion.
- Keep group selection and management within the existing bookmarks experience.
- Make the active bookmark target available to post buttons and thumbnail context menus.
- Preserve enough membership state to render the active-group icon and total-group count without requiring network access.

**Non-Goals:**

- No synchronization of local groups to any booru server.
- No changes to Danbooru's server-side favorite groups.
- No booru-specific group scope in the first version.
- No booru-host filter in the group selector; the existing bookmark filtering can be extended separately later.

## Decisions

### Use a separate local group and membership store

Store named groups and bookmark-to-group memberships separately from the existing bookmark records:

- A group record contains its local identifier and display name.
- A membership record contains a group identifier and the Hive key of a bookmark record.
- The absence of membership records means that a bookmark is `Ungrouped`.
- `All Bookmarks` and `Ungrouped` are virtual views rather than deletable group records.

This is preferred over adding group IDs directly to `BookmarkHiveObject`. It avoids rewriting the existing bookmark schema, lets older application versions ignore the new boxes, and makes group deletion a membership operation rather than a mutation of every post snapshot. The bookmark Hive key is used for the relation because it is already the stable local identifier exposed as `Bookmark.id`; booru post IDs are not globally unique.

The group repository is responsible for pruning memberships whose bookmark keys no longer exist. Group duplication creates a new group and copies membership records, never bookmark records.

### Keep bookmark existence separate from membership

The bookmark repository remains responsible for creating, updating, and deleting local post snapshots. A group repository manages named groups and memberships. A coordinated bookmark operation will:

1. Create the bookmark when necessary.
2. Add or remove the requested membership.
3. Refresh the in-memory bookmark and membership state.

If a new bookmark cannot be assigned to the requested group, the operation should remove the newly created bookmark so a failed add does not leave an unexpected orphan. Removing the final named membership does not delete the bookmark; it becomes visible in `Ungrouped`. Complete deletion is a separate explicit operation that removes the bookmark and every membership.

### Represent the active target separately from the displayed view

The bookmarks page needs a selected view (`All Bookmarks`, `Ungrouped`, or a named group) and the application needs a persisted active add/remove target. Selecting a named group updates both. Selecting `All Bookmarks` changes only the displayed view and leaves the target unchanged. Selecting `Ungrouped` sets the target to the special ungrouped state.

The active target is stored in the existing local settings mechanism. If a saved group no longer exists, the target falls back to `Ungrouped`. The target label is rendered below the bookmark button so a single tap is understandable even when the user is viewing `All Bookmarks`.

`Ungrouped` is a creation/default state, not a named membership that can coexist with named memberships. A post with named memberships must not have those memberships silently cleared by an action targeting `Ungrouped`; the user must remove memberships explicitly or delete the bookmark completely.

### Make bookmark controls membership-aware

The bookmark state exposed to widgets will include, or provide access to, the set of named group IDs for each local bookmark. The existing `isBookmarked` behavior remains available for general bookmark-page and deletion checks, while the post controls additionally derive:

- whether the bookmark belongs to the active named target;
- the total number of named groups containing it; and
- whether it is ungrouped.

The main icon is filled when the bookmark belongs to the active target. A small count badge shows the total number of named groups whenever the bookmark belongs to at least one named group other than the active target. Long press opens the group picker and updates the persisted target; selecting a newly created group also adds the current post to it.

When the active target is `Ungrouped`, a new post can be saved without memberships. Existing grouped posts are not converted to ungrouped by a single tap.

### Replace the thumbnail bookmark action with a dedicated section

The general post and Danbooru thumbnail context menus will retain unrelated actions and separate bookmark actions with a horizontal divider. The local bookmark section will expose:

- `Add to...`, including named groups and `Create new group...`;
- `Add to <active target>` when the target is a named group and the post is not a member;
- `Remove from...`, listing applicable named memberships;
- `Remove from <active target>` when the target is a named group and the post is a member; and
- `Delete bookmark completely`, with confirmation.

The existing local `Add to bookmark` item is removed. Danbooru's server-side `Add to favorite group` action remains a separate server feature and is not replaced by the local bookmark section.

### Make group deletion explicit about orphaned bookmarks

Deleting a group first calculates:

- memberships that will be removed; and
- bookmarks whose only named membership is the group being deleted.

The confirmation presents the affected counts and offers two explicit outcomes: keep those bookmarks as `Ungrouped`, or delete them. Keeping orphaned bookmarks is the safer default. Bookmarks belonging to another group are retained in that group regardless of the selected outcome.

### Integrate group filtering into the existing bookmarks page

The existing bookmark-page fetch/filter flow will load the local groups and memberships, then apply the selected group filter before the existing tag, source, and sort behavior. The group selector and group-management actions belong near the current bookmarks app bar and source selector. Group operations invalidate the bookmark page and membership state so counts and visible results update immediately.

## Risks / Trade-offs

- **Risk:** Membership and bookmark records can become inconsistent after an interrupted multi-step write. → **Mitigation:** centralize coordinated mutations in a repository/service, make new-bookmark assignment compensating, and prune stale memberships during load.
- **Risk:** A large group deletion may require many membership or bookmark writes. → **Mitigation:** batch Hive operations where supported, show progress for large destructive operations, and refresh state only after the operation completes.
- **Risk:** Older app versions do not understand local group boxes. → **Mitigation:** keep group data in separate boxes and avoid changing existing bookmark fields; document that using an older version during an active migration is unsupported if it can remove local data.
- **Risk:** The active target can become confusing when the user views `All Bookmarks`. → **Mitigation:** persist the target intentionally, leave it unchanged when selecting `All Bookmarks`, and display its label below the bookmark button.
- **Risk:** A count badge can be misread as the number of groups other than the active group. → **Mitigation:** define and test it as the total number of named groups containing the bookmark.

## Migration Plan

1. Register the new local group and membership persistence types without modifying existing bookmark records.
2. Treat every existing bookmark with no membership record as `Ungrouped`.
3. Initialize the active target to `Ungrouped` when no valid saved target exists.
4. Deploy the group selector, group-management UI, membership-aware bookmark controls, and context-menu actions.
5. During normal reads, remove membership records that reference deleted bookmark keys or missing groups.
6. If the feature is rolled back, existing bookmarks remain readable because their storage format is unchanged; newly created group data is ignored by older code and can be removed by a later cleanup.
