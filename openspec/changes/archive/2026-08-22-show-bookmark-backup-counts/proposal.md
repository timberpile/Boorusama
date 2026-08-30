## Why

Successful bookmark backup operations currently only say that the operation completed. Users cannot tell how many bookmarks were included or how many imported bookmarks were already present, which makes it difficult to verify a selective export or understand an additive import.

## What Changes

- Report the total number of bookmarks in successful direct bookmark exports.
- Report the total number of bookmarks in successful direct bookmark imports.
- Include the number of already-existing bookmarks in the import toast when that number is greater than zero.
- Keep the existing generic success messages for other backup sources and ZIP backup summaries.
- Preserve additive import behavior and existing bookmark/group compatibility.

## Capabilities

### New Capabilities

- `bookmark-backup-counts`: User-visible counts for successful direct bookmark backup exports and imports.

### Modified Capabilities

None.

## Impact

- The direct bookmark backup source and shared backup operation result flow need to carry export/import counts to the success toast.
- The bookmark importer needs to retain the distinction between total imported records and records whose bookmark identity already existed locally.
- Bookmark backup localization strings and focused tests will be updated.
