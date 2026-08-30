## 1. Backup payload support

- [x] 1.1 Add optional preservation of unknown top-level backup fields while keeping legacy payload decoding compatible
- [x] 1.2 Add bookmark-group backup value types and parsing/encoding for the optional `groups` payload field

## 2. Bookmark export and import

- [x] 2.1 Add failing tests for grouped bookmark export, legacy bookmark-only import, and cross-device bookmark reference resolution
- [x] 2.2 Export all bookmark groups and valid memberships without exporting local group IDs
- [x] 2.3 Import missing bookmarks first, then restore group memberships by resolving file-local bookmark IDs through `Bookmark.uniqueId`
- [x] 2.4 Reuse groups by case-insensitive name and merge memberships without deleting or overwriting existing data
- [x] 2.5 Safely ignore stale group references and make repeated imports idempotent

## 3. Verification

- [x] 3.1 Run focused backup and bookmark-group tests and format all changed Dart files
- [x] 3.2 Run the full Flutter test suite, OpenSpec strict validation, and whitespace checks; the full suite retains five unrelated baseline failures
