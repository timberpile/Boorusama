## Why

Bulk removal currently confirms only how many bookmarks lost membership in the
selected group. When the last named-group membership is removed, the bookmark is
preserved in `No Group`, but the user receives no explicit indication of that
result.

## What Changes

- Return both the number of removed memberships and the number of bookmarks that
  now have no named-group memberships.
- Extend the bulk removal success message to mention bookmarks now in `No Group`
  when that count is greater than zero.
- Keep the existing shorter success message when no bookmark moved to `No Group`.
- Add localized strings and provider/UI tests for both message variants.

## Capabilities

### New Capabilities

- `bookmark-removal-feedback`: Report when bulk group removal leaves bookmarks in
  `No Group`.

### Modified Capabilities

None.

## Impact

- Bulk bookmark notifier result types and `removePostsFromGroup` callers.
- Multi-selection bookmark success feedback and localization.
- Provider and widget tests for mixed memberships and final-membership removal.
