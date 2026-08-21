## Purpose

Provide global local bookmark groups so users can organize saved posts from Gelbooru and other booru types without relying on server-side favorite-group support.

## ADDED Requirements

### Requirement: Global bookmark groups

The system SHALL allow users to create local bookmark groups that are available across all booru types and configurations.

A bookmark SHALL be able to belong to multiple named groups or to no named group.

#### Scenario: Add an existing bookmark to another group

- **WHEN** a user adds a bookmark that already exists to a named group
- **THEN** the bookmark SHALL gain membership in that group without creating a duplicate bookmark

#### Scenario: Add a new post to a named group

- **WHEN** a user adds a post to a named group and no local bookmark exists for that post
- **THEN** the system SHALL create the local bookmark and assign it to the selected group

#### Scenario: Add an existing bookmark to multiple groups

- **WHEN** a user adds a bookmark to a second named group
- **THEN** the bookmark SHALL remain in its existing groups and SHALL also belong to the second group

#### Scenario: Confirm a successful named-group addition

- **WHEN** a bookmark is successfully added to a named group
- **THEN** the system SHALL show the existing localized `Bookmark added` success toast

### Requirement: Bookmark group views

The bookmarks page SHALL provide a group selector containing the `All` and `No Group` system views and all user-created groups.

`All` SHALL show every local bookmark. `No Group` SHALL show only bookmarks with no named group memberships.

#### Scenario: View all bookmarks

- **WHEN** the user selects `All`
- **THEN** the page SHALL show every local bookmark regardless of group membership

#### Scenario: View ungrouped bookmarks

- **WHEN** the user selects `No Group`
- **THEN** the page SHALL show only bookmarks that do not belong to any named group

#### Scenario: View a named group

- **WHEN** the user selects a named group
- **THEN** the page SHALL show only bookmarks belonging to that group

### Requirement: Full-screen bookmark group browser

Opening the bookmarks route SHALL first show a separate full-screen group browser before the existing bookmarks content view.

The browser SHALL display `All`, `No Group`, and every named group as square cards. Each card SHALL show up to the first four bookmarks that its corresponding bookmarks view would display under the currently selected bookmark sorting mode, arranged in a 2x2 grid in sorted order. Still images SHALL use the same sample-quality preview as the bookmark grid, while videos SHALL use their thumbnail image. Missing cells SHALL remain transparent instead of showing placeholder images, and populated cells SHALL have a small visible gap between them. The preview area SHALL have no gray placeholder fill; a subtle outline SHALL show the extent of an empty or partially populated card. The card's group name SHALL be overlaid near the top of the preview area.

The browser SHALL provide a compact `+` icon in the top-right corner for creating a group. The old horizontal group selector SHALL not be shown in the bookmarks content view. The content view SHALL show the selected group's name in its app-bar title.

#### Scenario: Open the bookmarks route

- **WHEN** the user opens Bookmarks
- **THEN** the system SHALL show the full-screen group browser instead of immediately showing the post grid

#### Scenario: Preview a named group

- **WHEN** a named group contains bookmarks
- **THEN** its browser card SHALL show the first four bookmarks from that group's current sorted order in a 2x2 grid, using bookmark-grid preview quality

#### Scenario: Preview a group with fewer than four bookmarks

- **WHEN** a group contains fewer than four bookmarks
- **THEN** its card SHALL show only those bookmarks in sorted order and SHALL leave the remaining grid cells transparent

#### Scenario: Preview an empty group

- **WHEN** a named group contains no bookmarks
- **THEN** its browser card SHALL show a transparent preview area instead of placeholder images

#### Scenario: Open a group from the browser

- **WHEN** the user taps a group card
- **THEN** the system SHALL open the existing bookmarks content view filtered to that group and make the named group the active bookmark target

#### Scenario: Create a group from the browser

- **WHEN** the user taps the `+` icon, enters a valid name, and confirms
- **THEN** the system SHALL create the group, leave the browser open, and show the new group card without selecting or opening its empty bookmarks content view

#### Scenario: Show the browser title

- **WHEN** the group browser is open
- **THEN** its title SHALL be `Bookmark Groups`

#### Scenario: Show the selected group title

- **WHEN** the bookmarks content view is open for a selected group
- **THEN** its app-bar title SHALL contain that group's name

### Requirement: Group management

The bookmarks page SHALL allow users to create, duplicate, rename, and delete named groups.

Duplicating a group SHALL copy its bookmark memberships without duplicating the bookmark records.

#### Scenario: Create a group

- **WHEN** the user creates a group with a valid name
- **THEN** the system SHALL create the group, select it as the active bookmark target, and show it in the group selector

#### Scenario: Duplicate a group

- **WHEN** the user duplicates a named group
- **THEN** the system SHALL create a separate group containing the same bookmark memberships

