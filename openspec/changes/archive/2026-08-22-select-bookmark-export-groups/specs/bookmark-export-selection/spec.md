## Purpose

This capability lets users create focused bookmark backups from selected groups while preserving the existing bookmark JSON format, import behavior, and full-backup semantics.

## ADDED Requirements

### Requirement: Direct bookmark exports offer a scope selector

The bookmark backup's direct Export and Export to clipboard actions SHALL open a scope selector before producing output. The selector SHALL offer All bookmarks, every real bookmark group, and No group, with All bookmarks selected by default. The selection SHALL be discarded after the operation.

#### Scenario: Opening a direct file export

- **WHEN** the user chooses Export from the bookmark backup actions
- **THEN** the scope selector is shown before the file destination picker
- **AND** All bookmarks is selected initially

#### Scenario: Opening a direct clipboard export

- **WHEN** the user chooses Export to clipboard from the bookmark backup actions
- **THEN** the same scope selector is shown before clipboard data is generated
- **AND** All bookmarks is selected initially

#### Scenario: Cancelling scope selection

- **WHEN** the user cancels the scope selector
- **THEN** no file picker is opened or clipboard data is changed
- **AND** the selection is not persisted for a later export

### Requirement: Selected scopes filter bookmarks and memberships

When the user chooses selected groups, the export SHALL contain each bookmark that belongs to at least one selected real group or, when selected, belongs to No group. Each bookmark SHALL appear at most once. The export SHALL contain memberships only for selected real groups, and SHALL preserve selected groups even when their filtered membership list is empty.

#### Scenario: Exporting multiple overlapping groups

- **WHEN** the user selects two groups that contain the same bookmark
- **THEN** the bookmark is written once to the export's data array
- **AND** both selected group entries reference that bookmark

#### Scenario: Omitting an unselected membership

- **WHEN** a selected bookmark also belongs to a group that was not selected
- **THEN** the bookmark remains in the export
- **AND** the unselected group and membership are omitted

#### Scenario: Exporting No group

- **WHEN** the user selects No group
- **THEN** bookmarks with no real group membership are included
- **AND** no real group entry is created solely for No group

#### Scenario: Exporting an empty selected group

- **WHEN** the user selects a real group that contains no bookmarks in the selected scope
- **THEN** the export contains that group with an empty bookmarkIds array

### Requirement: All-bookmark exports preserve current behavior

When All bookmarks is selected, the export SHALL include all bookmarks, all real groups, and all memberships exactly as the current full bookmark export does. The existing top-level data and optional groups JSON structure SHALL remain unchanged.

#### Scenario: Exporting all bookmarks

- **WHEN** the user accepts the default All bookmarks scope
- **THEN** every bookmark is included once
- **AND** every real group and its memberships are included

### Requirement: Import and full ZIP backup remain unfiltered

Bookmark file and clipboard imports SHALL not display or apply an export scope selection. Full ZIP backups SHALL continue to include all bookmark groups and bookmarks without displaying a group-selection dialog.

#### Scenario: Importing a direct bookmark backup

- **WHEN** the user chooses Import or Import from clipboard
- **THEN** the existing import flow starts without a group-selection dialog

#### Scenario: Creating a full ZIP backup

- **WHEN** the user creates a full ZIP backup containing bookmarks
- **THEN** all bookmarks and all real bookmark groups are included
- **AND** no group-selection dialog is displayed
