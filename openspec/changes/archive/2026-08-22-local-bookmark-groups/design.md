## Context

The existing local bookmark feature stores complete post snapshots in a Hive box named `favorites`. `BookmarkHiveObject` records are read by `BookmarkHiveRepository`, while `BookmarkNotifier` exposes bookmark state to post controls and the bookmarks page. Existing bookmarks are globally available and already retain their booru identity, source URL, post ID, image URLs, tags, and metadata.

The existing `FavoriteRepository` abstraction is for server-backed favorites and is implemented separately by each booru integration. Danbooru favorite groups are also server-backed and Danbooru-specific. Local groups therefore belong in the core bookmark domain rather than in a Gelbooru or Danbooru repository.

See `proposal.md` for motivation and `specs/local-bookmark-groups/spec.md` for the behavior contract.

## Goals / Non-Goals

**Goals:**

- Add global local group membership without changing the meaning of server favorites.
- Preserve all existing bookmarks as ungrouped bookmarks after upgrading.
- Support multiple memberships, group-specific removal, and safe final-membership removal.
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
- The absence of membership records means that a bookmark is shown by the `No Group` view.
- `All` and `No Group` are virtual views rather than deletable group records.

This is preferred over adding group IDs directly to `BookmarkHiveObject`. It avoids rewriting the existing bookmark schema, lets older application versions ignore the new boxes, and makes group deletion a membership operation rather than a mutation of every post snapshot. The bookmark Hive key is used for the relation because it is already the stable local identifier exposed as `Bookmark.id`; booru post IDs are not globally unique.

The group repository is responsible for pruning memberships whose bookmark keys no longer exist. Group duplication creates a new group and copies membership records, never bookmark records.

### Keep bookmark existence separate from membership

The bookmark repository remains responsible for creating, updating, and deleting local post snapshots. A group repository manages named groups and memberships. A coordinated bookmark operation will:

1. Create the bookmark when necessary.
2. Add or remove the requested membership.
3. Refresh the in-memory bookmark and membership state.

If a new bookmark cannot be assigned to the requested group, the operation should remove the newly created bookmark so a failed add does not leave an unexpected orphan. Removing one membership preserves the bookmark when another named membership remains. Removing the final named membership deletes the bookmark and every membership, so it does not move into `No Group`. Bookmarks only appear in `No Group` when they have no named memberships without having been removed from a final group.

### Represent the active target separately from the displayed view

The bookmarks page needs a selected view (`All`, `No Group`, or a named group) and the application needs a persisted active add/remove target. Selecting a named group updates both. Selecting `All` changes only the displayed view and leaves the target unchanged. Selecting `No Group` sets the target to the special ungrouped state.

The active target is stored in the existing local settings mechanism. If a saved group no longer exists, the target falls back to `No Group`. The normal bookmark button uses the same fixed toolbar slot and vertical icon center as neighboring action buttons. Its target label is a single line positioned below the bookmark anchor, centered on the bookmark glyph's center while ignoring the dropdown affordance and count badge. The label is about 30% smaller than the normal compact label style and uses ellipsis. The normal control uses the same standard icon-button press feedback and full hit target as the download control; the hit target includes the bookmark glyph, dropdown affordance, and count badge so long press works across the composite icon. The compact bookmark button used in dense layouts may show only the icon, dropdown affordance, and count badge.

`No Group` is a creation/default state, not a named membership that can coexist with named memberships. A post with named memberships must not have those memberships silently cleared by an action targeting `No Group`; the user must remove memberships explicitly or delete the bookmark completely.

### Use a dedicated full-screen group browser as the bookmarks entry screen

Opening the bookmarks route first shows a full-screen group browser. This browser is separate from the existing bookmarks content view and replaces the horizontal group selector as the way to choose a group. Selecting a card opens the existing bookmarks view filtered to that group; the selected named group also becomes the active bookmark target. Selecting `All` or `No Group` opens the corresponding existing system view.

The browser displays `All`, `No Group`, and named groups as square cards. Each card shows up to the first four bookmarks that the corresponding group view would display under the currently selected bookmark sorting mode, arranged in a 2x2 grid in sorted order. It reuses the existing sorting and shuffle behavior, including the current shuffle state when the mode is `Random`. Still images use the same sample-quality preview as the bookmark grid; videos use their thumbnail image. If fewer than four bookmarks are available, missing cells remain transparent rather than showing placeholders, populated cells have a small gap between them, and the card uses a subtle outline rather than a gray preview background to show its extent. An empty group therefore has a transparent preview area with only its outline and overlaid name visible.

The group name is overlaid near the top of the card image with sufficient contrast, constrained to a readable number of lines. Named cards expose `Duplicate`, `Rename`, and `Delete` through an overflow action; they do not expose a `Create` action because creation belongs to the browser's top-right `+` button. System cards do not expose destructive group actions. The new group is added to the browser and remains in the browser after creation. It does not become the displayed group or open its empty bookmarks view; the previously active bookmark target remains unchanged.

The existing bookmarks content view remains responsible for search, source filtering, sorting, shuffle, post display, and displaying the selected group's name in its app bar. The browser is an entry and navigation layer, not a second implementation of the bookmark grid.

### Make bookmark controls membership-aware

