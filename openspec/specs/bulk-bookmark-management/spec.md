# bulk-bookmark-management Specification

## Purpose

Provide a clear, group-aware way to manage bookmarks for multiple selected posts while preserving mixed group memberships and allowing consecutive bulk operations.

## Requirements

### Requirement: Multi-selection bookmark management menu

When posts are selected in a post listing or in the bookmark content view, the bottom bookmark action SHALL be labeled `Bookmarks` and SHALL open a menu containing exactly these bookmark-management actions:

- `Add to group >`
- `Remove from group >`
- `Delete`

The menu SHALL not expose the legacy single-purpose global bookmark action.

#### Scenario: Open bookmark management for selected posts

- **WHEN** one or more posts are selected and the user taps the bottom `Bookmarks` action
- **THEN** the system SHALL show the three bookmark-management actions without changing the current selection

#### Scenario: Open bookmark management in a bookmark group view

- **WHEN** one or more bookmarks are selected in a named group view and the user taps the bottom `Bookmarks` action
- **THEN** the system SHALL show the same three actions without requiring the dialog to know which group is currently displayed

### Requirement: Add selected posts to a group

The `Add to group` action SHALL open a group-selection dialog containing all named groups, the `No Group` target, and an option to create a new group. The dialog SHALL show the total selected-post count and aggregate membership information for each target rather than showing a single checked state for the entire mixed selection.

Selecting a named group SHALL add every selected post that is not already a member of that group. It SHALL preserve all existing memberships and SHALL create a local bookmark for an unbookmarked post before adding the membership.

Selecting `No Group` SHALL create ungrouped bookmarks for selected posts that are not bookmarked, leave already-ungrouped bookmarks unchanged, and leave bookmarks with named memberships unchanged. It SHALL not silently clear named memberships.

#### Scenario: Show aggregate named-group membership while adding

- **WHEN** 5 of 12 selected posts belong to a named group
- **THEN** that group SHALL show an aggregate state such as `5 of 12 already in this group`, without implying that every selected post has the same memberships

#### Scenario: Add selected posts to a named group

- **WHEN** the user selects a named group in the add dialog
- **THEN** missing memberships SHALL be added, existing memberships SHALL be preserved, and no duplicate bookmarks SHALL be created

#### Scenario: Add selected posts to No Group

- **WHEN** the user selects `No Group` in the add dialog
- **THEN** unbookmarked selected posts SHALL become ungrouped bookmarks, already-ungrouped bookmarks SHALL remain unchanged, and grouped bookmarks SHALL retain all their named memberships

#### Scenario: Create a group while adding selected posts

- **WHEN** the user creates a new group from the add dialog
- **THEN** the new group SHALL be created and all selected posts SHALL be added to it using the same additive semantics as an existing named group

### Requirement: Remove selected posts from a group

The `Remove from group` action SHALL open a group-selection dialog that shows aggregate counts for the named groups represented by the selected posts. It SHALL not treat `No Group` as a removable membership.

Selecting a named group SHALL remove only that group membership from selected posts that belong to it. It SHALL preserve all other memberships and SHALL preserve the underlying bookmark even when the removed membership was its final named membership. A bookmark with no remaining named memberships SHALL therefore appear in `No Group`.

#### Scenario: Show aggregate membership while removing

- **WHEN** 5 of 12 selected posts belong to a named group
- **THEN** that group SHALL show an aggregate state such as `5 of 12 selected posts belong to this group`

#### Scenario: Remove one membership while preserving other memberships

- **WHEN** a selected bookmark belongs to the chosen group and another named group
- **THEN** the chosen membership SHALL be removed and the other membership and bookmark SHALL remain

#### Scenario: Remove a final membership without deleting the bookmark

- **WHEN** a selected bookmark belongs only to the chosen named group and the user removes it through the multi-selection dialog
- **THEN** the named membership SHALL be removed, the bookmark SHALL remain, and the bookmark SHALL appear in `No Group`

### Requirement: Delete selected bookmarks completely

The `Delete` action SHALL be separate from group-membership removal and SHALL require confirmation before deleting selected local bookmarks. Confirming SHALL delete each existing bookmark, all of its group memberships, and its locally cached bookmark images. Selected posts that are not local bookmarks SHALL be unaffected.

#### Scenario: Confirm complete deletion

- **WHEN** the user confirms deletion of selected bookmarks
- **THEN** the selected local bookmarks and all their memberships SHALL be deleted

#### Scenario: Cancel complete deletion

- **WHEN** the user cancels the delete confirmation
- **THEN** all selected bookmarks and memberships SHALL remain unchanged

### Requirement: Preserve multi-selection after bookmark operations

Completing an add or remove operation through the multi-selection bookmark workflow SHALL not disable selection mode. The selected items SHALL remain selected while they remain present in the current listing, allowing the user to perform another action immediately.

If a remove or delete operation causes an item to leave the current filtered bookmark view, that item MAY disappear from the visible selection because it is no longer present in the listing. Selection mode SHALL remain available for any remaining visible items.

#### Scenario: Perform consecutive group edits

- **WHEN** the user adds selected posts to one group and then opens the `Bookmarks` action again
- **THEN** the same visible selection SHALL still be available for a subsequent add or remove operation

### Requirement: Preserve single-post final-membership behavior

The existing single-post bookmark edit workflow SHALL continue to delete a bookmark when removing its final named-group membership. This behavior SHALL use a distinct operation from the membership-only removal used by the multi-selection dialog.

#### Scenario: Remove the final membership from a single post

- **WHEN** the user removes a single post from its final named group through the single-post bookmark control
- **THEN** the bookmark SHALL be deleted completely rather than moved into `No Group`
