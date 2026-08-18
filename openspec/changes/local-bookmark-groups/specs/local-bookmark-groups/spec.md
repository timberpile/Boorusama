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

#### Scenario: Delete a group while preserving orphaned bookmarks

- **WHEN** the user chooses to delete a group and keep bookmarks that belong only to that group
- **THEN** the system SHALL delete the group, remove its memberships, and show those bookmarks in `No Group`

#### Scenario: Delete a group and its orphaned bookmarks

- **WHEN** the user chooses to delete a group and delete bookmarks that belong to no other group
- **THEN** the system SHALL delete the group and those orphaned bookmarks, while retaining bookmarks that belong to another group

### Requirement: Safe group deletion

Deleting an empty named group SHALL not require confirmation because it removes no memberships or bookmarks.

Deleting a non-empty named group SHALL always require confirmation. If no bookmark belongs only to the group being deleted, the system SHALL show a simple confirmation that the group and its memberships will be removed. If orphaned bookmarks exist, the confirmation SHALL explain how many bookmarks are affected and SHALL offer separate choices to keep orphaned bookmarks in `No Group` or delete them.

#### Scenario: Cancel group deletion

- **WHEN** the user cancels the group-deletion confirmation
- **THEN** the group and all of its memberships SHALL remain unchanged

#### Scenario: Delete an empty group

- **WHEN** the user deletes a group with no bookmark memberships
- **THEN** the system SHALL delete the group without prompting and SHALL not delete any bookmarks

#### Scenario: Confirm deletion of a non-empty group without orphaned bookmarks

- **WHEN** the user deletes a non-empty group and every affected bookmark belongs to another named group
- **THEN** the system SHALL show a simple confirmation before removing the group and its memberships

### Requirement: Active bookmark target

The system SHALL maintain a persisted active bookmark target, defaulting to `No Group`.

Opening a named group or creating a group SHALL make that group the active target. Selecting `All` SHALL leave the active target unchanged. Selecting `No Group` SHALL make `No Group` the active target.

The bookmark control SHALL display the active target name below its icon.

#### Scenario: Use the last selected group

- **WHEN** the user leaves a named group and later views another page containing posts
- **THEN** a single tap on the bookmark control SHALL target the last selected named group

#### Scenario: Default to ungrouped bookmarks

- **WHEN** the active target is `No Group` and the user taps an unbookmarked post
- **THEN** the system SHALL create an ungrouped bookmark and the direct action SHALL be labeled `Add Bookmark`

#### Scenario: Persist the active target

- **WHEN** the application is restarted after a user selected a valid target group
- **THEN** the active target SHALL be restored when that group still exists; otherwise it SHALL fall back to `No Group`

### Requirement: Group-aware bookmark button

The bookmark button SHALL toggle membership in the active named group instead of treating the bookmark as a single global boolean.

A long press on the bookmark button SHALL open a group-selection interface. The interface SHALL list available add targets and SHALL provide an option to `Create New Group`.

The group-selection interface SHALL use a filled bookmark icon to indicate that the post belongs to a group and a checkmark to indicate the active target. It SHALL not use active-target selection color as the membership indicator. When a post belongs to one or more named groups, `No Group` SHALL not be offered as a removal target.

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
- **THEN** the bookmark SHALL remain locally bookmarked and SHALL appear in `No Group`

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

When the bookmark belongs to one or more named groups other than the active target, the button SHALL also show a count badge containing the total number of named groups containing the bookmark. The active target label below the button SHALL fit within its available width by wrapping to at most two lines with ellipsis or by falling back to an icon-and-badge-only compact layout; it SHALL not be clipped after only a few characters.

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

### Requirement: Bookmark thumbnail context menu

The post-thumbnail context menu SHALL replace the existing standalone add-to-bookmark action with a dedicated bookmark section separated from unrelated actions by a horizontal divider.

The bookmark section SHALL provide the title-cased actions `Add To...`, `Add To <active target>` when applicable, `Remove From...`, `Remove From <active target>` when applicable, and `Delete Bookmark Completely` when a local bookmark exists. When the active target is `No Group`, the direct add action SHALL be labeled `Add Bookmark`.

#### Scenario: Add from the context menu

- **WHEN** the user selects a named group from `Add To...`
- **THEN** the system SHALL create the bookmark if needed, add it to that group, and make that group the active target

#### Scenario: Create a group from the context menu

- **WHEN** the user selects `Create New Group` from `Add To...` and enters a valid name
- **THEN** the system SHALL create the group, add the post to it, and make it the active target

#### Scenario: Remove from a selected group

- **WHEN** the user selects a group containing the bookmark from `Remove From...`
- **THEN** the system SHALL remove only that group membership

#### Scenario: Delete a bookmark completely

- **WHEN** the user selects `Delete Bookmark Completely` and confirms
- **THEN** the system SHALL delete the bookmark and all of its group memberships

#### Scenario: Cancel complete deletion

- **WHEN** the user cancels the complete-deletion confirmation
- **THEN** the bookmark and all memberships SHALL remain unchanged