The bookmark state exposed to widgets will include, or provide access to, the set of named group IDs for each local bookmark. The existing `isBookmarked` behavior remains available for general bookmark-page and deletion checks, while the post controls additionally derive:

- whether the bookmark belongs to the active named target;
- the total number of named groups containing it; and
- whether it is ungrouped.

The main icon is filled when the bookmark belongs to the active target. A small count badge shows the total number of named groups whenever the bookmark belongs to at least one named group other than the active target. Long press opens the group picker and updates the persisted target; selecting a newly created group also adds the current post to it.

When the active target is `No Group`, a new post can be saved without memberships. Existing grouped posts are not converted to ungrouped by a single tap.

Successful bookmark creation, named-group addition, and named-group removal use the existing localized `Bookmark added` or `Bookmark removed` success toasts. Failure paths continue to use the existing error toasts.

### Replace the thumbnail bookmark action with a dedicated section

The general post and Danbooru thumbnail context menus will retain unrelated actions and place one local `Bookmark` action between two horizontal dividers. The existing standalone local bookmark action is removed, and the thumbnail context menu does not provide a complete-delete action. Danbooru's server-side favorite-group action remains a separate server feature and is not replaced by the local bookmark action.

Selecting `Bookmark` replaces the contents of the anchored context menu in the same position with the same group list and toggle semantics used by the post bookmark button. The replacement view lists the permitted `No Group` row, all named groups, and a final `Create New Group` row separated by a divider. Membership icons are placed to the left of the group names; filled icons indicate existing membership and outline icons indicate that the post is not in that group. Selecting a group toggles its membership and makes it the active bookmark target. The thumbnail-context group list does not show the gray `Active` badge; the post bookmark popup continues to show it.

The `Bookmark` entry shows a right chevron to communicate that it opens another menu view. The replacement view starts with a `Back` row using a leading return arrow and a divider immediately below it. Back restores the original context-menu contents without dismissing the anchored popup. The replacement view removes the extra outer vertical padding and list padding so its first and last rows align with the normal context-menu surface.

When a post has named memberships, `No Group` is omitted because it cannot be used as a removal target. Creating a group captures a stable root navigator context, replaces the menu safely, and opens the create dialog after dismissal. The new group is added to the post and becomes the active target.

### Make group deletion explicit and final

Deleting a group first calculates the memberships in that group and the bookmarks whose only named membership is the group being deleted. An empty group is deleted without confirmation because no memberships or bookmarks are affected. A non-empty group always shows one standard confirmation containing the total number of bookmarks in the group. After confirmation, the group and its memberships are deleted; bookmarks that belong to no other named group are deleted as well, while bookmarks belonging to another group remain in those groups. There is no option to migrate deleted-group bookmarks into `No Group`.

In the post bookmark group picker, a filled bookmark icon indicates that the post belongs to a group, while a small gray `Active` text label indicates the current active target. The label has no border or background. The picker SHALL not use active-target selection color as a membership indicator or use a checkmark that could be confused with membership. When a post already belongs to one or more named groups, `No Group` is not shown as a removal target. The post picker is presented as an anchored `KurumiAnchor` popup using the same menu container and item styling as Downloads and hamburger menus. Its popup rows use a trailing slot for the `Active` badge, while the entire row remains one tap target. The thumbnail-context picker uses the same group rows without the trailing badge. Dialogs launched from a dismissed overlay use a stable navigator context captured before dismissal.

### Integrate group filtering into the existing bookmarks page

The existing bookmark-page fetch/filter flow will load the local groups and memberships, then apply the selected group filter before the existing tag, source, and sort behavior. Group management belongs in the full-screen group browser, while the content view shows the selected group name in its app bar. Group operations invalidate the bookmark page and membership state so counts and visible results update immediately.

## Risks / Trade-offs

- **Risk:** Membership and bookmark records can become inconsistent after an interrupted multi-step write. → **Mitigation:** centralize coordinated mutations in a repository/service, make new-bookmark assignment compensating, and prune stale memberships during load.
- **Risk:** A large group deletion may require many membership or bookmark writes. → **Mitigation:** batch Hive operations where supported, show progress for large destructive operations, and refresh state only after the operation completes.
- **Risk:** Older app versions do not understand local group boxes. → **Mitigation:** keep group data in separate boxes and avoid changing existing bookmark fields; document that using an older version during an active migration is unsupported if it can remove local data.
- **Risk:** The active target can become confusing when the user views `All`. → **Mitigation:** persist the target intentionally, leave it unchanged when selecting `All`, and display its responsive label below the bookmark button.
- **Risk:** A count badge can be misread as the number of groups other than the active group. → **Mitigation:** define and test it as the total number of named groups containing the bookmark.

## Migration Plan

1. Register the new local group and membership persistence types without modifying existing bookmark records.
2. Treat every existing bookmark with no membership record as visible in `No Group`.
3. Initialize the active target to `No Group` when no valid saved target exists.
4. Deploy the group selector, group-management UI, membership-aware bookmark controls, and context-menu actions.
5. During normal reads, remove membership records that reference deleted bookmark keys or missing groups.
6. If the feature is rolled back, existing bookmarks remain readable because their storage format is unchanged; newly created group data is ignored by older code and can be removed by a later cleanup.