#### Scenario: Rename a group

- **WHEN** the user renames a named group with a valid name
- **THEN** the system SHALL update the group name without changing its bookmark memberships

#### Scenario: Delete a group and its unique bookmarks

- **WHEN** the user confirms deletion of a named group
- **THEN** the system SHALL delete the group and its memberships, delete bookmarks that belong to no other named group, and retain bookmarks that belong to another group

### Requirement: Safe group deletion

Deleting an empty named group SHALL not require confirmation because it removes no memberships or bookmarks.

Deleting a non-empty named group SHALL always require one standard confirmation. The confirmation SHALL report the total number of bookmarks in the group and SHALL not offer a choice to keep deleted-group bookmarks in `No Group`.

#### Scenario: Cancel group deletion

- **WHEN** the user cancels the group-deletion confirmation
- **THEN** the group and all of its memberships SHALL remain unchanged

#### Scenario: Delete an empty group

- **WHEN** the user deletes a group with no bookmark memberships
- **THEN** the system SHALL delete the group without prompting and SHALL not delete any bookmarks

#### Scenario: Confirm deletion of a non-empty group

- **WHEN** the user deletes a non-empty group
- **THEN** the system SHALL show one confirmation containing the group's total bookmark count before removing the group and its memberships

### Requirement: Active bookmark target

The system SHALL maintain a persisted active bookmark target, defaulting to `No Group`.

Opening a named group or creating a group from a post add-group interface SHALL make that group the active target. Creating an empty group from the browser's `+` action SHALL leave the active target unchanged. Selecting `All` SHALL leave the active target unchanged. Selecting `No Group` SHALL make `No Group` the active target.

The normal bookmark control SHALL use the same fixed toolbar slot and vertical icon center as neighboring action buttons. It SHALL display the active target name below the bookmark glyph on one line, centered exactly below the bookmark glyph while ignoring the downward-arrow affordance and count badge. The label SHALL be about 30% smaller than the normal compact label style and SHALL use ellipsis. It SHALL include a small downward-arrow affordance beside the bookmark icon, aligned like the download-button affordance, to communicate that long press opens group actions. The normal control SHALL use the same standard icon-button press feedback and full hit target as the download control, and that hit target SHALL include the bookmark glyph, downward arrow, and count badge. A long press anywhere in that composite hit target SHALL open the group-selection interface. A compact bookmark control may omit the label when space is insufficient.

#### Scenario: Use the last selected group

- **WHEN** the user leaves a named group and later views another page containing posts
- **THEN** a single tap on the bookmark control SHALL target the last selected named group

#### Scenario: Default to ungrouped bookmarks

- **WHEN** the active target is `No Group` and the user taps an unbookmarked post
- **THEN** the system SHALL create an ungrouped bookmark and the direct action SHALL be labeled `Add bookmark`

#### Scenario: Persist the active target

- **WHEN** the application is restarted after a user selected a valid target group
- **THEN** the active target SHALL be restored when that group still exists; otherwise it SHALL fall back to `No Group`

### Requirement: Group-aware bookmark button

The bookmark button SHALL toggle membership in the active named group instead of treating the bookmark as a single global boolean.

A long press on the bookmark button SHALL open a group-selection interface. The interface SHALL list available add targets and SHALL provide an option to `Create New Group`.

The group-selection interface SHALL use a filled group/bookmark icon to indicate that the post belongs to a group and a small gray `Active` text label to indicate the active target. The label SHALL have no border or background. It SHALL not use a checkmark or active-target accent color as the membership indicator. When a post belongs to one or more named groups, `No Group` SHALL not be offered as a removal target. The interface SHALL be presented as an anchored popup using the same menu container and item styling as the download and hamburger menus. The active-target badge SHALL appear in a trailing slot within the same tap target as its group row.

#### Scenario: Add through a single tap

- **WHEN** a post is not bookmarked and the active target is a named group
- **THEN** a single tap SHALL create the bookmark and add it to that group

#### Scenario: Add an existing bookmark to the active group

- **WHEN** a post is bookmarked but is not a member of the active named group
- **THEN** a single tap SHALL add the bookmark to the active group without duplicating it

#### Scenario: Remove from the active group

- **WHEN** a post belongs to the active named group
- **THEN** a single tap SHALL remove only that group membership

#### Scenario: Remove the final named membership

- **WHEN** a user removes a bookmark from its final named group
- **THEN** the system SHALL delete the bookmark and all of its remaining membership records instead of moving it into `No Group`

#### Scenario: Confirm a successful named-group removal

- **WHEN** a bookmark is successfully removed from a named group
- **THEN** the system SHALL show the existing localized `Bookmark removed` success toast

#### Scenario: Select a group by long press

