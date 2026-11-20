# Multi-File Local Media Package — #185

Status: **Deferred backlog design outline; not implemented.**
Issue: https://github.com/timberpile/Boorusama/issues/185
Depends on: #180 and #182. Do not include this in initial single-media sharing.

## Intent

Allow a deliberately selected group of local media files to travel in one Boorusama attachment while preserving exact-file identity and per-item metadata.

## Expected user-facing behavior

- Select multiple local items and share one versioned media-package attachment.
- Recipient opens a package preview/summary and chooses **Import**; the package must not silently modify their library.
- Each payload carries its own SHA-256 and portable metadata. An existing SHA-256 item is not duplicated; local data retains precedence.
- Clearly report imported, skipped and invalid items, with safe file-count, total-size and per-item limits.

## Compatibility and safety

Extend the single-file package design (#182) compatibly, **not** the `.bslink` remote-reference grammar. Do not send duplicate bytes for repeat occurrences of the same SHA-256. Use bounded streaming ZIP64/STORE for compressed media, strict path/manifest validation and staging/rollback or a clearly atomic import policy.

Do not implement a background sync system, reactions, automatically shared bookmark groups or a remote server as part of this issue.

## Decisions intentionally deferred until implementation review

Package-level collection ordering, the precise partial-failure/rollback policy, maximum file count/size, and whether to transfer group membership must be decided after the single-media flow is proven. Preserve interoperability of existing V1 single-file packages.

## Verification when scheduled

Test mixed formats, duplicate identities, malformed entries, oversize package, low storage, cancellation, existing-library conflicts, preview and platform handoff on supported devices.
