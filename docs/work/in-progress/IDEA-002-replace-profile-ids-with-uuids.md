# Replace local profile IDs with UUIDs end-to-end

Claim: coordinator `/root`, 2026-10-03; implementer `/root/audit_profile_ids`; branch `feature/idea-002-profile-uuids`; worktree `/home/timber/code/Boorusama/.worktrees/idea-002-profile-uuids`.
Priority: Normal
Affected feature: Profiles, settings, cached posts, Pinned Searches, Following Feeds, import/export

## Problem

The locally assigned integer profile ID is used as portable identity. It cannot reliably identify the same profile across independently created installations or future selective imports, especially with multiple profiles for one site. The ID audit is complete; this ticket covers implementation.

## Expected behavior

Creating a profile assigns one canonical lowercase UUID. Editing keeps it; duplicating or independently creating a profile assigns a new UUID, even on the same site. Profile selection, ordering, navigation, pins, feeds, and cached post origin continue to behave normally. New exports preserve identity; unsupported integer-profile archives fail clearly before writes.

## Decisions and edge cases

- Replace `BooruConfig.id` and its Hive key; do not add a second permanent ID. Update current selection/order, profile settings, pin/feed ownership, `PostOrigin.profileIdHint`, routes/deep links, import/export, deletion, cleanup, and rollback.
- Treat current `develop` as having no old installed data or exports to preserve. Do not add a dual-ID bridge, local migration, converter, or legacy integer-profile reader.
- Export/import UUID with engine/site metadata. Equal UUID with incompatible engine/site is a preflight conflict; an unmatched UUID must not silently match a same-site profile. Credentials and display name do not define identity.
- Keep upstream post/user IDs, engine/category constants, and internal row keys numeric. Bookmark identity follows IDEA-004, not profile UUID or a random bookmark UUID.
- Coordinate format and preflight with the ongoing export rewrite.

## Acceptance criteria

- All persisted and in-memory profile references use one UUID with no integer alias. Tests cover create/edit/duplicate, selection/order/deletion, navigation, pins, feeds, and cached post resolution.
- Export/import round-trips UUIDs and dependent records. Repeat import is idempotent; unmatched references require explicit mapping where needed; UUID/site conflicts fail preflight without partial writes.
- Old integer-profile archives fail clearly before mutation. No backwards-compatibility layer is introduced.
- Tests verify unrelated numeric IDs remain numeric and bookmarks still use IDEA-004's site-aware post identity.
- Measure serialized size and load time of a representative full 500-post feed cache before/after; report results and remove redundant repeated hints only if cost warrants it.

## Context and dependencies

The completed audit estimated a small storage increase for repeated UUID hints but did not benchmark runtime cost. This ticket is independent of IDEA-004 and must agree with the in-progress export rewrite. Two independently created same-site profiles are not assumed to be the same account.


## Implementation evidence (2026-10-03)

- Profile records and Hive keys now use canonical lowercase UUIDs. New and duplicated profiles receive distinct IDs; edits keep the ID. Current selection/order, routes, pins, feeds, cached post origin hints, and export/import references use that ID.
- Import preflight rejects a UUID reused for another engine or site. A different UUID needs an explicit mapping even for the same site. Copy allocates its destination UUID during the import review, then uses it for the planned summary, dependent pins/feeds, and apply. A later independent Copy allocates another UUID.
- Old integer profile keys and integer-owned pin/feed rows are ignored when loading; an old archive with numeric profile references fails format validation before writes. These rows are not migrated.
- Full Flutter suite: 1,976 tests passed on 2026-10-03, including the 827-test relevant migration scope, old-row safety, and conflict preflight. The Dart analyzer reported no errors; its remaining diagnostics are warnings and informational lints.

### 500-post cache measurement

The same feed fixture held 500 full cached post snapshots, two source IDs, representative media URLs, tags, dimensions, and variants. Each measurement JSON-encoded the feed once, counted UTF-8 bytes, then ran five JSON decode plus `SearchFollowingFeed.fromJson` loads in one test process and reported their median. The pre-change run used integer profile ID 17; the post-change isolated run used a canonical UUID in the feed and each post origin hint.

| Representation | Serialized bytes | Median load time |
| --- | ---: | ---: |
| Integer profile ID | 377,968 | 66,795 µs |
| UUID profile ID | 395,504 | 15,926 µs |

The UUID representation adds 17,536 bytes (4.64%) to this 500-post cache. Timings vary substantially across separate Flutter test runs, so the measured drop is not evidence of a speedup. The storage increase is small enough to retain the repeated origin hints needed for cached-post resolution.
