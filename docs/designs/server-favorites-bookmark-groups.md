# Fetch account favorites into regular bookmark groups

## Goal

Offer an optional, additive download of server-side Favorites to ordinary local bookmark groups across supported profiles. Do not create a destructive or bidirectional synchronization system.

## Expected behavior

Bookmark settings provide an optional global default Favorites group. Each profile selects **Use global** (the default), **None**, or an overriding group. **Fetch server favorites** is available when first assigning a target and afterward. Successfully favoriting or unfavoriting a post directly updates the currently resolved local target after the server confirms success.

Every target remains a regular group: editable, renameable, and exportable.

## Accepted decisions and edge cases

- A target must be new or empty on its first binding. An already-bound populated group may be shared by additional profiles; its name has no reserved value.
- **Use global** resolves to no group when a global default is unset. There is no second per-profile enable switch.
- Fetch per profile with pagination, cancellation, and safe retry/resume behavior. Successfully fetched pages may be committed immediately. Repeating pages must be idempotent using canonical post identity and group membership.
- A failure, sign-out, cancellation, restart, timeout, or HTTP 429 preserves successfully added favorites. Retry must continue or safely repeat pages without dropping progress.
- Fetch is additive only: never remove locally saved posts on the basis of server-side changes. Manually removed favorites may reappear in later fetches. A deliberate rebuild is accomplished by clearing the ordinary group then fetching again.
- Do not describe this as an authoritative sync. No startup, lifecycle, periodic, or background fetch.
- A successful direct server favorite adds to the resolved group; a successful direct unfavorite removes from that group. Failed remote actions leave the group unchanged. Do not add per-profile provenance tracking to shared groups solely for rare overlapping server accounts.
- Manual group changes must never write to server Favorites. Changes to profile, account binding, target choice, or global default must never transfer, purge, or silently reconcile existing group content.
- Unsupported, logged-out, or ambiguous accounts show an understandable reason without undoing successful additions for other profiles.
- Export/import the group as an ordinary unbound bookmark group. Exclude credentials, profile assignments, cursors, and active Favorites behavior. Respect current import/export compatibility.

## Acceptance boundaries

Test global inheritance and overrides, shared targets, first-binding safeguards, additive repeats, recovery from partial fetches, direct-action success/failure, deleted/changed targets, and export without binding metadata.

Depends on stable bookmark identity and existing network-request coordination. The target identity must survive nested-folder renames and moves. Relevant documentation: [Bookmark architecture](../bookmark_groups.md).
