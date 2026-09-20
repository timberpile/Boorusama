# Combine searches into a cached following feed within a profile

Priority: Normal
Affected feature: Following feeds

## Expected behavior

Users can create a feed from its own hidden search subscriptions, separate from
independent user-created pins. Results merge chronologically and deduplicate by profile-local
post ID. Opening uses cached results and exposes freshness and partial failures.

## Dependencies and design

- Depends on [PS-005](../done/PS-005-engine-refresh-adapters.md) and
  [PS-007](../done/PS-007-automatic-refresh-scheduler.md).
- Folders are optional organization, not required feed sources.
- Before coding, specify subscription purpose/ownership migration, feed persistence,
  bounded result retention, read semantics, ordering ties, backup behavior, and
  what happens when a referenced pin is deleted.
- See [feed roadmap](../../superpowers/specs/2026-09-14-pinned-searches-design.md#combined-following-feeds).
- This feed observes bounded snapshots; it is not a complete archive of all matches.

## Acceptance criteria

- [x] Create, rename, edit sources, and delete feeds owned by one profile.
- [x] Use feed-owned hidden sources that do not appear in Pinned Searches.
- [x] Deleting a feed deletes only its owned sources and preserves independent pins.
- [x] Merge cached discoveries newest-first, deduplicating profile-local post IDs.
- [x] Persist/materialize results so opening a feed does not synchronously fetch all sources.
- [x] Reuse existing post-grid/search patterns and profile authentication.
- [x] Source refresh failures preserve usable cached feed results and expose partial freshness.
- [x] Opening/reading behavior follows the agreed design without silently marking unrelated pins read.
- [x] Profile deletion and backup/restore preserve the agreed ownership lifecycle.
- [x] Cross-profile aggregation and local booru query evaluation remain excluded.

## Constraints and verification

Use the existing profile repositories and engine query composition. NEW means
observed matching uploads after the checkpoint; metadata edits to old posts do
not trigger it. Preserve PS-001's bounded snapshots and failure behavior; do
not restore exact counts or exhaustive pagination. Keep the side-menu section
and desktop tab positions stable. Add localized text through i18n.

Test observable behavior and persistence where relevant. Validate Android UI
with Maestro. Update [subsystem documentation](../../pinned_searches.md) and
record completion evidence here before moving the task to `done/`.

## Completion evidence

Agent: Codex (/root). Branch: `feature/chronological-pinned-search-support`.

Implemented feed-owned hidden subscriptions with backward-compatible Hive field
12, profile-owned definitions, chronological deduplicated materialized caches,
source editing/deletion, cached post grids, source freshness/error details,
and definition-only backup version 3. Opening clears only owned sources; native
post details are fetched on thumbnail selection.

Verified 279 related tests plus the corrected Pixiv detail regression test;
static analysis clean; dev APK built. Maestro verified feed creation, fifty
cached Safebooru posts, source Info, renaming/source replacement, deletion,
and preservation of the independent pinned search and its NEW state.

## User decisions — 2026-09-17

Feeds own invisible search subscriptions separate from user-created pins; they never reference or clear independent user pins.
