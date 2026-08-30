## Purpose

Make bulk bookmark-group removal transparent by explicitly telling users when
removing a final named-group membership leaves bookmarks in `No Group`.

## ADDED Requirements

### Requirement: Report bookmarks moved to No Group after bulk removal

When the user removes a named group membership from multiple bookmarks, the
system SHALL report both the number of memberships removed and, when applicable,
the number of affected bookmarks that now have no named-group memberships.

The success message SHALL use the following forms:

- When no bookmark becomes ungrouped: `{removed} bookmarks removed from {group}`.
- When one or more bookmarks become ungrouped: `{removed} bookmarks removed from {group}; {ungrouped} bookmarks are now in No Group`.

The `No Group` suffix SHALL be omitted when `{ungrouped}` is zero. A bookmark
that remains in another named group SHALL not be counted as moved to `No Group`.

#### Scenario: Report bookmarks that become ungrouped

- **WHEN** the user removes `Favorites` from three bookmarks and two of those bookmarks have no other named-group memberships
- **THEN** the success message SHALL state that three bookmarks were removed from `Favorites` and that two bookmarks are now in `No Group`

#### Scenario: Omit the No Group suffix when other memberships remain

- **WHEN** the user removes `Favorites` from three bookmarks and every affected bookmark remains in at least one other named group
- **THEN** the success message SHALL state that three bookmarks were removed from `Favorites` without a `No Group` suffix

#### Scenario: Count only memberships actually removed

- **WHEN** the selection includes bookmarks that do not belong to the chosen group
- **THEN** those bookmarks SHALL not contribute to either the removed count or the count of bookmarks now in `No Group`