- **WHEN** the user long-presses the bookmark button and selects a named group
- **THEN** the system SHALL make that group the active target and SHALL apply the selection to the current post according to the add/remove operation

#### Scenario: Create a group while adding a post

- **WHEN** the user chooses `Create New Group` from the add-group interface and enters a valid name
- **THEN** the system SHALL create the group, add the current post to it, and make it the active target

#### Scenario: Avoid clearing memberships through No Group

- **WHEN** a bookmarked post belongs to one or more named groups and `No Group` is the active target
- **THEN** a bookmark-button action SHALL not silently remove all named memberships; the user SHALL use a named-group removal action to remove memberships

### Requirement: Bookmark membership indicators

The bookmark button SHALL indicate whether the current post belongs to the active target group.

When the bookmark belongs to one or more named groups other than the active target, the button SHALL also show a count badge containing the total number of named groups containing the bookmark. The normal button SHALL show the active-target label below the icon and SHALL fit it within an area wide enough for at least six or seven characters before wrapping to at most two lines with ellipsis. A compact layout may fall back to an icon-and-badge-only layout.

#### Scenario: Post is not bookmarked

- **WHEN** no local bookmark exists for the post
- **THEN** the button SHALL show an empty bookmark icon without a group-count badge

#### Scenario: Post belongs only to the active group

- **WHEN** the post belongs to the active named group and no other named groups
- **THEN** the button SHALL show a filled bookmark icon without a group-count badge

#### Scenario: Post belongs to other groups only

- **WHEN** the post belongs to one or more named groups but not the active named group
- **THEN** the button SHALL show an empty bookmark icon and a badge containing the total number of named groups

#### Scenario: Post belongs to the active group and other groups

- **WHEN** the post belongs to the active named group and at least one other named group
- **THEN** the button SHALL show a filled bookmark icon and a badge containing the total number of named groups

#### Scenario: Show the aligned long-press affordance and target label

- **WHEN** the normal bookmark control is shown
- **THEN** it SHALL show a small downward arrow aligned like the download control, keep the bookmark glyph vertically aligned with neighboring toolbar icons, and display a single-line active-target label centered below the bookmark glyph

#### Scenario: Use a simple gray active label

- **WHEN** the group-selection interface shows the active target
- **THEN** it SHALL use a small gray `Active` text label without a border, background, checkmark, or accent-color selection state

### Requirement: Bookmark thumbnail context menu

The post-thumbnail context menu SHALL replace the existing standalone add-to-bookmark action with one local `Bookmark` action between exactly one divider before it and exactly one divider after it. It SHALL NOT provide a complete-delete action.

The `Bookmark` action SHALL show a right chevron. Selecting it SHALL replace the contents of the anchored context menu in the same position with a group picker using the same group rows and membership-toggle semantics as the post bookmark popup. The picker SHALL begin with a `Back` row containing a leading return arrow and a horizontal divider immediately after it. Activating `Back` SHALL restore the original context-menu contents without dismissing the anchored popup. The picker SHALL show the permitted `No Group` row, all named groups, and `Create New Group` after the Back divider. Membership icons SHALL appear to the left of the group names; filled icons SHALL indicate membership and outline icons SHALL indicate no membership. The thumbnail-context picker SHALL omit the `Active` badge, but selecting a group SHALL still make it the active bookmark target. Selecting a group SHALL close the picker after applying the membership change. The replacement picker SHALL not add extra outer or list padding beyond the normal context-menu surface.

When a post has one or more named memberships, `No Group` SHALL not be shown because it cannot be used as a removal target. Selecting `Create New Group` SHALL replace the menu safely, open the create-group dialog using a stable navigator context, add the post to the new group, and make the new group the active target.

#### Scenario: Toggle a group from the context menu

- **WHEN** the user selects a named group from the `Bookmark` picker
- **THEN** the system SHALL create the bookmark if needed, add or remove that group's membership according to the current membership state, and make that group the active target

#### Scenario: Create a group from the context menu

- **WHEN** the user selects `Create New Group` from the `Bookmark` picker and enters a valid name
- **THEN** the system SHALL create the group, add the post to it, and make it the active target

#### Scenario: Show the thumbnail bookmark picker without an active badge

- **WHEN** the user opens `Bookmark` from a thumbnail context menu
- **THEN** the group rows SHALL show membership with leading filled or outline icons and SHALL not show the `Active` badge

#### Scenario: Open the create-group dialog after replacing the context menu

- **WHEN** the user selects `Create New Group` from the thumbnail bookmark picker
- **THEN** the replacement menu SHALL close and the create-group dialog SHALL open using a still-active navigator context

#### Scenario: No complete-delete action in the context menu

- **WHEN** a local bookmark exists
- **THEN** the local bookmark section SHALL expose only the `Bookmark` membership picker, without a complete-delete action
