## 1. Export scope and filtering

- [x] 1.1 Add a runtime-only bookmark export scope model for All bookmarks, selected real group IDs, and No group.
- [x] 1.2 Implement bookmark backup data filtering that unions selected memberships, deduplicates bookmarks, omits unselected groups, and preserves selected empty groups.
- [x] 1.3 Add unit tests covering the all-bookmarks scope, overlapping groups, No group, omitted memberships, empty groups, and stable JSON-compatible group references.

## 2. Direct export user interface

- [x] 2.1 Add localized strings for the bookmark export scope dialog, including All bookmarks, Selected groups, No group, and selection validation.
- [x] 2.2 Implement a transient group-scope dialog that defaults to All bookmarks, lists current real groups, supports No group, and returns cancellation without side effects.
- [x] 2.3 Integrate an optional bookmark-specific export-scope hook into the direct backup tile flow while keeping the four existing actions and opening the file picker only after scope confirmation.
- [x] 2.4 Use the same scope dialog for file and clipboard exports and add widget-level coverage for default selection, cancellation, and selected-group confirmation.

## 3. Export paths and compatibility

- [x] 3.1 Apply the selected scope to direct bookmark file and clipboard payload generation while leaving import actions unchanged.
- [x] 3.2 Verify that full ZIP backups continue using the all-bookmarks scope and never show the group-selection dialog.
- [x] 3.3 Verify existing bookmark-only exports, legacy imports, group imports, and clipboard size handling remain compatible.
- [x] 3.4 Run formatting, focused tests, analyzer checks, and OpenSpec validation.
