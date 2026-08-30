## Context

The shared direct-backup tile currently awaits `void` export and import operations, then formats one generic success message. The bookmark importer already identifies records missing from the local repository, but that distinction is discarded after the import completes. Bookmark export filtering also already produces the exact payload that needs to be counted.

## Goals / Non-Goals

**Goals:**

- Carry an optional operation result through direct file and clipboard export/import operations.
- Report the selected export payload size and the total import payload size.
- Report how many imported bookmarks matched existing local bookmarks.
- Keep message formatting localized to the bookmark tile while retaining generic behavior elsewhere.

**Non-Goals:**

- Changing ZIP backup result summaries.
- Adding counts to other backup sources.
- Changing bookmark identity matching, additive import behavior, or group restoration.

## Decisions

### Use an optional typed operation result

The backup capability and import-preparation interfaces will return an optional count result instead of forcing every source to know about bookmark-specific counts. Existing sources return no result and continue using their current generic messages. The result carries the total item count and an already-existing count.

This is preferred over reading the repository again after export/import because it avoids duplicate work and guarantees that the toast describes the payload actually processed. It is also preferred over checking the source ID in the shared widget because source-specific formatting remains explicit and type-safe.

### Let the bookmark source provide localized success message builders

The shared backup tile will accept optional success-message builders for export and import. The bookmark source supplies builders that use the localized strings and the optional existing-count suffix; other sources omit them. The file and clipboard paths use the same builders.

### Calculate import counts before mutating local state

The bookmark importer will compare imported bookmark identities with the current local identities, derive total and already-existing counts, add only missing bookmarks as before, restore group memberships, and return the count result. The counts therefore describe the incoming payload even when all records already exist.

## Risks / Trade-offs

- [API surface] Changing shared capability return types requires updating existing source closures → Keep the result optional and return `null` for sources without count-aware feedback.
- [Duplicate records in malformed backups] A payload containing duplicate bookmark identities could make raw record counts differ from unique bookmark counts → Preserve the existing importer semantics and count payload records consistently with the requested total-payload wording; malformed duplicate handling remains out of scope.
- [Localization coverage] New message placeholders must be available to the generated localization code → Add the English source strings and regenerate i18n artifacts using the repository workflow.

## Migration Plan

No data migration is required. Deploy the code and updated translations together; existing backups remain compatible because only the success-result plumbing changes.
