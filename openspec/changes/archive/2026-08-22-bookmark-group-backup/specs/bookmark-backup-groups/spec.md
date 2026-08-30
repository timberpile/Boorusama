## Purpose

Bookmark backup files must preserve the local groups that organize bookmarks while remaining compatible with existing bookmark-only exports and safe to import into a device with different local database identifiers.

## ADDED Requirements

### Requirement: Bookmark backup payloads preserve existing bookmark data

The bookmark backup format SHALL keep the existing bookmark objects in the top-level `data` array unchanged. A payload MAY include a top-level `groups` array. Each group entry SHALL contain a `name` string and a `bookmarkIds` array of bookmark IDs from the same payload.

#### Scenario: Exporting bookmarks with groups

- WHEN bookmarks and local group memberships are exported
- THEN the payload contains the existing bookmark objects in `data`
- AND it contains one group entry for each local group
- AND each group entry contains its name and the IDs of its member bookmarks

#### Scenario: Exporting bookmarks without groups

- WHEN bookmarks are exported and no local groups exist
- THEN the payload remains a valid bookmark backup with an empty or omitted `groups` array

#### Scenario: Reading a legacy bookmark-only backup

- WHEN a bookmark backup contains `data` but no `groups` field
- THEN the importer reads all bookmarks
- AND it treats the backup as containing no group memberships

### Requirement: Group references are resolved across devices

The importer SHALL treat bookmark IDs inside `groups` as file-local references and SHALL resolve them to local bookmarks using the bookmark identity represented by `Bookmark.uniqueId`, rather than requiring the exported numeric ID to exist locally.

#### Scenario: Restoring a group on a device with different bookmark IDs

- WHEN an imported bookmark matches an existing local bookmark by its unique identity
- AND the imported group references that bookmark's exported ID
- THEN the importer adds the local bookmark to the matching local group

#### Scenario: Ignoring an invalid group reference

- WHEN a group references a bookmark ID that is not present in the backup's `data`
- THEN the importer ignores that reference
- AND it continues importing the remaining valid bookmarks and memberships

### Requirement: Bookmark group imports are additive and idempotent

Bookmark group imports SHALL add missing bookmarks and memberships without overwriting existing bookmark records, deleting bookmarks, deleting groups, or removing memberships. Group names SHALL match case-insensitively; an existing matching group SHALL be reused, otherwise a new group SHALL be created. Repeating the same import SHALL not create duplicate bookmarks, groups, or memberships.

#### Scenario: Importing into an empty repository

- WHEN a valid bookmark backup with groups is imported into an empty repository
- THEN all valid bookmarks are added
- AND all valid groups are created
- AND each group contains its referenced local bookmarks

#### Scenario: Importing into a populated repository

- WHEN a valid bookmark backup is imported into a repository containing some of its bookmarks or groups
- THEN only missing bookmarks and memberships are added
- AND existing bookmark records remain unchanged
- AND an existing group with a case-insensitive name match is reused
- AND existing groups, bookmarks, and memberships not mentioned by the backup remain untouched

#### Scenario: Repeating an import

- WHEN the same bookmark backup is imported more than once
- THEN the repository state after the first import is unchanged by subsequent imports
