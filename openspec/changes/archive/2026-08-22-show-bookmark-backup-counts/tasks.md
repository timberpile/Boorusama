## 1. Result plumbing

- [x] 1.1 Add an optional backup operation result carrying the total item count and already-existing count.
- [x] 1.2 Update direct file export, clipboard export, and import preparation APIs to return optional operation results while preserving `null` results for sources without count-aware feedback.
- [x] 1.3 Update existing non-bookmark backup sources and ZIP integration to use the updated interfaces without changing their success messages or result summaries.

## 2. Bookmark count tracking

- [x] 2.1 Return the total exported bookmark count from the bookmark source for both file and clipboard exports, including selected and empty scopes.
- [x] 2.2 Return total imported and already-existing bookmark counts from the bookmark importer while preserving additive imports and group restoration.
- [x] 2.3 Wire the bookmark source to provide localized count-aware success messages for direct file and clipboard operations.

## 3. User feedback and tests

- [x] 3.1 Update the shared backup tile to use optional count-aware success message builders for file and clipboard exports/imports, retaining generic messages when no builder is supplied.
- [x] 3.2 Add localized strings for the exact export and import count message forms, including omission of the existing-count suffix when it is zero.
- [x] 3.3 Add unit and widget coverage for export totals, all-new imports, mixed imports, all-existing imports, zero existing suffix omission, and unchanged generic source feedback.

## 4. Verification

- [x] 4.1 Run formatting, focused backup tests, analyzer checks, and strict OpenSpec validation.
