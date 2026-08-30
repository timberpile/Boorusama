## Purpose

Make successful direct bookmark backup operations verifiable by showing how many bookmarks were represented and how many imports were already present locally.

## ADDED Requirements

### Requirement: Direct bookmark exports show the exported bookmark count

The system SHALL show a success toast for a successful direct bookmark file or clipboard export using the total number of bookmarks represented by the exported payload.

#### Scenario: Exporting a selected bookmark scope

- **WHEN** a user successfully exports a selected bookmark scope containing `X` bookmarks to a file or clipboard
- **THEN** the success toast says `X Bookmarks exported`

#### Scenario: Exporting an empty bookmark scope

- **WHEN** a user successfully exports a bookmark scope containing zero bookmarks to a file or clipboard
- **THEN** the success toast says `0 Bookmarks exported`

### Requirement: Direct bookmark imports show total and existing bookmark counts

The system SHALL show a success toast for a successful direct bookmark file or clipboard import using the total number of bookmarks in the imported payload. When one or more imported bookmarks already exist locally, the toast SHALL append `(Y already existed)`.

#### Scenario: Importing bookmarks with no existing matches

- **WHEN** a user successfully imports a payload containing `X` bookmarks and none match an existing local bookmark
- **THEN** the success toast says `X Bookmarks imported`

#### Scenario: Importing bookmarks with existing matches

- **WHEN** a user successfully imports a payload containing `X` bookmarks and `Y` match existing local bookmarks, where `Y` is greater than zero
- **THEN** the success toast says `X Bookmarks imported (Y already existed)`

#### Scenario: Importing a payload whose bookmarks all already exist

- **WHEN** a user successfully imports a payload containing `X` bookmarks and all `X` match existing local bookmarks
- **THEN** the success toast says `X Bookmarks imported (X already existed)`

### Requirement: Count-specific feedback is limited to direct bookmark operations

The system SHALL retain the existing success feedback for non-bookmark backup sources and full ZIP backup summaries.

#### Scenario: Completing another backup source operation

- **WHEN** a non-bookmark backup source completes a successful direct export or import
- **THEN** its existing generic success toast remains unchanged

#### Scenario: Completing a full ZIP backup

- **WHEN** a full ZIP backup export or import completes successfully
- **THEN** its existing source-level summary remains unchanged and no bookmark count toast is added
