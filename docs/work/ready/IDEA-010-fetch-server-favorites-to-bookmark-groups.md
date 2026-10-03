# Fetch server favorites into ordinary bookmark groups

Priority: Normal
Affected feature: Account Favorites, bookmarks, profile settings, group export

## Problem

Server Favorites are not available as one configurable local bookmark-group collection across supported profiles. Users need an optional way to fetch and retain them without a destructive or two-way synchronization contract.

## Expected behavior

Bookmark settings offer an optional global default Favorites group. Each profile chooses `Use global` (default), `None`, or a specific override group. `Fetch server favorites` is available on initial assignment and later; it adds missing server favorites but never removes group entries. Direct successful favorite/unfavorite actions update the resolved local target. Every target remains an ordinary, fully editable and exportable bookmark group.

## Decisions and edge cases

- A target must be new or empty when first bound. A populated target already bound by one profile may be shared by more profiles. Its name is unrestricted. `Use global` resolves to no target if no global default exists; there is no additional per-profile enable flag.
- Fetch independently per profile using paginated, cancellable, safely resumable requests. Successful pages may add immediately. Retry may repeat pages, but IDEA-004 identity and group membership make additions idempotent. Partial success survives cancellation, restart, sign-out, timeout, or 429.
- Fetch is additive only: server-side removals and unrelated manual entries remain local. A manually removed server favorite may reappear on later fetch. For a rebuild, the user clears the ordinary group and fetches again. Do not call this authoritative `Sync` or run it at startup, on lifecycle changes, periodically, or in the background.
- After a direct server favorite succeeds, add the post to the current resolved target; after direct unfavorite succeeds, remove it. Failed server actions leave local membership alone. Do not track per-profile membership provenance for rare shared-target overlap; another profile's later fetch may re-add it.
- Manual group edits never mutate server Favorites. Profile, account/site binding, assignment, or global-default changes never move or clean up old target entries. Unsupported, signed-out, or ambiguous-account profiles show a reason without undoing other profiles' additions.
- Export/import a target as an ordinary unbound group, excluding credentials, assignments/profile references, cursors, and active Favorites behavior. Coordinate detailed file format with the ongoing export rewrite.

## Acceptance criteria

- Global inheritance, `None`, and overrides route additions/direct removals only to the resolved group. First binding rejects a nonempty unbound group; another profile may reuse a bound populated one.
- Fetch adds all successfully retrieved favorites once and removes none. Repeating it preserves local additions and stale server entries while adding newly found favorites.
- Cancellation/failure preserves completed additions; retry safely resumes or repeats. Successful direct unfavorite removes the local target entry; server failure leaves it unchanged.
- Changing/deleting profiles, assignments, or targets does not mutate old group contents. Manual edits never trigger server writes or a network fetch.
- Exported/imported targets contain ordinary group content only, with no profile binding or automatic fetch behavior.

## Context and dependencies

Requires IDEA-004 for cross-profile post identity and IDEA-007 for request priority, cancellation, and rate-limit handling. IDEA-015 must keep target references stable across folder renames/moves. The parallel export rewrite determines archive structure, not the product behavior here.

- [Bookmark architecture](../../bookmark_groups.md)
